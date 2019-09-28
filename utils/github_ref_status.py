#!/usr/bin/env python2

"""
Retrieve Status + Context from a github ref (branch, sha)

Depends on : python & python-requests (2.7)
"""

import os
import sys
import argparse
try:
    import json
except ImportError:
    import simplejson as json
import requests

EPILOG="""Example Usage, block further testing of a PR until Travis CI passes:

$ ./github_ref_status.py -t <token> -o acme -r anvil <PR HEAD sha> | \\
        grep -q 'success overall' && run_more_tests.sh

"""

def parse_argv(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     epilog=EPILOG,
                                     formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-t', '--token', required=True,
                      help="Access token for github")
    parser.add_argument('-o', '--owner', required=True,
                      help="Owner name of the repository (left side of slash)")
    parser.add_argument('-r', '--repo', required=True,
                      help="Repository name (right side of slash)")
    parser.add_argument('-s', '--showtarget', action='store_true', default=False,
                        help="Show the 'target' url for each status item")
    parser.add_argument('ref', help="SHA, a branch name, or a tag name.")
    return parser.parse_args(argv[1:])


def main(argv=None):
    options = parse_argv(argv)
    if options.showtarget:
        stdout = lambda context, state, target: sys.stdout.write("{0} {1} {2}\n".format(context, state, target))
    else:
        stdout = lambda context, state, target: sys.stdout.write("{0} {1}\n".format(state, context))

    # Ref: https://developer.github.com/v3/repos/statuses/#get-the-combined-status-for-a-specific-ref
    url = ("https://api.github.com/repos/{0}/{1}/commits/{2}/status"
           "".format(options.owner, options.repo, options.ref))
    target = ("https://github.com/{0}/{1}/commits/{2}"
              "".format(options.owner, options.repo, options.ref))
    response = requests.get(url, headers=dict(Authorization="token {0}".format(options.token)))
    if response.status_code != 200:
        raise ValueError("Response code {0} != 200 while retrieving {1}."
                         "".format(response.status_code, url))
    response_json = response.json()
    overall_state = response_json.get("state")
    if not overall_state:
        raise ValueError("Response good, but does not include an overall state (yet).")
    stdout("overall", overall_state, target)
    statuses = response_json.get("statuses", [])
    # N/B: Does not cope with any pagination
    # Ref: https://developer.github.com/v3/guides/traversing-with-pagination/
    for status in statuses:
        context = status.get("context", "<none>")
        state = status.get("state", "<none>")
        target = status.get("target_url", target)
        stdout(context, state, target)


if __name__ == '__main__':
    main(sys.argv)
