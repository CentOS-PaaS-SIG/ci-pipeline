#!/bin/env python
import json
import sys
import os.path

# Exit 2 if upstream package list doesnt exist
# Exit 1 if file exists, but package isnt in the list

jsonpath = 'fedora-atomic/fedora-atomic-host-base.json'

# Make sure json file exists
if not os.path.isfile(jsonpath):
    print("Could not find upstream package json file")
    sys.exit(2)

jsonfile = open(jsonpath, 'r').read()
atomicjson = json.loads(jsonfile)
mypackage = sys.argv[1]

# Check if package exists in the json file
# Check both all packages and x86_64 specific packages
if mypackage in atomicjson["packages"] or mypackage in atomicjson["packages-x86_64"]:
    print ("Package of interest!")
    sys.exit(0)

# Fail if not
sys.exit(1)
