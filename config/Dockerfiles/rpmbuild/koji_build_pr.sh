#!/bin/bash

# This container builds with koji into $RPMDIR starting from a pagure PR

set -xe

# Check to make sure we have all required vars
if [ -z "${fed_repo}" ]; then echo "No fed_repo env var" ; exit 1 ; fi
if [ -z "${fed_id}" ]; then echo "No fed_id env var" ; exit 1 ; fi
if [ -z "${fed_uid}" ]; then echo "No fed_uid env var" ; exit 1 ; fi
if [ -z "${FEDORA_PRINCIPAL}" ]; then echo "No FEDORA_PRINCIPAL env var"; exit 1; fi

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi

RPMDIR=${CURRENTDIR}/${fed_repo}_repo

# Create one dir to store logs in that will be mounted
LOGDIR=${CURRENTDIR}/logs
rm -rf ${LOGDIR}/*
mkdir -p ${LOGDIR}

# Clone the fedoraproject git repo
rm -rf ${fed_repo}
fedpkg clone -a ${fed_repo}
if [ "$?" != 0 ]; then echo -e "ERROR: FEDPKG CLONE\nSTATUS: $?"; exit 1; fi
pushd ${fed_repo}
# Checkout the PR
git fetch -fu origin refs/pull/${fed_id}/head:pr
git checkout pr
# Get current NVR
truenvr=$(rpm -q --define "dist .$DIST_BRANCH" --queryformat '%{name}-%{version}-%{release}\n' --specfile ${fed_repo}.spec | head -n 1)
echo "original_spec_nvr=${truenvr}" >> ${LOGDIR}/job.props
# Find number of git commits in log to append to RELEASE before %{?dist}
commits=$(git log --pretty=format:'' | wc -l)
# %{?dist} seems to only be used when defining $release, but some
# .spec files use different names for release, so just replace %{?dist}
sed -i "s/%{?dist}/%{?dist}.pr.${fed_uid}/" ${fed_repo}.spec

# Build srpm to send to koji
fedpkg --release ${fed_branch} srpm
VERSION=$(rpmspec --queryformat "%{VERSION}\n" -q ${fed_repo}.spec | head -n 1)
# Set up koji creds
kinit -k -t "${CURRENTDIR}/fedora.keytab" $FEDORA_PRINCIPAL

 # Some packages are requiring configure not be run as root, so set this to bypass the error
export FORCE_UNSAFE_CONFIGURE=1

# Build the package with koji
python2 /usr/bin/koji build --wait --arch-override=x86_64 --scratch ${branch} ${fed_repo}*.src.rpm | tee ${LOGDIR}/kojioutput.txt
# Set status if either job fails to build the rpm
RPMBUILD_RC=$?
if [ "$RPMBUILD_RC" != 0 ]; then
     echo "status=FAIL" >> ${LOGDIR}/job.props
     echo -e "ERROR: KOJI BUILD\nSTATUS: $MOCKBUILD_RC"
     exit 1
fi
echo "status=SUCCESS" >> ${LOGDIR}/job.props
popd

SCRATCHID=$(cat ${LOGDIR}/kojioutput.txt | awk '/Created task:/ { print $3 }')
echo "koji_task_id=${SCRATCHID}" >> ${LOGDIR}/job.props

# Make repo to download rpms to
rm -rf ${RPMDIR}
mkdir -p ${RPMDIR}
# Create repo
pushd ${RPMDIR}
koji download-task ${SCRATCHID} --logs
createrepo .
popd

# Store modified nvr as well
set +e
RPM_TO_CHECK=$(find ${RPMDIR}/ -name "${fed_repo}-${VERSION}*" | grep -v src)
RPM_NAME=$(basename $RPM_TO_CHECK)
NVR=$(rpm --queryformat "%{NAME} %{VERSION} %{RELEASE}\n" -qp $RPM_TO_CHECK)
echo "nvr=${NVR}" >> ${LOGDIR}/job.props
exit 0
