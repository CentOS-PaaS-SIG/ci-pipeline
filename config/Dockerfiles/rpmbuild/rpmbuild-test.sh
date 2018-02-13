#!/bin/bash

set +e
set -x
# Check to make sure we have all required vars
if [ -z "${fed_repo}" ]; then echo "No fed_repo env var" ; exit 1 ; fi
if [ -z "${fed_branch}" ]; then echo "No fed_branch env var" ; exit 1 ; fi
if [ -z "${fed_rev}" ]; then echo "No fed_rev env var" ; exit 1 ; fi
if [ -z "${FEDORA_PRINCIPAL}" ]; then echo "No FEDORA_PRINCIPAL env var"; exit 1; fi
if [ -z "${RSYNC_BRANCH}" ]; then echo "No RSYNC_BRANCH env var"; exit 1; fi

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi
# Add the c to branch for libabigail
ABIGAIL_BRANCH=$(echo ${RSYNC_BRANCH} | sed 's/./&c/1')
echo "config_opts['basedir'] = '${CURRENTDIR}/rpmbuild/'" >> /etc/mock/site-defaults.cfg
RPMDIR=/${fed_repo}_repo
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create one dir to store logs in that will be mounted
LOGDIR=${CURRENTDIR}/logs
rm -rf ${LOGDIR}/*
mkdir -p ${LOGDIR}

# Need to debug git clone errors
export GIT_CURL_VERBOSE=1

# Clone the fedoraproject git repo
rm -rf ${fed_repo}
for i in 1 2 3 4 5 ; do fedpkg clone -a ${fed_repo} && break || sleep 10 ; done
if [ "$?" != 0 ]; then echo -e "ERROR: FEDPKG CLONE\nSTATUS: $?"; exit 1; fi
pushd ${fed_repo}
# Checkout the proper branch, likely unneeded since we checkout commit anyways
git checkout ${fed_branch}
# Checkout the commit from the fedmsg
git checkout ${fed_rev}
# Create new branch because fedpkg wont build with detached head
git checkout -b test_branch
# Get current NVR
truenvr=$(rpm -q --define "dist .$ABIGAIL_BRANCH" --queryformat '%{name}-%{version}-%{release}\n' --specfile ${fed_repo}.spec | head -n 1)
echo "original_spec_nvr=${truenvr}" >> ${LOGDIR}/package_props.txt
# Find number of git commits in log to append to RELEASE before %{?dist}
commits=$(git log --pretty=format:'' | wc -l)
# %{?dist} seems to only be used when defining $release, but some
# .spec files use different names for release, so just replace %{?dist}
sed -i "s/%{?dist}/.${commits}.${fed_rev:0:7}%{?dist}/" ${fed_repo}.spec
# fedpkg prep to unpack the tarball
fedpkg --release ${fed_branch} prep
VERSION=$(rpmspec --queryformat "%{VERSION}\n" -q ${fed_repo}.spec | head -n 1)
# Some packages are packagename-version-release, some packagename-sha, some packagename[0-9]
DIR_TO_GO=$(dirname $(find . -name Makefile | tail -n 1))
if [ -n "$DIR_TO_GO" ] ; then
    pushd $DIR_TO_GO
    # Run configure if it exists, to prep for make test. If not, no big deal
    # "Configure script can automatically adjust the Makefile according to the system requirements."
    ./configure
    # Run tests if they are there
    make test >> ${LOGDIR}/make_test_output.txt
    MAKE_TEST_STATUS=$?
    popd
    if [ "$MAKE_TEST_STATUS" == 2 ]; then
         echo "description='${fed_repo} - No tests or make test failed'" >> ${LOGDIR}/package_props.txt
    elif [ "$MAKE_TEST_STATUS" == 0 ]; then
         echo "description='${fed_repo} - make test passed'" >> ${LOGDIR}/package_props.txt
    else
         echo "description='${fed_repo} - make test unknown rc'" >> ${LOGDIR}/package_props.txt
    fi
fi

# Prepare concurrent koji build
cp -rp ../${fed_repo}/** ~/rpmbuild/SOURCES
rpmbuild -bs --define "dist .$fed_branch" ${fed_repo}.spec
ls
# Set up koji creds
kinit -k -t "${CURRENTDIR}/fedora.keytab" $FEDORA_PRINCIPAL

# Want to archive build logs if mock build exits uncleanly
function archive_logs {
     cp ${CURRENTDIR}/${fed_repo}/results_${fed_repo}/${VERSION}/*/*.log ${LOGDIR}/
}
trap archive_logs EXIT SIGHUP SIGINT SIGTERM

 # Some packages are requiring configure not be run as root, so set this to bypass the error
 export FORCE_UNSAFE_CONFIGURE=1

