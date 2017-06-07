#!/usr/bin/python

DOCUMENTATION = '''
---
module: beakerlib
short_description: Executes a beakerlib function on a remote node
description:
     - The beakerlib module takes one of the implemented beakerlib functions
       followed by a list of space-delimited arguments.
     - The function will be executed on all selected nodes. Currently implemented
       functions include:
       rlRun - The given command will be executed on all selected nodes. It will not be
       processed through the shell, so variables like C($HOME) and operations
       like C("<"), C(">"), C("|"), C(";") and C("&") will not work. The return code
       of the given command will be checked against the provided return code.  Only if
       they match will the module return with exit code 0.  Optionally, one can also
       provide a log file and string to write to said file at the time of execution of
       the command
       rlAssertGrep - The provided file will be grepped for the provided string.  If it
       exists in the file, it will return 0.
       rlAssertNotGrep - The provided file will be grepped for the provided string. If it
       does not exist in the file, it will return 0.
options:
  chdir:
    description:
      - cd into this directory before running the command
    required: false
    default: null
  function:
    description:
      - the beakerlib function to run
    required: true
    default: null
  command:
    description:
      - the command to run in the case of rlRun
    required: false
    default: null
  returncode:
    description:
      - the rc to check against in the case of rlRun
    required: false
    default: 0
  string:
    description:
      - the message to log during rlRun command execution or the string to
        grep for in rlAssertGrep and rlAssertNotGrep
    required: false
    default: null
  file:
    description:
      - the file to write the log message to during rlRun execution or the
        file to grep in rlAssertGrep and rlAssertNotGrep
    required: false
    default: null
notes:
    -  If you want to run a command through the shell (say you are using C(<),
       C(>), C(|), etc), you might see unexpected behavior as this mirrors the
       command module, not the shell module
author: 
    - Johnny Bieren
    - TODO... Red Hat? our team? unsure
'''

EXAMPLES = '''
# TODO Remove these one line examples - How to test module:
# - git clone git://github.com/ansible/ansible.git
# - source ansible/hacking/env-setup
# - ansible/hacking/test-module -m ./beakerlib.py -a "function=rlAssertGrep file=./outputfile string=\"i Am running a test\""
# - ansible/hacking/test-module -m ./beakerlib.py -a "function=rlRun command=\"cat abc\" returncode=1 string=\"i am running a test\" file=./outputfile"
# TODO these need to be checked if args have to be under args: 
# or can just be under the module like you would normally
- beakerlib:
  args:
    function: rlRun
    command: cat nonexistent_file
    returncode: 1
    chdir: somedir/
    string: Now trying to cat nonexistent_file
    file: /var/log/beakerlib.out
- beakerlib:
  args:
    function: rlAssertGrep
    string: Am I here
    file: some_log_file
'''

import datetime
import glob
import shlex
import os

from ansible.module_utils.basic import *
from ansible.module_utils.six import b

def rlRun(module, args, shell, returncode, logmessage, logfile):
    if args.strip() == '':
        module.fail_json(rc=256, msg="no command given")

    if not shell:
        args = shlex.split(args)

    startd = datetime.datetime.now()

    f = open(logfile, 'a')
    f.write(logmessage + '\n')
    f.close()

    rc, out, err = module.run_command(args, encoding=None)

    endd = datetime.datetime.now()
    delta = endd - startd

    if rc == returncode:
        finalrc = 0
    else:
        finalrc = rc

    return finalrc, out, err, startd, endd, delta

def rlAssertGrep(filename, phrase):
    startd = datetime.datetime.now()
    rc = 1
    with open(filename) as myfile:
        if phrase in myfile.read():
            rc = 0
        endd = datetime.datetime.now()
        delta = endd - startd
        return rc, startd, endd, delta

def main():

    module = AnsibleModule(
        argument_spec=dict(
          _raw_params = dict(),
          _uses_shell = dict(type='bool', default=False),
          command = dict(default=None),
          function = dict(required=True, type='str'),
          chdir = dict(type='path'),
          returncode = dict(type='int', default=0),
          string = dict(type='str', default=None),
          file = dict(type='path', default=None)
        )
    )

    chdir = module.params['chdir']
    beakerlibfunc = module.params['function']
    myfile = module.params['file']
    mystring = module.params['string']

    if chdir:
        chdir = os.path.abspath(chdir)
        os.chdir(chdir)

    if beakerlibfunc == 'rlRun':
        rc, out, err, startd, endd, delta = rlRun(module, module.params['command'], module.params['_uses_shell'], module.params['returncode'], mystring, myfile)

    if beakerlibfunc == 'rlAssertGrep':
        rc, startd, endd, delta = rlAssertGrep(myfile, mystring)
        out = ''
        err = ''

    if beakerlibfunc == 'rlAssertNotGrep':
        rc, startd, endd, delta = rlAssertGrep(myfile, mystring)
        out = ''
        err = ''
        rc = int(not rc)

    module.exit_json(
        function = beakerlibfunc,
        stdout   = out.rstrip(b("\r\n")),
        stderr   = err.rstrip(b("\r\n")),
        rc       = rc,
        start    = str(startd),
        end      = str(endd),
        delta    = str(delta),
        changed  = True
    )

if __name__ == '__main__':
    main()
