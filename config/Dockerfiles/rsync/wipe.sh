#!/bin/sh -x

set -x

#rsync_to="${RSYNC_USER}@${RSYNC_SERVER}::${RSYNC_DIR}/${RSYNC_BRANCH}/tempImages_${dailyImageDir}"

rsync -vr --delete $(mktemp -d)/ ${rsync_to}/
