#!/usr/bin/sh

set -xeuo pipefail

base_dir="$( pwd )"

# Setup defaults for IMG_URL and ENABLE_VM
export IMG_URL=${IMG_URL:=/home/images/latest-atomic.qcow2}
export ENABLE_VM=${ENABLE_VM:=false}

function clean_up {
    set +e
    ara generate junit - > ${base_dir}/logs/ansible_xunit.xml
    if [ -e "$base_dir/inventory" ]; then
        virsh screenshot --file ${base_dir}/logs/atomic-host.ppm atomic-host-fedoraah
        ansible-playbook -vv -i hosts ${base_dir}/ci-pipeline/playbooks/setup-libvirt-image.yml -e state=absent -e skip_init=true
    fi
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM


export ara_location=$(python -c "import os,ara; print(os.path.dirname(ara.__file__))")
export ANSIBLE_CALLBACK_PLUGINS=$ara_location/plugins/callbacks
export ANSIBLE_ACTION_PLUGINS=$ara_location/plugins/actions
export ANSIBLE_LIBRARY=$ara_location/plugins/modules

mkdir -p ${base_dir}/logs

cat << EOF > hosts
[libvirt-hosts]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python
EOF

export ANSIBLE_HOST_KEY_CHECKING=False

# If using a VM in the example
if [ "${ENABLE_VM}" == "true" ]; then

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
       img_url: $IMG_URL
       admin_ssh_rsa: $pubkey
EOF

    # Start test VM
    ansible-playbook -vv -i hosts ${base_dir}/ci-pipeline/playbooks/setup-libvirt-image.yml -e state=present -e skip_init=true

    # For running playbook on a cloud image VM inside the sample pipeline container
    ipaddress=$(cat libvirt-hosts | awk -F= '/ansible_ssh_host=/ { print $2 }')
    cat << EOF > inventory
    [pipeline_sample_container_slave]
    $ipaddress ansible_user=admin ansible_ssh_pass=admin ansible_become=true ansible_become_pass=admin
EOF
    echo "Running example playbook on a cloud VM image inside the sample pipeline container"
    ansible-playbook -vv i inventory ${base_dir}/ci-pipeline/playbooks/pipeline-sample-boot-verify.yml -l pipeline_sample_container_slave
else
    echo "Running example playbook on the sample pipeline container"
    ansible-playbook -vv -i hosts ${base_dir}/ci-pipeline/playbooks/pipeline-sample.yml
fi
