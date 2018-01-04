# !/bin/env python
import json
import sys

# Exit 2 if upstream package list doesn't exist
# Exit 1 if file exists, but package isn't in the list
# Exit 0 if file exists, and package is in the list

jsonpath = 'fedora-atomic/fedora-atomic-host-base.json'

try:
    with open(jsonpath, 'r') as f:
        atomicjson = json.load(f)
    mypackage = sys.argv[1]

    # Check if package exists in the json file
    # Check both all packages and x86_64 specific packages
    if mypackage in atomicjson["packages"] or mypackage in atomicjson["packages-x86_64"]:
        print ("Package of interest!")
        sys.exit(0)
    # Fail if not
    sys.exit(1)
except IOError as e:
    print("Could not find upstream package json file")
    sys.exit(2)
