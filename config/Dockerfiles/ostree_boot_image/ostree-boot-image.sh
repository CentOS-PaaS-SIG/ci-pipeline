#!/usr/bin/sh

set -xeuo pipefail

base_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function clean_up {
    #kill $(jobs -p)
    #rm -rf $tmpdir
    ara generate junit - > /root/output/logs/ansible_xunit.xml
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

export ara_location=$(python -c "import os,ara; print(os.path.dirname(ara.__file__))")
export ANSIBLE_CALLBACK_PLUGINS=$ara_location/plugins/callbacks
export ANSIBLE_ACTION_PLUGINS=$ara_location/plugins/actions
export ANSIBLE_LIBRARY=$ara_location/plugins/modules

mkdir -p /root/output/logs

if [ -d "/root/output/images" ]; then
    pushd /root/output
    ls
    ls images
    if [ -d "images/latest-atomic.qcow2" ]; then
        # Use symlink if it exists
        IMG_URL="/root/output/images/latest-atomic.qcow2"
    else
        # Find the last image we pushed
        prev_img=$(ls -tr images/*.qcow2 | tail -n 1)
        IMG_URL="/root/output/$prev_img"
    fi
    popd
fi

# If image2boot is defined use that image, but if not fall back to the
# previous image built
bootimage=${image2boot:-$IMG_URL}

if ! [ -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
fi

pubkey=$(cat ~/.ssh/id_rsa.pub)

mkdir -p host_vars
cat << 'EOF' > host_vars/localhost.yml
qemu_img_path: /var/lib/libvirt/images
bridge: virbr0
virt_uri: qemu+tcp://libvirtd/system
gateway: 192.168.122.1
domain: local
libvirt_systems:
 atomic-host-fedoraah:
   ip: 192.168.122.200
   remoteip: libvirtd
   sshport: 2222
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

if [ "$state" = "absent" ]; then
    ansible-playbook -i hosts ci-pipeline/playbooks/setup-libvirt-image.yml -e state=absent -e skip_init=true
else
    # Start test VM
    ansible-playbook -i hosts ci-pipeline/playbooks/setup-libvirt-image.yml -e state=present -e skip_init=true

    PROVISION_STATUS=$?
    if [ "$PROVISION_STATUS" != 0 ]; then
        echo "ERROR: Provisioning\nSTATUS: $PROVISION_STATUS"
        exit 1
    fi

    cat << EOF > inventory
[ostree_compose_slave]
libvirtd ansible_port=2222 ansible_user=admin ansible_ssh_pass=admin ansible_become=true ansible_become_pass=admin
EOF

    ansible-playbook -i inventory ci-pipeline/playbooks/ostree-boot-verify.yml -l ostree_compose_slave -e "commit=$commit"

    BOOT_STATUS=$?
    if [ "$BOOT_STATUS" != 0 ]; then
        echo "ERROR: Provisioning\nSTATUS: $BOOT_STATUS"
        exit 1
    fi
fi
