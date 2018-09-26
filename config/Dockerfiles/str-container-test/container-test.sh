#!/bin/bash
set -e

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi
export TEST_ARTIFACTS=${CURRENTDIR}/logs
if [ -z "${TEST_LOCATION:-}" ]; then
    export TEST_LOCATION=https://src.fedoraproject.org/container/${container}
fi

if [ -z "${TAG:-}" ]; then
    export TAG=container
fi
# The test artifacts must be an empty directory
rm -rf ${TEST_ARTIFACTS}
mkdir -p ${TEST_ARTIFACTS}

# Try to update for few times, if for some reason could not update,
# continue test with installed STR version
str_attempts=1
while [ $str_attempts -le 5 ]; do
    if yum update -y standard-test-roles; then
        break
    fi
  ((str_attempts++))
done
rpm -q standard-test-roles

# Invoke tests according to section 1.7.2 here:
# https://fedoraproject.org/wiki/Changes/InvokingTests

if [ -z "${container:-}" ]; then
	if [ $# -lt 1 ]; then
		echo "No container defined"
		exit 2
	else
		container="$1"
	fi
fi

# Check out the dist-git repository for this container
rm -rf ${container}
if ! git clone ${TEST_LOCATION}; then
	echo "No dist-git repo for this container! Exiting..."
	exit 0
fi

# The specification requires us to invoke the tests in the checkout directory
pushd ${container}

# Check out the appropriate branch and rev
if [ -z ${build_pr_id} ]; then
    git checkout ${branch}
    git checkout ${rev}
else
    git checkout ${branch}
    curl --insecure -L ${TEST_LOCATION}/pull-request/${build_pr_id}.patch > pr_${build_pr_id}.patch
    git apply pr_${build_pr_id}.patch
fi

# Check if there is a tests dir from dist-git, if not, exit
if [ -d tests ]; then
     pushd tests
else
     echo "No tests for this container! Exiting..."
     exit 0
fi

# This will introduce a problem with concurrency as it has no locks
function clean_up {
    cat ${TEST_ARTIFACTS}/test.log
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
set -xo pipefail
for playbook in tests*.yml; do
	if [ -f ${playbook} ]; then
		timeout 4h ansible-playbook -v --inventory=$ANSIBLE_INVENTORY $PYTHON_INTERPRETER \
			--extra-vars "artifacts=$TEST_ARTIFACTS" \
			--tags ${TAG} ${playbook} $@ | tee ${TEST_ARTIFACTS}/${playbook}-run.txt
	fi
done
popd
popd