# Build the package into ./results_${fed_repo}/$VERSION/$RELEASE/ and concurrently do a koji build
{ time fedpkg --release ${fed_branch} mockbuild ; } 2> ${LOGDIR}/mockbuild.txt &
{ time python2 /usr/bin/koji build --wait --arch-override=x86_64 --scratch $RSYNC_BRANCH ~/rpmbuild/SRPMS/${fed_repo}*.src.rpm ; } 2> ${LOGDIR}/kojibuildtime.txt &
# Set status if either job fails to build the rpm
MOCKBUILD_RC=0
for job in `jobs -p`; do
echo $job
    wait $job || let "MOCKBUILD_RC+=1"
done
# Make mockbuildtime be just the time result
tail -n 3 ${LOGDIR}/mockbuild.txt > ${LOGDIR}/mockbuildtime.txt
if [ "$MOCKBUILD_RC" != 0 ]; then
     echo "status=FAIL" >> ${LOGDIR}/package_props.txt
     echo -e "ERROR: FEDPKG MOCKBUILD\nSTATUS: $MOCKBUILD_RC"
     exit 1
fi
echo "status=SUCCESS" >> ${LOGDIR}/package_props.txt
popd

# Make repo with the newly created rpm
rm -rf ${RPMDIR}
mkdir -p ${RPMDIR}
cp ${CURRENTDIR}/${fed_repo}/results_${fed_repo}/${VERSION}/*/*.rpm ${RPMDIR}/
# Run rpmlint
rpmlint ${RPMDIR}/ > ${LOGDIR}/rpmlint_out.txt
pushd ${RPMDIR} && createrepo .
mkdir logs
cp ${CURRENTDIR}/${fed_repo}/results_${fed_repo}/${VERSION}/*/*.log logs/
archive_logs
popd
# Run fedabipkgdiff against the newly created rpm
rm -rf libabigail
git clone -q git://sourceware.org/git/libabigail.git
RPM_TO_CHECK=$(find ${RPMDIR}/ -name "${fed_repo}-${VERSION}*" | grep -v src)
if [ -z ${RPM_TO_CHECK} ] ; then
     echo "Could not find an rpm with pkg_name-ver*.rpm that was built besides the src rpm, so using src rpm"
     RPM_TO_CHECK=$(find ${RPMDIR}/ -name "${fed_repo}-${VERSION}*" | grep src)
else
     libabigail/tools/fedabipkgdiff --from ${ABIGAIL_BRANCH} ${RPM_TO_CHECK} &> ${LOGDIR}/fedabipkgdiff_out.txt
fi
RPM_NAME=$(basename $RPM_TO_CHECK)
echo "package_url=${HTTP_BASE}/${RSYNC_BRANCH}/repo/${fed_repo}_repo/$RPM_NAME" >> ${LOGDIR}/package_props.txt
RPM_NAME=$(echo $RPM_NAME | rev | cut -d '.' -f 2- | rev)
echo "nvr=${RPM_NAME}" >> ${LOGDIR}/package_props.txt
RSYNC_LOCATION="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/${RSYNC_BRANCH}"

# If we do rsync, make sure we have the password
if [ -z "${RSYNC_PASSWORD}" ]; then echo "Told to rsync but no RSYNC_PASSWORD env var" ; exit 1 ; fi
# Create our ${RSYNC_BRANCH}/repo directory structure
mkdir -p ${RSYNC_BRANCH}/repo
# Rsync our ${RSYNC_BRANCH}/repo directory structure over first
rsync -arv ${RSYNC_BRANCH} ${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}

# Kill backgrounded jobs on exit
function clean_up {
    # Delete the rsync lock we placed
     rsync -vr --delete $(mktemp -d)/ ${RSYNC_LOCATION}/repo/lockdir/
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM
# Write uuid to a lock file and store a backup
uuidgen > file.lock
cp file.lock uuid.saved
while true; do
    # Check if lock exists on remote server
     while [[ $(rsync --ignore-existing --dry-run -avz file.lock ${RSYNC_LOCATION}/repo/lockdir) != *"file.lock"* ]]; do
          sleep 60
     done
     cp uuid.saved file.lock
    # Push lock file with uuid to remote server
     rsync --ignore-existing -avz file.lock ${RSYNC_LOCATION}/repo/lockdir/
    # Pull lock file back
     rsync -avz ${RSYNC_LOCATION}/repo/lockdir/file.lock file.lock
    # If uuid matches, we can proceed
     if [[ $(diff file.lock uuid.saved) == "" ]]; then
          break
     fi
     sleep 60
done
rsync --delete --stats -a ${RPMDIR} ${RSYNC_LOCATION}/repo
if [ "$?" != 0 ]; then echo "ERROR: RSYNC REPO\nSTATUS: $?"; exit 1; fi
# Update repo manifest file on artifacts.ci.centos.org
rsync --delete --stats -a ${RSYNC_LOCATION}/repo/manifest.txt .
# Remove repo name from file if it exists so it isn't there twice
sed -i "/${fed_repo}_repo/d" manifest.txt
rm -rf ${RSYNC_BRANCH}
rm -rf repo
echo "${fed_repo}_repo $(date --utc +%FT%T%Z)" >> manifest.txt
sort manifest.txt -o manifest.txt
rsync --delete -stats -a manifest.txt ${RSYNC_LOCATION}/repo
clean_up
exit 0
