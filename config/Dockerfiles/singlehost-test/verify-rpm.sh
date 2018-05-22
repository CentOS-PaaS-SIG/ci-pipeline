#!/bin/bash
set -ex

if [[ -z "${package}" || -z "${expected}" ]]; then
    echo "package or expected variable not provided. Exiting..."
    exit 1
fi

if [ -z "${TEST_SUBJECTS}" ]; then
    echo "No test subject defined. Exiting..."
    exit 1
fi

set +u
PYTHON_INTERPRETER=""

if [[ ! -z "${python3}" && "${python3}" == "yes" ]] ; then
    PYTHON_INTERPRETER='--extra-vars ansible_python_interpreter=/usr/bin/python3'
fi
set -u

ansible-playbook -v --inventory=${ANSIBLE_INVENTORY} ${PYTHON_INTERPRETER} \
	--extra-vars "subjects=${TEST_SUBJECTS}" \
	--extra-vars "package=${package}" \
	--extra-vars "expected=${expected}.x86_64" \
	/tmp/rpm-verify.yml
