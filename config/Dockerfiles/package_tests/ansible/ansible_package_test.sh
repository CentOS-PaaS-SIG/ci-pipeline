#!/bin/bash

# This script requires that the docker run mounts the artifacts
# dir to /tmp/artifacts, the ansible inventory file to /tmp/inventory,
# and the ssh private key to /tmp/ssh_key, so mount some dir with
# the inventory and ssh_key to /tmp and expect artifacts there

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
if [ -f ${package}/tests.yml ]; then
     if [[ $(ansible-playbook --list-tags ${package}/tests.yml) != *"atomic"* ]]; then
         echo "No atomic tagged tests for this package!"
         exit 0
     fi
     sed 's/hosts: localhost/hosts: all/g' ${package}/tests.yml > ${package}/test_atomic.yml
     ansible-playbook -i /tmp/inventory --private-key=/tmp/ssh_key --tags=atomic --start-at-task='Define remote_artifacts if it is not already defined' ${package}/test_atomic.yml
     exit $?
# All code from here down is for legacy purposes and does not
# guarantee the tests running are meant to pass on atomic host
elif [ -f ${package}/test_local.yml ]; then
     sed 's/hosts: localhost/hosts: all/g' ${package}/test_local.yml > ${package}/test_atomic.yml
else
     # Write test_atomic.yml header
     cat << EOF > ${package}/test_atomic.yml
---
- hosts: all
  roles:
  - role: standard-test-beakerlib
    tests:
EOF
     # Find the tests
     if [ $(find ${package} -name "runtest.sh" | wc -l) -eq 0 ]; then
          echo "No runtest.sh files found in package's repo. Exiting..."
          exit 1
     fi
     for test in $(find ${package} -name "runtest.sh"); do
          echo "    - $test" >> ${package}/test_atomic.yml
     done
fi
ansible-playbook -i /tmp/inventory --private-key=/tmp/ssh_key --start-at-task='Define remote_artifacts if it is not already defined' ${package}/test_atomic.yml
exit $?
