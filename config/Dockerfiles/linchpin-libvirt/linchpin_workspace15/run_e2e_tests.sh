#!/bin/sh -x

su - -c "echo Running as Username $USER"
echo "Inserting img_src"
img_src=$(find /workDir/workspace -name "untested-atomic.qcow2" | tail -n 1)
sed -i "s|        image_src\:.*|        image_src\: \"file\:\/\/$img_src\"|" /root/linchpin_workspace/topologies/example-topology.yml
su - -c "mkdir ~/.ssh"

retries=3

for ((i=0; i<retries; i++)); do
    echo "Running linchpin up inside libvirt container"
    su - -c "linchpin -v -w /root/linchpin_workspace up" && su - -c "linchpin -v -w /root/linchpin_workspace drop" 
    [[ $? -eq 0 ]] && break

    echo "something went wrong, let's wait 20 seconds and retry"
    sleep 20
done

[[ $retries -eq i ]] && { echo "Failed!"; exit 1; }

cat /tmp/e2e.log
