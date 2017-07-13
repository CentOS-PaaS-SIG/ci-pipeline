#!/bin/bash

# Check if there is an upstream first repo for this package
curl -s --head https://upstreamfirst.fedorainfracloud.org/${package} | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
if [ $? -ne 0 ]; then
     echo "No upstream repo for this package! Exiting..."
     exit 1
fi
# Clone standard-test-roles repo
git clone https://pagure.io/standard-test-roles.git
pushd standard-test-roles
# Write test_cloud.yml file
cat << EOF > test_cloud.yml
---
- hosts: localhost
  vars:
    artifacts: ./
    playbooks: ./${package}/test_local.yml
  vars_prompt:
  - name: subjects
    prompt: "A QCow2/raw test subject file"
    private: no

  roles:
  - standard-test-cloud
EOF
if ! [ -f ${package}/test_local.yml ]; then
     # Write test_local.yml header
     cat << EOF > ${package}/test_local.yml
---
- hosts: localhost
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
          echo "    - $test" >> ${package}/test_local.yml
     done
fi
# Execute the tests
sudo ansible-playbook test_cloud.yml -e artifacts=/tmp/artifacts -e subjects=${image_location}
exit $?
