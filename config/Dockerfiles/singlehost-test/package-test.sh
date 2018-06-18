#!/bin/bash
set -e

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi
export TEST_ARTIFACTS=${CURRENTDIR}/logs
if [ -z "${TEST_SUBJECTS:-}" ]; then
    export TEST_SUBJECTS=${CURRENTDIR}/untested-atomic.qcow2
fi
if [ -z "${TEST_LOCATION:-}" ]; then
    export TEST_LOCATION=https://src.fedoraproject.org/rpms/${package}
fi
if [ -z "${TAG:-}" ]; then
    export TAG=atomic
fi
# The test artifacts must be an empty directory
rm -rf ${TEST_ARTIFACTS}
mkdir -p ${TEST_ARTIFACTS}

# It was requested that these tests be run with latest rpm of standard-test-roles
dnf update -y standard-test-roles
rpm -q standard-test-roles

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
if ! git clone ${TEST_LOCATION}; then
	echo "No dist-git repo for this package! Exiting..."
	exit 0
fi

# The specification requires us to invoke the tests in the checkout directory
pushd ${package}

# Check out the appropriate branch and rev
if [ -z ${build_pr_id} ]; then
    git checkout ${branch}
    git checkout ${rev}
else
    git fetch -fu origin refs/pull/${build_pr_id}/head:pr
    git checkout pr
fi

# Check if there is a tests dir from dist-git, if not, exit
if [ -d tests ]; then
     pushd tests
else
     echo "No tests for this package! Exiting..."
     exit 0
fi

# This will introduce a problem with concurrency as it has no locks
function clean_up {
    rm -rf tests/package
    mkdir -p tests/package
    cp ${TEST_ARTIFACTS}/* tests/package/
    cat ${TEST_ARTIFACTS}/test.log
    set +u
    if [[ ! -z "${RSYNC_USER}" && ! -z "${RSYNC_SERVER}" && ! -z "${RSYNC_DIR}" && ! -z "${RSYNC_PASSWORD}"  && ! -z "${RSYNC_BRANCH}" ]]; then
        RSYNC_LOCATION="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/${RSYNC_BRANCH}"
        rsync --stats -arv tests ${RSYNC_LOCATION}/repo/${package}_repo/logs
    fi
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

# The inventory must be from the test if present (file or directory) or defaults
if [ -e inventory ] ; then
    ANSIBLE_INVENTORY=$(pwd)/inventory
    export ANSIBLE_INVENTORY
fi

set +u
PYTHON_INTERPRETER=""

if [[ ! -z "${python3}" && "${python3}" == "yes" ]] ; then
    PYTHON_INTERPRETER='--extra-vars ansible_python_interpreter=/usr/bin/python3'
fi
set -u

# Invoke each playbook according to the specification
set -x
for playbook in tests*.yml; do
	if [ -f ${playbook} ]; then
		timeout 4h ansible-playbook -v --inventory=$ANSIBLE_INVENTORY $PYTHON_INTERPRETER \
			--extra-vars "subjects=$TEST_SUBJECTS" \
			--extra-vars "artifacts=$TEST_ARTIFACTS" \
			--tags ${TAG} ${playbook}
	fi
done
popd
popd
