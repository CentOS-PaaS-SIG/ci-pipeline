#!/bin/sh -x

set -x

#rsync_paths="ostree"
#rsync_from="fedora-atomic@artifacts.ci.centos.org::fedora-atomic/f26/"
#rsync_to="/home/output/"

for v in $rsync_paths; do
    rsync --delete --stats -a ${rsync_from}${v}/ ${rsync_to}${v}/
done
