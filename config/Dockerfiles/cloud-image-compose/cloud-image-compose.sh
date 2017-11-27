#!/usr/bin/sh

set -xeuo pipefail

# A simple shell script to create a cloud image
# using Image Factory in a container. Currently,
# this container is hardcoded to build just rawhide.

# Requires package and rpm_repo variables where package is the
# rpm name and rpm_repo is the location of the repo
# ex. package=systemd rpm_repo=http://mywebserver.com/rpms/systemd

# Note: This is untested with rpm subjects with nvr's lesser in
# value than that of rawhide's.

base_dir="$(pwd)"
mkdir -p ${base_dir}/logs

if [[ -z "${package}" || -z "${rpm_repo}" ]]; then
    echo "This container requires both package and rpm_repo to be defined. Exiting..."
    exit 1
fi

# Tell oz to use enough ram
sed -i -e 's/# memory = 1024/memory = 2048/' /etc/oz/oz.cfg

# Start libvirtd
mkdir -p /var/run/libvirt
libvirtd &
sleep 5
virtlogd &

chmod 666 /dev/kvm

function clean_up {
  set +e
  kill $(jobs -p)
  for screenshot in /var/lib/oz/screenshots/*.ppm; do
      [ -e "$screenshot" ] && cp $screenshot ${base_dir}/logs
  done
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

{ #group for tee

# Factory defaults to wanting a root PW in the TDL - this causes
# problems with converted images - just force it

branch="rawhide"

mkdir -p ${base_dir}/images
# Spot where imagefactory puts images
imgdir=/var/lib/imagefactory/storage/

# Generate kickstart file from upstream - clone must be in here to get latest
if [ ! -d "${base_dir}/fedora-kickstarts" ]; then
    git clone https://pagure.io/fedora-kickstarts ${base_dir}/fedora-kickstarts
fi
# The centos7 pykickstart rpm doesnt support --noboot being in the .ks file
noboot=no
if grep -q '^autopart --noboot' "${base_dir}/fedora-kickstarts/fedora-cloud-base.ks" ; then
    autopart_line=$(cat ${base_dir}/fedora-kickstarts/fedora-cloud-base.ks | grep ^autopart)
    sed -i 's/^autopart.*/autopart/' ${base_dir}/fedora-kickstarts/fedora-cloud-base.ks
    noboot=yes
fi
# Flatten %include lines
ksflatten -c ${base_dir}/fedora-kickstarts/fedora-cloud-base.ks -o ${base_dir}/logs/fedora-cloud-base-flat.ks
if [ "$noboot" == "yes" ] ; then
    sed -i "s/^autopart/$autopart_line/" ${base_dir}/logs/fedora-cloud-base-flat.ks
fi
# Modify kickstart file to add rpm under test
sed -i '/^repo/a repo --name="'$package'" --baseurl='$rpm_repo'' ${base_dir}/logs/fedora-cloud-base-flat.ks
sed -i '/^%packages/a '$package'' ${base_dir}/logs/fedora-cloud-base-flat.ks

# Create a tdl file for imagefactory
cat <<EOF >${base_dir}/logs/fedora-${branch}.tdl
<template>
    <name>${branch}</name>
    <os>
        <name>Fedora</name>
        <version>${branch}</version>
        <arch>x86_64</arch>
        <install type='url'>
            <url>https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/x86_64/os/</url>
        </install>
        <rootpw>foobar</rootpw>
        <kernelparam>console=ttyS0</kernelparam>
    </os>
</template>
EOF

#export LIBGUESTFS_BACKEND=direct
export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1

imagefactory --debug --imgdir $imgdir --timeout 3000 base_image ${base_dir}/logs/fedora-${branch}.tdl --parameter offline_icicle true --file-parameter install_script ${base_dir}/logs/fedora-cloud-base-flat.ks

# convert to qcow
imgname="fedora-cloud-rawhide-$package"
qemu-img convert -c -p -O qcow2 $imgdir/*body ${base_dir}/images/$imgname.qcow2

} 2>&1 | tee ${base_dir}/logs/console.log #group for tee
