#!/bin/sh -x

echo "Running linchpin up inside libvirt container"

linchpin -v -w /tmp/linchpin_workspace up

cat /tmp/e2e.log
