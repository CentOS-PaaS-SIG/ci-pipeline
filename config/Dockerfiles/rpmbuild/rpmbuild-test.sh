#!/bin/bash
set +e

RPMDIR=/home/${fed_repo}_repo
# Create one dir to store logs in that will be mounted
LOGDIR=/home/logs
rm -rf ${LOGDIR}/*
mkdir -p ${LOGDIR}
# Clone the fedoraproject git repo
rm -rf ${fed_repo}
fedpkg clone -a ${fed_repo}
if [ "$?" != 0 ]; then echo -e "ERROR: FEDPKG CLONE\nSTATUS: $?"; exit 1; fi
pushd ${fed_repo}
# Checkout the proper branch, likely unneeded since we checkout commit anyways
git checkout ${fed_branch}
# Checkout the commit from the fedmsg
git checkout ${fed_rev}
# Create new branch because fedpkg wont build with detached head
git checkout -b test_branch
# Find number of git commits in log to append to RELEASE before %{?dist}
commits=$(git log --pretty=format:'' | wc -l)
# Append to release in spec file before dist
sed -i "/^Release:/s/%{?dist}/.${commits}.${fed_rev:0:7}%{?dist}/" ${fed_repo}.spec
# fedpkg prep to unpack the tarball
fedpkg --release ${fed_branch} prep
VERSION=$(rpmspec --queryformat "%{VERSION}\n" -q ${fed_repo}.spec | head -n 1)
# Some packages are packagename-version-release, some packagename-sha, some packagename[0-9]
DIR_TO_GO=$(find . -maxdepth 1 -type d | cut -c 3- | grep ${fed_repo})
pushd $DIR_TO_GO
# Run configure if it exists, if not, no big deal
./configure
# Run tests if they are there
make test >> ${LOGDIR}/make_test_output.txt
MAKE_TEST_STATUS=$?
popd
if [ "$MAKE_TEST_STATUS" == 2 ]; then
     echo "description='${fed_repo} - No tests'" >> ${LOGDIR}/package_props.txt
elif [ "$MAKE_TEST_STATUS" == 0 ]; then
     echo "description='${fed_repo} - make test passed'" >> ${LOGDIR}/package_props.txt
else
     echo "description='${fed_repo} - make test failed'" >> ${LOGDIR}/package_props.txt
     exit $MAKE_TEST_STATUS
fi
# Build the package into ./results_${fed_repo}/$VERSION/$RELEASE/
fedpkg --release ${fed_branch} mockbuild
MOCKBUILD_STATUS=$?
echo "status=$MOCKBUILD_STATUS" >> ${LOGDIR}/package_props.txt
if [ "$MOCKBUILD_STATUS" != 0 ]; then echo -e "ERROR: FEDPKG MOCKBUILD\nSTATUS: $MOCKBUILD_STATUS"; exit 1; fi
popd

ABIGAIL_BRANCH=$(echo ${fed_branch} | sed 's/./&c/1')
if [ "${fed_branch}" = "master" ]; then
    ABIGAIL_BRANCH="fc27"
fi
# Make repo with the newly created rpm
rm -rf ${RPMDIR}/*
mkdir -p ${RPMDIR}
cp ${fed_repo}/results_${fed_repo}/${VERSION}/*/*.rpm ${RPMDIR}/
# Run rpmlint
rpmlint ${RPMDIR}/ > ${LOGDIR}/rpmlint_out.txt
pushd ${RPMDIR} && createrepo .
popd
# Run fedabipkgdiff against the newly created rpm
rm -rf libabigail
git clone git://sourceware.org/git/libabigail.git
RPM_TO_CHECK=$(find ${fed_repo}/results_${fed_repo}/${VERSION}/*/ -name "${fed_repo}-${VERSION}*" | grep -v src)
libabigail/tools/fedabipkgdiff --from ${ABIGAIL_BRANCH} ${RPM_TO_CHECK} &> ${LOGDIR}/fedabipkgdiff_out.txt
RPM_NAME=$(basename $RPM_TO_CHECK)
echo "package_url=http://artifacts.ci.centos.org/fedora-atomic/${fed_branch}/repo/${fed_repo}_repo/$RPM_NAME" >> ${LOGDIR}/package_props.txt

# Perform rsync to artifacts.ci.centos.org
RSYNC_BRANCH=${fed_branch}
if [ "${fed_branch}" = "master" ]; then
    RSYNC_BRANCH=rawhide
fi
mkdir ${RSYNC_BRANCH}
mkdir repo
# Kill backgrounded jobs on exit
function clean_up {
    # Delete the rsync lock we placed
     rsync -vr --delete $(mktemp -d)/ fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}/repo/lockdir/
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM
# Write uuid to a lock file and store a backup
uuidgen > file.lock
cp file.lock uuid.saved
while true; do
    # Check if lock exists on remote server
     while [[ $(rsync --ignore-existing --dry-run -avz file.lock fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}/repo/lockdir) != *"file.lock"* ]]; do
          sleep 60
     done
     cp uuid.saved file.lock
    # Push lock file with uuid to remote server
     rsync --ignore-existing -avz file.lock fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}/repo/lockdir/
    # Pull lock file back
     rsync -avz fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}/repo/lockdir/file.lock file.lock
    # If uuid matches, we can proceed
     if [[ $(diff file.lock uuid.saved) == "" ]]; then
          break
     fi
     sleep 60
done
# Rsync the empty directories over first, then the repo directory
rsync -arv ${RSYNC_BRANCH}/ fedora-atomic@artifacts.ci.centos.org::fedora-atomic
rsync -arv repo/ fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}
rsync --delete --stats -a ${RPMDIR} fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}/repo
if [ "$?" != 0 ]; then echo "ERROR: RSYNC REPO\nSTATUS: $?"; exit 1; fi
rm -rf ${RSYNC_BRANCH}
rm -rf repo
# Update repo manifest file on artifacts.ci.centos.org
rsync --delete --stats -a fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}/repo/manifest.txt .
# Remove repo name from file if it exists so it isn't there twice
sed -i "/${fed_repo}_repo/d" manifest.txt
echo "${fed_repo}_repo $(date --utc +%FT%T%Z)" >> manifest.txt
sort manifest.txt -o manifest.txt
rsync --delete -stats -a manifest.txt fedora-atomic@artifacts.ci.centos.org::fedora-atomic/${RSYNC_BRANCH}/repo
clean_up
