#!/bin/sh -x

echo "Running linchpin up inside libvirt container"

linchpin -v -w /root/linchpin_workspace up

cat /tmp/e2e.log
