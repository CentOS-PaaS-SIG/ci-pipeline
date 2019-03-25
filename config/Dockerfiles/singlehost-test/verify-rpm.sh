#!/bin/bash
set -ex

if [ -z "${rpm_repo}" ]; then
    echo "rpm_repo variable not provided. Exiting..."
    exit 1
fi

if [ -z "${TEST_SUBJECTS}" ]; then
    echo "No test subject defined. Exiting..."
    exit 1
fi

export TEST_ARTIFACTS=$(pwd)/logs
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

set +u
PYTHON_INTERPRETER=""

if [[ ! -z "${python3}" && "${python3}" == "yes" ]] ; then
    PYTHON_INTERPRETER='--extra-vars ansible_python_interpreter=/usr/bin/python3'
fi
set -u

set -xo pipefail
ansible-playbook -v --inventory=${ANSIBLE_INVENTORY} ${PYTHON_INTERPRETER} \
    --extra-vars "rpm_repo=${rpm_repo}" \
    --extra-vars "artifacts=$TEST_ARTIFACTS" \
    /tmp/rpm-verify.yml $@ | tee $(pwd)/logs/rpm-verify-out.txt
