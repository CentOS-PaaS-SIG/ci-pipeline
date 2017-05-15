#!/usr/bin/env python
from __future__ import print_function
import os
import json
import requests
import sys
from optparse import OptionParser

# This script will comment on a GitHub pull request.
#
# Example usage:
# ./pr-commenter.py --token <GH token> --commentfiles file1,file2 \
#  --pr 1 --prop-files props1,props2,props3 \
#  --consistency ghprbPullId,ghprbGhRepository \
#  --logvariable log_link --repo <GH Org>/<GH Repo>

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def list_callback(option, opt, value, parser):
    setattr(parser.values, option.dest, value.split(','))

class PR_functions:
    def check_results(self, file_list):
        rc = 1
        for file_to_check in file_list:
            print ("Checking if file: " + file_to_check + " exists.")
            if os.path.exists(file_to_check):
                print ("Found a file that exists: " + file_to_check)
                rc = 0
        return rc

    def create_body(self, comment_list):
        body = ''
        for file_to_add in comment_list:
            if os.path.exists(file_to_add):
                with open(file_to_add) as infile:
                    body = body + infile.read() + '\n'
        return body

    def get_field(self, prop_file, field):
        if not os.path.exists(prop_file):
            print ("The property file did not exist: " + prop_file)
            return ''
        myfile = open(prop_file)
        for line in myfile:
            fields = line.split("=")
            if fields[0] == field:
                field_long = ''.join(fields[1:])
                return field_long.split('\n', 1)[0]
        return ''

    def consistency(self, file_list, field_list):
        for field in field_list:
            field_value = self.get_field(file_list[0], field)
            for myfile in file_list:
                if field_value != self.get_field(myfile, field) or self.get_field(myfile, field) == '':
                    return False
        return True

    def get_comments(self, comment_var):
        if isinstance(comment_var, basestring):
            return comment_var
        else:
            return self.create_body(comment_var)

def main(args):
    if sys.version_info < (2,5):
        eprint("Python 2.5 or better is required.")
        sys.exit(1)

    # Parse the command line args
    usage = 'usage: %prog'
    parser = OptionParser()
    parser.add_option('-t', '--token', dest='token', default=None,
                      help='GitHub authorization token to use')
    parser.add_option('-c', '--comment', dest='comment', default=None,
                      help='String to comment to create GitHub comment')
    parser.add_option('--commentfiles', dest='commentfiles', default=None,
                      type='string', action='callback', callback=list_callback,
                      help='Comma separated (no quotes) list of files to append to create GitHub comment')
    parser.add_option('-r', '--repo', dest='repo', default=None,
                      help='Manually specify the GitHub repo to comment to (entire organization/repo)')
    parser.add_option('-p', '--pr', dest='pr', default=None,
                      help='Manually specify the GitHub pr to comment to')
    parser.add_option('-l', '--logfile', dest='log', default=None,
                      help='Manually specify a logfile to add to the comments')
    parser.add_option('--logvariable', dest='logvar', default=None,
                      help='Manually specify a logfile variable in the properties file to use as a log link')
    parser.add_option('--check', dest='list_to_check', default=None,
                      type='string', action='callback', callback=list_callback,
                      help='Comma separated (no quotes) list of result files to check for existence before commenting. If any one exists, script will proceed.')
    parser.add_option('--consistency', dest='consistent_fields', default=None,
                      type='string', action='callback', callback=list_callback,
                      help='Comma separated (no quotes) list of string fields to check for consistency across the property files')
    parser.add_option('--prop-files', dest='prop_files', default=None,
                      type='string', action='callback', callback=list_callback,
                      help='Comma separated (no quotes) list of property files to get fields from (if no repo/pr passed in, will check these files for ghprbGhRepository/ghprbPullId)')
    parser.add_option('-d', '--dry-run', dest='dryrun', action='store_true',
                      help='If passed in, comment will be printed but not posted to GitHub.')

    options, arguments = parser.parse_args(args)

    if options.token is None:
        eprint("You must provide a GitHub authorization token to use.")
        sys.exit(1)

    if options.comment is None and options.commentfiles is None:
        eprint("You must provide something to comment on the pull request.")
        sys.exit(1)

    if options.repo is None and options.prop_files is None:
        eprint("You did not pass in a repo nor any property files - cannot determine what repo to comment on.")
        sys.exit(1)

    if options.pr is None and options.prop_files is None:
        eprint("You did not pass in a pr number nor any property files - cannot determine what pr to comment on.")
        sys.exit(1)

    if options.logvar is not None and options.prop_files is None:
        eprint("You asked to search the property files for the log link, but did not pass in any property files.")
        sys.exit(1)

    if options.consistent_fields is not None and options.prop_files is None:
        eprint("You cannot give a list of fields to check for consistency without giving property files to find them in.")
        sys.exit(1)

    if options.list_to_check is not None and not isinstance(options.list_to_check, list):
        eprint("The list of result files passed in was not a list.")
        sys.exit(1)

    if options.consistent_fields is not None and not isinstance(options.consistent_fields, list):
        eprint("The list of consistent fields passed in was not a list.")
        sys.exit(1)

    if options.prop_files is not None and not isinstance(options.prop_files, list):
        eprint("The list of property files passed in was not a list.")
        sys.exit(1)

    try:
        commenter = PR_functions()
    except:
        eprint("Failed to initiate", sys.exc_info()[0])
        sys.exit(1)

    if options.list_to_check is not None:
        if commenter.check_results(options.list_to_check) == 1:
            eprint("The result files do not exist!")
            sys.exit(1)

    if options.consistent_fields is not None:
        if commenter.consistency(options.prop_files, options.consistent_fields) is False:
            eprint("The fields were not consistent across the property files, or a field asked to be checked did not exist in a property file.")
            sys.exit(1)

    if options.comment is not None:
        data = commenter.get_comments(options.comment)
    else:
        data = commenter.get_comments(options.commentfiles)
    if options.log is not None:
        data = data + "Log - " + options.log
    else:
        if options.logvar is not None:
            data = data + "Log - " + commenter.get_field(options.prop_files[0], options.logvar)

    if options.repo is not None:
        ghrepo = options.repo
    else:
        ghrepo = commenter.get_field(options.prop_files[0], 'ghprbGhRepository')
    if options.pr is not None:
        ghpr = options.pr
    else:
        ghpr = commenter.get_field(options.prop_files[0], 'ghprbPullId')

    # Post comment
    mydata = {'body': data}
    api_url = "https://api.github.com/repos/%s/issues/%s/comments" % \
               (ghrepo, ghpr)
    token_header = {'Authorization': 'token ' + options.token}

    # Check for dry run
    if options.dryrun:
        print("Comment would be created for \n%s \non PR #%s\n\
with the following comment: \n%s" % (ghrepo, ghpr, data))
        sys.exit(0)

    r = requests.post(api_url, data=json.dumps(mydata), headers=token_header)
    if r.status_code != requests.codes.created:
        eprint("Failed to add a comment [HTTP %d]" % r.status_code)
        eprint(r.headers)
        eprint(r.json())
        sys.exit(1)

if __name__ == '__main__':
    main(sys.argv[1:])
