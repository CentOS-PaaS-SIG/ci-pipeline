#!/bin/bash
set -eux

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi
export TEST_ARTIFACTS=${CURRENTDIR}/logs
if [ -z "${TEST_SUBJECTS:-}" ]; then
    export TEST_SUBJECTS=${CURRENTDIR}/untested-atomic.qcow2
fi
# The test artifacts must be an empty directory
rm -rf ${TEST_ARTIFACTS}
mkdir -p ${TEST_ARTIFACTS}

# Invoke tests according to section 1.7.2 here:
# https://fedoraproject.org/wiki/Changes/InvokingTests

if [ -z "${package:-}" ]; then
	if [ $# -lt 1 ]; then
		echo "No package defined"
		exit 1
	else
		package="$1"
	fi
fi

# Make sure we have or have downloaded the test subject
if [ -z "${TEST_SUBJECTS:-}" ]; then
	echo "No subject defined"
	exit 1
elif ! file ${TEST_SUBJECTS:-}; then
	wget -q -O testimage.qcow2 ${TEST_SUBJECTS}
	export TEST_SUBJECTS=${PWD}/testimage.qcow2
fi

# Check out the upstreamfirst repository for this package
rm -rf ${package}
if ! git clone https://upstreamfirst.fedorainfracloud.org/${package}; then
	echo "No upstreamfirst repo for this package! Exiting..."
	exit 0
fi

# The specification requires us to invoke the tests in the checkout directory
pushd ${package}

function clean_up {
     rm -rf tests/package
     mkdir -p tests/package
     cp ${TEST_ARTIFACTS}/* tests/package/
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

# The inventory must be from the test if present (file or directory) or defaults
if [ -e inventory ] ; then
    ANSIBLE_INVENTORY=$(pwd)/inventory
    export ANSIBLE_INVENTORY
fi

# Link test doesn't work on rawhide https://bugzilla.redhat.com/show_bug.cgi?id=1526615
# Loginctl test doesn't work on rawhide https://bugzilla.redhat.com/show_bug.cgi?id=1526621
if [ "$package" == "systemd" ]; then
    sed -i '/link/c\' tests.yml
    sed -i '/loginctl/c\' tests.yml
fi

set +u
PYTHON_INTERPRETER=""

if [[ ! -z "${python3}" && "${python3}" == "yes" ]] ; then
    PYTHON_INTERPRETER='--extra-vars ansible_python_interpreter=/usr/bin/python3'
fi
set -u

# Invoke each playbook according to the specification
for playbook in tests*.yml; do
	if [ -f ${playbook} ]; then
		ansible-playbook --inventory=$ANSIBLE_INVENTORY $PYTHON_INTERPRETER \
			--tags classic ${playbook}
	fi
done
popd
