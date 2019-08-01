#!/bin/bash

set -xe

# Ensure we have required variable
if [ -z "${PROVIDED_KOJI_TASKID}" ]; then echo "No task id variable provided" ; exit 1 ; fi

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi

LOGDIR=${CURRENTDIR}/logs
rm -rf ${LOGDIR}/*
mkdir ${LOGDIR}

# Allow change koji server to be used
KOJI_SERVER=${KOJI_SERVER:-}
if [[ -n ${KOJI_SERVER} ]]; then
    KOJI_SERVER="-s ${KOJI_SERVER} "
fi

# Create trap function to archive as many of the variables as we have defined
function archive_variables {
    set +e
    cat << EOF > ${LOGDIR}/job.props
koji_task_id=${PROVIDED_KOJI_TASKID}
fed_repo=${PACKAGE}
fed_rev=kojitask-${PROVIDED_KOJI_TASKID}
nvr=${NVR}
original_spec_nvr=${NVR}
rpm_repo=${RPMDIR}
EOF
rm -rf somewhere
}
trap archive_variables EXIT SIGHUP SIGINT SIGTERM

mkdir somewhere
pushd somewhere
# Download koji build so we can archive it
for i in {1..5}; do
    koji ${KOJI_SERVER} download-build --arch=x86_64 --arch=src --arch=noarch --debuginfo --task-id ${PROVIDED_KOJI_TASKID} || koji ${KOJI_SERVER} download-task --arch=x86_64 --arch=src --arch=noarch --logs ${PROVIDED_KOJI_TASKID} && break
    echo "koji build download failed, attempt: $i/5"
    if [[ $i -lt 5 ]]; then
        sleep 10
    else
        exit 1
    fi
done
createrepo .
PACKAGE=$(rpm --queryformat "%{NAME}\n" -qp *.src.rpm)
NVR=$(rpm --queryformat "%{NAME}-%{VERSION}-%{RELEASE}\n" -qp *.src.rpm)
popd

RPMDIR=${CURRENTDIR}/${PACKAGE}_repo
rm -rf ${RPMDIR}
mkdir -p ${RPMDIR}

mv somewhere/* ${RPMDIR}/

archive_variables
