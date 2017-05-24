#!/bin/bash

# This script takes a bash array as input
# and echoes out a simple jenkins compatible
# xunit file

# It expects an array where the array elements
# are variables, with the variables defining
# the return codes of the ansible playbooks

ARRAY=("$@")
if [ ${ARRAY} == "" ] ; then echo "No array input given. Exiting" ; exit 1 ; fi

echo "<?xml version='1.0' encoding='utf8'?>"
echo "<testsuites>"
echo "  <testsuite tests=\"0\">"
for playbook in ${!ARRAY[@]}; do
     echo "    <testcase classname=\"ansible-playbook\" name=\"${ARRAY[$playbook]}\">"
     if [ ${playbook} != "0" ]; then
          echo "      <error type=\"${playbook}\"/>"
     fi
     echo "      <system-out></system-out>"
     echo "    </testcase>"
done
echo "  </testsuite>"
echo "</testsuites>"
