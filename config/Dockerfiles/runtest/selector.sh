#!/bin/bash

if [[ ${suite} == "package" ]]; then
     /tmp/tmp-package-tests.sh
     exit $?
elif [[ ${suite} == "host" ]]; then
     /tmp/tmp-atomic-host-tests.sh
     exit $?
else
     "Please enter a suite value of either package or host."
     exit 1
fi
