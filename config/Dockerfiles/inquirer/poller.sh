#!/bin/bash

# Parameters:
# timeout - if this many seconds pass and the file still DNE, exit 1
# interval - how many seconds to sleep between polls
# remote_file - file to poll for existence

set -x

i=0
while [[ "$i" -lt "$timeout" && $(curl -sI $remote_file | grep HTTP) != *"200"* ]]; do
    i=$((i+interval))
    sleep $interval
done

# Exit nonzero if we hit timeout
if [ "$i" -ge "$timeout" ]; then
    exit 1
fi
