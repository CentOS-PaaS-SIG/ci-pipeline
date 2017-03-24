#!/usr/bin/env python
from __future__ import print_function
import sys
import time
import requests
import json
from optparse import OptionParser
import pprint
pp = pprint.PrettyPrinter(indent=4)
token_header = dict()
keyword = None


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def has_retest_keyword(pr, prev_time):
    url = pr.get('comments_url')
    while True:
        request_comments = requests.get(url, headers=token_header)
        if request_comments.status_code != 200:
            eprint("Failed to retrieve")
            eprint("%s:%s" % (url, request_comments.status_code))
            sys.exit(1)
        comments = request_comments.json()
        for comment in comments:
            time_field = comment.get('updated_at')
            comment_time = time.strptime(time_field, '%Y-%m-%dT%H:%M:%SZ')
            body_field = comment.get('body')
            if comment_time > prev_time and body_field.find(keyword) != -1:
                return True
        if 'next' in request_comments.links:
            url = request_comments.links["next"]["url"]
        else:
            break
    return False


def has_active_commits(pr, prev_time):
    url = pr.get('commits_url')
    while True:
        request_commits = requests.get(url, headers=token_header)
        if request_commits.status_code != 200:
            eprint("Failed to retrieve")
            eprint("%s:%s" % (url, request_commits.status_code))
            sys.exit(1)
        commits = request_commits.json()
        for commit in commits:
            time_field = commit.get('commit').get('committer').get('date')
            commit_time = time.strptime(time_field, '%Y-%m-%dT%H:%M:%SZ')
            if commit_time > prev_time:
                return True
        if 'next' in request_commits.links:
            url = request_commits.links["next"]["url"]
        else:
            break
    return False


def get_active_prs(owner, repo, prev_time):
    prs = list()
    url = "https://api.github.com/repos/%s/%s/pulls" % (owner, repo)
    while True:
        request_pulls = requests.get(url, headers=token_header)
        if request_pulls.status_code != 200:
            eprint("Failed to retrieve")
            eprint("%s:%s" % (url, request_pulls.status_code))
            sys.exit(1)
        pulls = request_pulls.json()
        for pr in pulls:
            pr_time = time.strptime(pr.get('updated_at'), '%Y-%m-%dT%H:%M:%SZ')
            if pr_time > prev_time \
                    and (has_retest_keyword(pr, prev_time) or
                         has_active_commits(pr, prev_time)):
                prs.append(pr)
        if 'next' in request_pulls.links:
            url = request_pulls.links["next"]["url"]
        else:
            break
    return prs


def get_config_json(config_file):
    try:
        with open(config_file) as json_data:
            config = json.load(json_data)
    except (ValueError, IOError):
        config = dict()
    return config


def write_config(config_file, config):
    with open(config_file, 'w') as json_data:
        json.dump(config, json_data)


def get_prev_time(config, owner, repo):
    time_string = config.get("%s/%s" % (owner, repo))
    try:
        prev_time = time.strptime(time_string, '%Y-%m-%dT%H:%M:%SZ')
    except (TypeError, ValueError):
        prev_time = time.gmtime()
    return prev_time


def update_prev_time(config, owner, repo):
    time_string = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    config['%s/%s' % (owner, repo)] = time_string


def main(args):
    global token_header, keyword

    # Parse the command line args
    usage = 'usage: %prog'
    parser = OptionParser()
    parser.add_option('-c', '--config', dest='config_file',
                      default='config.json',
                      help='File to store previous run data in')
    parser.add_option('-t', '--token', dest='token',
                      default=None,
                      help='Authentication token to use.')
    parser.add_option('-k', '--keyword', dest='keyword',
                      default='retest',
                      help='keyword to use to trigger retesting')
    parser.add_option('-j', '--json', dest='json',
                      action="store_true",
                      help='Output in json format')
    options, arguments = parser.parse_args(args)

    try:
        owner, repo = arguments.pop().split('/')
    except (ValueError, IndexError):
        eprint("Please specify OWNER/REPO")
        sys.exit(1)

    if options.token:
        token_header = {'Authorization': 'token ' + options.token}
    keyword = options.keyword
    config = get_config_json(options.config_file)
    prev_time = get_prev_time(config, owner, repo)
    prs = get_active_prs(owner, repo, prev_time)
    update_prev_time(config, owner, repo)
    write_config(options.config_file, config)

    if options.json:
        # {
        #  'owner_repo': 'OWNER/REPO',
        #  'prs': [ 123, 321, 4325 ]
        # }
        output = dict(owner_repo="%s/%s" % (owner, repo),
                      prs=[pr.get('number') for pr in prs])
        print(json.dumps(output))
    else:
        for pr in prs:
            print("%s" % pr.get('number'))


if __name__ == '__main__':
    main(sys.argv[1:])
