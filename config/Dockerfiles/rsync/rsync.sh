#!/bin/sh -x

set -x

#rsync_paths="ostree"
#rsync_from="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/f26/"
#rsync_to="/home/output/"

if [[ ! -v rsync_opts ]]; then
    rsync_opts="--delete"
fi

for v in $rsync_paths; do
    rsync ${rsync_opts} --stats -a ${rsync_from}${v}/ ${rsync_to}${v}/
done