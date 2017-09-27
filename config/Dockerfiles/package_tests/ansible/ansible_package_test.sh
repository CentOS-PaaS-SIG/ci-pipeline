#!/bin/bash
set -eu

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
if ! git clone https://src.fedoraproject.org/rpms/${package}; then
	echo "No dist-git repo for this package! Exiting..."
	exit 0
fi

# The specification requires us to invoke the tests in the checkout directory
cd ${package}

# Check out the appropriate branch
# TODO: Where does this branch come from, currently f26?
git checkout f26

# The test artifacts must be an empty directory
TEST_ARTIFACTS=${TEST_ARTIFACTS:-$PWD/artifacts}
rm -rf $TEST_ARTIFACTS
export TEST_ARTIFACTS

# The inventory must be from the test if present (file or directory) or defaults
ANSIBLE_INVENTORY=$(test -e inventory && echo inventory || echo /usr/share/ansible/inventory)
export ANSIBLE_INVENTORY

# Invoke each playbook according to the specification
for playbook in tests/tests*.yml; do
	if [ -f ${playbook} ]; then
		ansible-playbook --inventory=$ANSIBLE_INVENTORY \
			--extra-vars "subjects=$TEST_SUBJECTS" --extra-vars "artifacts=$TEST_ARTIFACTS" \
			--tags atomic ${playbook}
	fi
done
