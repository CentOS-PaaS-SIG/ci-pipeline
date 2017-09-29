#!/bin/bash
set -eu

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi
export TEST_SUBJECTS=${CURRENTDIR}/untested-atomic.qcow2
export TEST_ARTIFACTS=${CURRENTDIR}/logs
# The test artifacts must be an empty directory
rm -rf ${TEST_ARTIFACTS}
mkdir -p ${TEST_ARTIFACTS}

# Invoke tests according to section 1.7.2 here:
# https://fedoraproject.org/wiki/Changes/InvokingTests

if [ -z "${package:-}" ]; then
	if [ $# -lt 1 ]; then
		echo "No package defined"
		exit 2
	else
		package="$1"
	fi
fi

# Make sure we have or have downloaded the test subject
if [ -z "${TEST_SUBJECTS:-}" ]; then
	echo "No subject defined"
	exit 2
elif ! file ${TEST_SUBJECTS:-}; then
	wget -q -O testimage.qcow2 ${TEST_SUBJECTS}
	export TEST_SUBJECTS=${PWD}/testimage.qcow2
fi

# Check out the dist-git repository for this package
rm -rf ${package}
if ! git clone https://src.fedoraproject.org/rpms/${package}; then
	echo "No dist-git repo for this package! Exiting..."
	exit 0
fi

# The specification requires us to invoke the tests in the checkout directory
pushd ${package}

# Check out the appropriate branch
git checkout ${branch}

# Check if there is a tests dir from dist-git, if not, exit
if [ -d tests ]; then
     pushd tests
else
     echo "No tests for this package! Exiting..."
     exit 0
fi

# This will introduce a problem with concurrency as it has no locks
function clean_up {
if [[ -z "${RSYNC_USER}" || -z "${RSYNC_SERVER}" || -z "${RSYNC_DIR}" || -z "${RSYNC_PASSWORD}" ]]; then echo "Told to rsync but missing rsync env var(s)" ; exit 1 ; fi
     RSYNC_BRANCH=${branch}
     if [ "${branch}" = "master" ]; then
         RSYNC_BRANCH=rawhide
     fi
     RSYNC_LOCATION="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/${RSYNC_BRANCH}"
     rsync --stats -a ${TEST_ARTIFACTS}/* ${RSYNC_LOCATION}/repo/${package}_repo/logs
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

# The inventory must be from the test if present (file or directory) or defaults
ANSIBLE_INVENTORY=$(test -e inventory && echo inventory || echo /usr/share/ansible/inventory)
export ANSIBLE_INVENTORY

# Invoke each playbook according to the specification
for playbook in tests*.yml; do
	if [ -f ${playbook} ]; then
		ansible-playbook --inventory=$ANSIBLE_INVENTORY \
			--extra-vars "subjects=$TEST_SUBJECTS" \
			--extra-vars "artifacts=$TEST_ARTIFACTS" \
			--tags atomic ${playbook}
	fi
done
popd
popd
