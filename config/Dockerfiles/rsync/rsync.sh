#!/bin/sh -x

set -x

#rsync_paths="ostree"
#rsync_from="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/f26/"
#rsync_to="/home/output/"

if [[ ! -v rsync_opts ]]; then
    rsync_opts="--delete"
fi

for v in $rsync_paths; do
    # Make sure the destination path exists
    OFS=$IFS
    IFS="/"
    for rsync_path in ${rsync_to}; do
        IFS=$OIFS
        if [ -z "${built_path}" ]; then
            if [ -n "${rsync_path}" ]; then
                built_path="${rsync_path}"
            else
                built_path="/"
            fi
        else
            built_path="${built_path}/${rsync_path}"
            rsync ${tmp_dir}/. ${built_path}/
        fi
    done
    rsync -q ${rsync_from}${v}/
    # rsync rc:23     Partial transfer due to error
    if [ $? -eq 23 ]; then
        echo "Partial transfer due to error, could be source doesn't exist?"
    else
        rsync ${rsync_opts} --stats -a ${rsync_from}${v}/ ${rsync_to}${v}/
    fi
done
