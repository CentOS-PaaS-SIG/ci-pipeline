#!/bin/sh -x

echo "Inserting img_src"
img_src=$(find /workDir/workspace -name ${image_name} | tail -n 1)
sed -i "s|        image_src\:.*|        image_src\: \"file\:\/\/$img_src\"|" /root/linchpin_workspace/topologies/example-topology.yml

echo "Running linchpin up inside libvirt container"

linchpin -v -w /root/linchpin_workspace up

cat /tmp/e2e.log
