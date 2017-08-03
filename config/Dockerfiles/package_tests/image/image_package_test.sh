#!/bin/bash

# Check if there is an upstream first repo for this package
curl -s --head https://upstreamfirst.fedorainfracloud.org/${package} | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
if [ $? -ne 0 ]; then
     echo "No upstream repo for this package! Exiting..."
     exit 1
fi
git clone https://upstreamfirst.fedorainfracloud.org/${package}
if [[ $(grep "standard-test-beakerlib" ${package}/*.yml) == "" ]]; then
	echo "No beakerlib tests in this repo! Exiting.."
	exit 0
fi
if [[ $(file ${TEST_SUBJECTS}) == *"No such file or directory"* ]]; then
	wget -q -O testimage.qcow2 ${TEST_SUBJECTS}
	export TEST_SUBJECTS=${PWD}/testimage.qcow2
fi
if [ -f ${package}/tests.yml ]; then
     # Execute the tests
     ansible-playbook --tags atomic ${package}/tests.yml
     exit $?
fi
# Note: The below code should work, but we are not calling it.
# The reason for this is that if repos do not have a tests.yml file,
# then they have not been modified since test tagging came out,
# which means we have no idea if the tests are meant to run/will pass
# on atomic hosts.

#else
#     # Write test_cloud.yml file
#     cat << EOF > test_cloud.yml
#---
#- hosts: localhost
#  vars:
#    artifacts: ./
#    playbooks: ./${package}/test_local.yml
#  vars_prompt:
#  - name: subjects
#    prompt: "A QCow2/raw test subject file"
#    private: no
#
#  roles:
#  - standard-test-cloud
#EOF
#     # Write test_local.yml header
#     cat << EOF > ${package}/test_local.yml
#---
#- hosts: all
#  roles:
#  - role: standard-test-beakerlib
#    tests:
#EOF
#     # Find the tests
#     if [ $(find ${package} -name "runtest.sh" | wc -l) -eq 0 ]; then
#          echo "No runtest.sh files found in package's repo. Exiting..."
#          exit 1
#     fi
#     for test in $(find ${package} -name "runtest.sh"); do
#          echo "    - $test" >> ${package}/test_local.yml
#     done
#     # Execute the tests legacy method
#     ansible-playbook test_cloud.yml -e subjects=$TEST_SUBJECTS -e artifacts=$TEST_ARTIFACTS
#     exit $?
#fi
