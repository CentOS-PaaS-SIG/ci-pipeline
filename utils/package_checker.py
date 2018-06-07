#!/bin/env python
import json
import sys
import httplib

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
    # Check if a package that comes from this distgit repo is in atomic
    else:
        # Open up a connection to mdapi
        mdapi_server = httplib.HTTPSConnection('apps.fedoraproject.org', timeout=10)
        # Get package name and branch from args
        mypackage = sys.argv[1]
        mybranch = sys.argv[2]
        
        resultPage = "/mdapi/" + mybranch + "/pkg/" + mypackage
        mdapi_server.request("GET",resultPage)
        res = mdapi_server.getresponse()
        if res.status != 200:
            print("mdapi lookup failed for %s" % resultPage)
            sys.exit(2)
        mdapi_message = res.read()
        # Convert to json
        mdapi_parsed = json.loads(mdapi_message)
        if "co-packages" in mdapi_parsed:
            # Perform the check
            if set(atomicjson["packages"]).isdisjoint(mdapi_parsed["co-packages"]) and set(atomicjson["packages-x86_64"]).isdisjoint(mdapi_parsed["co-packages"]):
                # Sets are disjoint so package is not in atomic host
                sys.exit(1)
            else:
                # Sets are not disjoint so package is in atomic host
                print ("Package of interest!")
                sys.exit(0)
except IOError as e:
    print("Could not find upstream package json file")
    sys.exit(2)
