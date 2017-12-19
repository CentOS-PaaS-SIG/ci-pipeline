#!/usr/bin/sh

set -xeuo pipefail

base_dir="$( pwd )"

function clean_up {
    set +e
    ara generate junit - > ${base_dir}/logs/ansible_xunit.xml
    if [ -e "$base_dir/hosts" ]; then
        virsh screenshot --file ${base_dir}/logs/atomic-host.ppm atomic-host-fedoraah
        ansible-playbook -i hosts ${base_dir}/ci-pipeline/playbooks/setup-libvirt-image.yml -e state=absent -e skip_init=true
    fi
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM


curl -o /var/lib/libvirt/images/latest-atomic.qcow2 -z /var/lib/libvirt/images/latest-atomic.qcow2 ${IMG_URL}
if [ -f ]; then
    mkdir ${base_dir}/images
    ln -fs /var/lib/libvirt/images/latest-atomic.qcow2 ${base_dir}/images/latest-atomic.qcow2
fi

export ara_location=$(python -c "import os,ara; print(os.path.dirname(ara.__file__))")
export ANSIBLE_CALLBACK_PLUGINS=$ara_location/plugins/callbacks
export ANSIBLE_ACTION_PLUGINS=$ara_location/plugins/actions
export ANSIBLE_LIBRARY=$ara_location/plugins/modules

mkdir -p ${base_dir}/logs

#if [ -d "${base_dir}/images" ]; then
#    pushd ${base_dir}
#    if [ -d "images/latest-atomic.qcow2" ]; then
#        # Use symlink if it exists
#        IMG_URL="${base_dir}/images/latest-atomic.qcow2"
#    else
#        # Find the last image we pushed
#        prev_img=$(ls -tr images/*.qcow2 | tail -n 1)
#        IMG_URL="${base_dir}/$prev_img"
#    fi
#    popd
#fi

# If image2boot is defined use that image, but if not fall back to the
# previous image built
bootimage=${image2boot:-$IMG_URL}

if ! [ -f ~/.ssh/id_rsa ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
fi

pubkey=$(cat ~/.ssh/id_rsa.pub)

mkdir -p host_vars
cat << 'EOF' > host_vars/localhost.yml
qemu_img_path: /var/lib/libvirt/images
bridge: virbr1
gateway: 192.168.123.1
domain: local
libvirt_systems:
 atomic-host-fedoraah:
   admin_passwd: $5$uX5x24soDWv3G2TH$BYxhEq4HmxjKmyChV0.VTpqxfhqMaRk8LCr34KOg2C7
   memory: 3072
   disk: 10G
EOF
cat << EOF >> host_vars/localhost.yml
   img_url: $bootimage
   admin_ssh_rsa: $pubkey
EOF
cat << EOF > hosts
[libvirt-hosts]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python
EOF

export ANSIBLE_HOST_KEY_CHECKING=False

# Start test VM
ansible-playbook -i hosts ${base_dir}/ci-pipeline/playbooks/setup-libvirt-image.yml -e state=present -e skip_init=true

ipaddress=$(cat libvirt-hosts | awk -F= '/ansible_ssh_host=/ { print $2 }')
cat << EOF > inventory
[pipeline_sample_container_slave]
$ipaddress ansible_user=admin ansible_ssh_pass=admin ansible_become=true ansible_become_pass=admin
EOF

#ansible-playbook -i inventory ${base_dir}/ci-pipeline/playbooks/pipeline-sample.yml -l pipeline_sample_container_ -e "commit=$commit"
ansible-playbook -i inventory ${base_dir}/ci-pipeline/playbooks/pipeline-sample.yml -l pipeline_sample_container

