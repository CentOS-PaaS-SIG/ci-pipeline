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

dnf update -y standard-test-roles
rpm -q standard-test-roles

ansible-playbook -v --inventory=${ANSIBLE_INVENTORY} \
	--extra-vars "subjects=${TEST_SUBJECTS}" \
	--extra-vars "rpm_repo=${rpm_repo}" \
	/tmp/rpm-verify.yml
