#!/bin/bash
set -eu

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi
# admin-unlock, pkg-layering and system-containers require reboots so cant be run with standard-test-roles
export ENABLED_TESTS="docker-build-httpd docker-swarm docker"
export TEST_SUBJECTS=${CURRENTDIR}/untested-atomic.qcow2
export TEST_ARTIFACTS=${CURRENTDIR}/logs
# The test artifacts must be an empty directory
rm -rf ${TEST_ARTIFACTS}
mkdir -p ${TEST_ARTIFACTS}

# Make sure we have or have downloaded the test subject
if [ -z "${TEST_SUBJECTS:-}" ]; then
	echo "No subject defined"
	exit 2
elif ! file ${TEST_SUBJECTS:-}; then
	wget -q -O testimage.qcow2 ${TEST_SUBJECTS}
	export TEST_SUBJECTS=${PWD}/testimage.qcow2
fi

# The inventory must be from the test if present (file or directory) or defaults
ANSIBLE_INVENTORY=$(test -e inventory && echo inventory || echo /usr/share/ansible/inventory)
export ANSIBLE_INVENTORY

# This will introduce a problem with concurrency as it has no locks
function clean_up {
if [[ -z "${RSYNC_USER}" || -z "${RSYNC_SERVER}" || -z "${RSYNC_DIR}" || -z "${RSYNC_PASSWORD}" ]]; then echo "Told to rsync but missing rsync env var(s)" ; exit 1 ; fi
     RSYNC_BRANCH=${branch}
     if [ "${branch}" = "master" ]; then
         RSYNC_BRANCH=rawhide
     fi
     RSYNC_LOCATION="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/${RSYNC_BRANCH}"
     rm -rf tests/integration
     mkdir -p tests/integration
     cp ${TEST_ARTIFACTS}/*.log tests/integration/
     rsync --stats -arv tests ${RSYNC_LOCATION}/repo/${package}_repo/logs
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

# Get integration tests repo
git clone https://github.com/projectatomic/atomic-host-tests
pushd atomic-host-tests

# Change test config
sed -i s/true/false/ tests/docker/vars.yml
RC=0
for test in $ENABLED_TESTS; do
	ansible-playbook -v --inventory=$ANSIBLE_INVENTORY \
		--extra-vars "subjects=$TEST_SUBJECTS" \
		tests/${test}/main.yml |& tee -a ${TEST_ARTIFACTS}/${test}.log
        if [ $? -ne 0 ]; then
		RC=1
	fi
done
popd
exit $RC
