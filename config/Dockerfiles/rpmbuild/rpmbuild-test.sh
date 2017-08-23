#!/bin/bash
set +e

OUTPUTDIR=/home/${fed_repo}/output
which fedpkg
if [ "$?" != 0 ]; then echo "ERROR: FEDPKG RPM NOT INSTALLED\nSTATUS: $?"; exit 1; fi
# Put all output files into logs/ for rsync
rm -rf ${OUTPUTDIR}/logs
mkdir ${OUTPUTDIR}/logs
# Clone the fedoraproject git repo
rm -rf ${fed_repo}
fedpkg clone -a ${fed_repo}
if [ "$?" != 0 ]; then echo "ERROR: FEDPKG CLONE\nSTATUS: $?"; exit 1; fi
pushd ${fed_repo}
# Checkout the proper branch
git checkout ${fed_branch}
# Checkout the commit from the fedmsg
git checkout ${fed_rev}
# Create new branch because fedpkg wont build with detached head
git checkout -b test_branch
# Get current NVR
truenvr=$(rpm -q --define "dist .$fed_branch" --queryformat '%{name}-%{version}-%{release}\n' --specfile ${fed_repo}.spec | head -n 1)
# Find number of git commits in log to append to RELEASE
commits=$(git log --pretty=format:'' | wc -l)
# Append to release in spec file
sed -i "/^Release:/s/%{?dist}/.${commits}.${fed_rev:0:7}%{?dist}/" ${fed_repo}.spec
# fedpkg prep to unpack the tarball
fedpkg --release ${fed_branch} prep
# Make sure we have rpmspec before we call it
which rpmspec
if [ "$?" != 0 ]; then echo "ERROR: RPMSPEC RPM NOT INSTALLED\nSTATUS: $?"; exit 1; fi
VERSION=$(rpmspec --queryformat "%{VERSION}\n" -q ${fed_repo}.spec | head -n 1)
# Some packages are packagename-version-release, some packagename-sha, some packagename[0-9]
DIR_TO_GO=$(find . -maxdepth 1 -type d | cut -c 3- | grep ${fed_repo})
pushd $DIR_TO_GO
# Run configure if it exists, if not, no big deal
./configure
# Run tests if they are there
make test >> ${OUTPUTDIR}/logs/make_test_output.txt
MAKE_TEST_STATUS=$?
popd
if [ "$MAKE_TEST_STATUS" == 2 ]; then
     sudo echo "description='${fed_repo} - No tests'" >> ${OUTPUTDIR}/logs/description.txt
elif [ "$MAKE_TEST_STATUS" == 0 ]; then
     sudo echo "description='${fed_repo} - make test passed'" >> ${OUTPUTDIR}/logs/description.txt
else
     sudo echo "description='${fed_repo} - make test failed'" >> ${OUTPUTDIR}/logs/description.txt
fi
# Build the package into ./results_${fed_repo}/$VERSION/$RELEASE/
fedpkg --release ${fed_branch} mockbuild
MOCKBUILD_STATUS=$?
sudo echo "status=$MOCKBUILD_STATUS" >> ${OUTPUTDIR}/logs/package_props.txt
if [ "$MOCKBUILD_STATUS" != 0 ]; then echo "ERROR: FEDPKG MOCKBUILD\nSTATUS: $MOCKBUILD_STATUS"; exit 1; fi
popd

ABIGAIL_BRANCH=$(echo ${fed_branch} | sed 's/./&c/1')
if [ "${fed_branch}" = "master" ]; then
    ABIGAIL_BRANCH="fc27"
fi
# Make repo with the newly created rpm
rm -rf ${OUTPUTDIR}/${fed_repo}_repo
mkdir ${OUTPUTDIR}/${fed_repo}_repo
cp /${fed_repo}/results_${fed_repo}/${VERSION}/*/*.rpm ${OUTPUTDIR}/${fed_repo}_repo/
# Run rpmlint
rpmlint ${OUTPUTDIR}/${fed_repo}_repo/ > ${OUTPUTDIR}/logs/rpmlint_out.txt
pushd ${OUTPUTDIR}/${fed_repo}_repo && createrepo .
popd
# Run fedabipkgdiff against the newly created rpm
rm -rf libabigail
git clone git://sourceware.org/git/libabigail.git
RPM_TO_CHECK=$(find /${fed_repo}/results_${fed_repo}/${VERSION}/*/ -name "${fed_repo}-${VERSION}*" | grep -v src)
libabigail/tools/fedabipkgdiff --from ${ABIGAIL_BRANCH} ${RPM_TO_CHECK} &> ${OUTPUTDIR}/logs/fedabipkgdiff_out.txt
RPM_NAME=$(basename $RPM_TO_CHECK)
echo "package_url=${HTTP_BASE}/${fed_branch}/repo/${fed_repo}_repo/$RPM_NAME" >> ${OUTPUTDIR}/logs/package_props.txt
echo "original_spec_nvr=${truenvr}" >> ${OUTPUTDIR}/logs/package_props.txt
RPM_NAME=$(echo $RPM_NAME | rev | cut -d '.' -f 2- | rev)
echo "nvr=${RPM_NAME}" >> ${OUTPUTDIR}/logs/package_props.txt

exit 0