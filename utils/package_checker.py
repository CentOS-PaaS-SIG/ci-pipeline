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
        # Open up a connection to the PDC
        pdc_server = httplib.HTTPSConnection('pdc.fedoraproject.org', timeout=10)
        # Get package name from args
        mypackage = sys.argv[1]
        
        # Set up array of packages
        childPackages = []
        # Set first page to pull. We only need the name field, which speeds it up
        resultPage = "/rest_api/v1/rpms/?arch=x86_64&arch=noarch&fields=name&srpm_name=" + mypackage
        while resultPage != None:
            pdc_server.request("GET",resultPage)
            res = pdc_server.getresponse()
            if res.status != 200:
                print("PDC lookup failed for %s" % resultPage)
                sys.exit(2)
            pdc_message = res.read()
            # Convert to json
            pdc_parsed = json.loads(pdc_message)
            if 'results' in pdc_parsed:
                # Add packages to array
                for package in pdc_parsed['results']:
                    childPackages = childPackages + [package['name']]
            # This will be None on the last page
            resultPage = pdc_parsed['next']
    # Perform the check
    if set(atomicjson["packages"]).isdisjoint(childPackages) and set(atomicjson["packages-x86_64"]).isdisjoint(childPackages):
        # Sets are disjoint so package is not in atomic host
        sys.exit(1)
    else:
        # Sets are not disjoint so package is in atomic host
        print ("Package of interest!")
        sys.exit(0)
except IOError as e:
    print("Could not find upstream package json file")
    sys.exit(2)
