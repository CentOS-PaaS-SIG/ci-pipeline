#!/bin/bash
set -xeo pipefail

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

{ #group for tee

# It was requested that these tests be run with latest rpm of standard-test-roles
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

if [ -z "${package:-}" ]; then
	if [ $# -lt 1 ]; then
        echo "No package defined" | tee "${TEST_ARTIFACTS}/FAIL_package-test.log"
		exit 2
	else
		package="$1"
	fi
fi

namespace=${namespace:-"rpms"}

tests_path="tests"
if [ "${namespace}" == "tests" ]; then
    tests_path="."
fi

# Make sure we have or have downloaded the test subject
if [ -z "${TEST_SUBJECTS:-}" ]; then
    echo "No subject defined"  | tee "${TEST_ARTIFACTS}/FAIL_package-test.log"
	exit 2
elif ! file ${TEST_SUBJECTS:-}; then
	wget -q -O testimage.qcow2 ${TEST_SUBJECTS}
	export TEST_SUBJECTS=${PWD}/testimage.qcow2
fi

# Check out the dist-git repository for this package
rm -rf ${package}
if ! git clone ${TEST_LOCATION}; then
    echo "Could not clone dist-git repo for this package! Exiting..."  | tee "${TEST_ARTIFACTS}/FAIL_package-test.log"
	exit 1
fi

# The specification requires us to invoke the tests in the checkout directory
pushd ${package}

# Check out the appropriate branch and rev
if [ -z ${build_pr_id} ]; then
    git checkout ${branch}
    git checkout ${rev}
else
    git checkout ${branch}
    git fetch -fu origin refs/pull/${build_pr_id}/head:pr
    # Setting git config and merge message in case we try to merge a closed PR, like it is done on stage instance
    git -c "user.name=Fedora CI" -c "user.email=ci@lists.fedoraproject.org"  merge pr -m "Fedora CI pipeline"
fi

# Check if there is a tests dir from dist-git, if not, exit
if [ -d ${tests_path} ]; then
     pushd ${tests_path}
else
     echo "No tests for this package! Exiting..."
     exit 0
fi

PATH_PIPELINE_INVENTORY=""

function sync_artifacts {
    if [[ -z $PATH_PIPELINE_INVENTORY ]]; then
        return
    fi
    # Run a playbook to get logs from the VM
    timeout 10m ansible-playbook --inventory=$PATH_PIPELINE_INVENTORY $PYTHON_INTERPRETER \
         /tmp/sync-artifacts.yml || true
}

# This will introduce a problem with concurrency as it has no locks
function clean_up {
    ret=$?
    sync_artifacts || true
    killall /usr/bin/qemu-system-x86_64 > /dev/null 2>&1 || true
    rm -rf tests/package
    mkdir -p tests/package
    cp -rp ${TEST_ARTIFACTS}/* tests/package/
    if [[ -e ${TEST_ARTIFACTS}/test.log ]]; then
        cat ${TEST_ARTIFACTS}/test.log
    fi
    set +u
    if [[ ! -z "${RSYNC_USER}" && ! -z "${RSYNC_SERVER}" && ! -z "${RSYNC_DIR}" && ! -z "${RSYNC_PASSWORD}"  && ! -z "${RSYNC_BRANCH}" ]]; then
        RSYNC_LOCATION="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/${RSYNC_BRANCH}"
        rsync --stats -arv tests ${RSYNC_LOCATION}/repo/${package}_repo/logs
    fi
    if [[ $ret -eq 124 ]]; then
        echo "FAIL: test aborted due to timeout" | tee "${TEST_ARTIFACTS}/FAIL_package-test.log"
    fi
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

# The inventory must be from the test if present (file or directory) or defaults
if [ -e inventory ] ; then
    if [ ! -x inventory ] ; then
        echo "FAIL: tests/inventory file must be executable" | tee "${TEST_ARTIFACTS}/FAIL_package-test.log"
        exit 1
    fi
    ANSIBLE_INVENTORY=$(pwd)/inventory
    export ANSIBLE_INVENTORY
fi

PYTHON_INTERPRETER='--extra-vars ansible_python_interpreter=/usr/bin/python3'
set -u

function provision_with_retry {
    # the script is running with set -e, but in this case we don't want to abort
    # if command fails, so set +e
    set +e
    attempts=5

    until [[ $attempts -eq 0 ]]; do
        # WORKAROUND until we have a better way to detect the VM failed to boot up
        # kill any other VM that might be running
        killall /usr/bin/qemu-system-x86_64 > /dev/null 2>&1 || true
        rm -f pipeline_inventory.yaml
        # set TEST_DEBUG so the VM stays up
        TEST_DEBUG=1 TEST_SUBJECTS=$TEST_SUBJECTS ansible-inventory --inventory=$ANSIBLE_INVENTORY --list --yaml | tee pipeline_inventory.yaml
        python3 -c 'import yaml; _dict = yaml.load(open("pipeline_inventory.yaml")); print(_dict["all"]["children"]["localhost"])'
        ret=$?
        # success
        if [[ $ret -eq 0 ]]; then
            break
        fi
        let attempts-=1
    done
    if [[ $ret -ne 0 ]]; then
        echo "FAIL: Could not provision inventory..."
        # add some sleep to help debug
        cat pipeline_inventory.yaml
        echo "FAIL: invalid inventory" | tee "${TEST_ARTIFACTS}/FAIL_package-test.log"
        exit 1
    fi

    set -e
    PATH_PIPELINE_INVENTORY=$(pwd)/pipeline_inventory.yaml
    return 0
}

if [[ `ls -1 tests*.yml 2>/dev/null | wc -l` == 0 ]]; then
    echo "FAIL: there is no tests*.yml" | tee "${TEST_ARTIFACTS}/FAIL_package-test.log"
    exit 1
fi

# Invoke each playbook according to the specification
for playbook in tests*.yml; do
	if [ -f ${playbook} ]; then
        ansible-playbook --list-tags ${playbook} > playbook-tags.txt
        if ! grep -e "TASK TAGS: \[.*\<${TAG}\>.*\]" playbook-tags.txt; then
            echo "SKIP: ${playbook} doesn't run on ${TAG}" >> ${TEST_ARTIFACTS}/test.log
            continue
        fi
        # should provision fresh VM for each tests* playbook
        provision_with_retry
        ANSIBLE_STDOUT_CALLBACK=yaml timeout 4h ansible-playbook -v --inventory=pipeline_inventory.yaml $PYTHON_INTERPRETER \
            --tags ${TAG} ${playbook} $@ | tee ${TEST_ARTIFACTS}/${playbook}-run.txt
	fi
done
popd
popd
} 2>&1 | tee ${TEST_ARTIFACTS}/console.log #group for tee
