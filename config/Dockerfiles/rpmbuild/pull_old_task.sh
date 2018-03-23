#!/bin/bash

set -xe

# Ensure we have required variable
if [ -z "${PROVIDED_KOJI_TASKID}" ]; then echo "No task id variable provided" ; exit 1 ; fi

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi

RPMDIR=${CURRENTDIR}/${fed_repo}_repo
rm -rf ${RPMDIR}
mkdir -p ${RPMDIR}

LOGDIR=${CURRENTDIR}/logs
rm -rf ${LOGDIR}/*
mkdir ${LOGDIR}

# Create trap function to archive as many of the variables as we have defined
function archive_variables {
    set +e
    cat << EOF > ${LOGDIR}/job.props
koji_task_id=${PROVIDED_KOJI_TASKID}
fed_repo=${PACKAGE}
fed_branch=${FED_BRANCH}
branch=${BRANCH}
fed_rev=kojitask${PROVIDED_KOJI_TASKID}
nvr=${NVR}
original_spec_nvr=${NVR}
EOF
}
trap archive_variables EXIT SIGHUP SIGINT SIGTERM

pushd ${RPMDIR}
# Download brew build so we can archive it
koji download-task ${PROVIDED_KOJI_TASKID} --logs
createrepo .
PACKAGE=$(rpm --queryformat "%{NAME}\n" -qp *.src.rpm)
NVR=$(rpm --queryformat "%{NAME} %{VERSION} %{RELEASE}\n" -qp *.src.rpm)
FED_BRANCH=$(grep -Po "chrootPath='/var/lib/mock/\K[^-]+" build.*.log | head -n 1)
popd

if [ "${FED_BRANCH}" = $(curl -s https://src.fedoraproject.org/rpms/fedora-release/raw/master/f/fedora-release.spec | awk '/%define dist_version/ {print $3}') ]; then
    BRANCH="master"
    FED_BRANCH="rawhide"
else
    BRANCH=$FED_BRANCH
fi

# Let's archive the logs too
cp ${RPMDIR}/*.log ${LOGDIR}/

archive_variables
