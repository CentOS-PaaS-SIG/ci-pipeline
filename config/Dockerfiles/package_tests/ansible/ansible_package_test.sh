#!/bin/bash

# This script requires that the docker run mounts the artifacts
# dir to /tmp/artifacts, the ansible inventory file to /tmp/inventory,
# and the ssh private key to /tmp/ssh_key

# Check if there is an upstream first repo for this package
curl -s --head https://upstreamfirst.fedorainfracloud.org/${package} | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
if [ $? -ne 0 ]; then
     echo "No upstream repo for this package! Exiting..."
     exit 1
fi
# Clone standard-test-roles repo
git clone https://pagure.io/standard-test-roles.git
pushd standard-test-roles
if [ -f ${package}/test_local.yml ]; then
     sed 's/hosts: localhost/hosts: all/' ${package}/test_local.yml > test_atomic.yml
else
     # Write test_atomic.yml header
     cat << EOF > test_atomic.yml
---
- hosts: all
  roles:
  - role: standard-test-beakerlib
    tests:
EOF
     # Find the tests
     git clone https://upstreamfirst.fedorainfracloud.org/${package}
     if [ $(find ${package} -name "runtest.sh" | wc -l) -eq 0 ]; then
          echo "No runtest.sh files found in package's repo. Exiting..."
          exit 1
     fi
     for test in $(find ${package} -name "runtest.sh"); do
          echo "    - $test" >> test_atomic.yml
     done
fi
# Get ready to execute tests
sed -i 's|^artifacts\:.*|artifacts\: /tmp/artifacts|' roles/standard-test-beakerlib/vars/main.yml
# Execute the tests
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i /tmp/inventory --private-key=/tmp/ssh_key --start-at-task='Define remote_artifacts if it is not already defined' test_atomic.yml
exit $?
