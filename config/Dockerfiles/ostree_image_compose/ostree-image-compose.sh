#!/usr/bin/sh

set -xeuo pipefail

# A simple shell script to automate v2c converstion
# using Image Factory in a container

# argument 1: Path to file containing the image to be converted

# Factory defaults to wanting a root PW in the TDL - this causes
# problems with converted images - just force it
# TODO: Point the working directories at the bind mounted location?

base_dir="$(dirname $0)"

# Start libvirtd
ls /var/run/libvirt
mkdir -p /var/run/libvirt
libvirtd &
sleep 5
virtlogd &

chmod 666 /dev/kvm

function clean_up {
  # Add some debug here since I want to make sure I see what's in $basedir
  ls $base_dir
  kill $(jobs -p)
  for screenshot in /var/lib/oz/screenshots/*.ppm; do
      [ -e "$screenshot" ] && cp $screenshot /home/output/logs
  done

  [ -e "$base_dir/fedora-atomic.ks" ] && cp $base_dir/fedora-atomic.ks /home/output/logs
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

# Do our thing
if [ "${branch}" = "rawhide" ]; then
    VERSION="rawhide"
else
    VERSION=$(echo $branch | sed -e 's/[a-zA-Z]*//')
fi

REF="fedora/${branch}/x86_64/atomic-host"

mkdir -p /home/output/logs

imgdir=/var/lib/imagefactory/storage/

version=$(ostree --repo=/home/output/ostree show --print-metadata-key=version $REF| sed -e "s/'//g")
release=$(ostree --repo=/home/output/ostree rev-parse $REF| cut -c -15)

if [ -d "/home/output/images" ]; then
    # Find the last image we pushed
    prev_img=$(ls -tr /home/output/images/fedora-atomic-*.qcow2 | tail -n 1)
    prev_rel=$(echo $prev_img | sed -e 's/.*-\([^-]*\).qcow2/\1/')
    # Don't fail if the previous build has been pruned
    (rpm-ostree db --repo=/home/output/ostree diff $prev_rel $release || echo "Previous build has been pruned") | tee /home/output/logs/packages.txt
else
    mkdir /home/output/images
fi

pushd /home/output/ostree
python -m SimpleHTTPServer &
popd

# Grab the kickstart file
cp $base_dir/config/ostree/fedora-atomic-${branch}.ks fedora-atomic.ks

# Put new url into the kickstart file
sed -i "s|^ostreesetup.*|ostreesetup --nogpg --osname=fedora-atomic --remote=fedora-atomic --url=http://192.168.122.1:8000/ --ref=$REF|" ./fedora-atomic.ks

# point to upstream
sed -i "s|\(%end.*$\)|ostree remote delete fedora-atomic\nostree remote add --set=gpg-verify=false fedora-atomic http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n\1|" ./fedora-atomic.ks

# Create a tdl file for imagefactory
#       <install type='url'>
#           <url>http://download.fedoraproject.org/pub/fedora/linux/releases/25/Everything/x86_64/os/</url>
#       </install>
cat <<EOF >./fedora-${branch}.tdl
<template>
    <name>${branch}</name>
    <os>
        <name>Fedora</name>
        <version>${VERSION}</version>
        <arch>x86_64</arch>
        <install type='iso'>
            <iso>file:///home/output/netinst/Fedora-Everything-netinst-x86_64.iso</iso>
        </install>
        <rootpw>password</rootpw>
        <kernelparam>console=ttyS0</kernelparam>
    </os>
</template>
EOF

#export LIBGUESTFS_BACKEND=direct

imagefactory --debug --imgdir $imgdir --timeout 3000 base_image ./fedora-${branch}.tdl --parameter offline_icicle true --file-parameter install_script ./fedora-atomic.ks

# convert to qcow
imgname="fedora-atomic-$version-$release"
qemu-img convert -c -p -O qcow2 $imgdir/*body /home/output/images/$imgname.qcow2

# delete images over 3 days old
find /home/output/images/ -type f -mtime +3 -exec rm {} \;

# Also delete if we have more than 3 images (from manual runs)
pushd /home/output/images
ls -t | sed -e '1,3d' | xargs --no-run-if-empty -d '\n' rm
ln -sf $imgname.qcow2 latest-atomic.qcow2
popd

# Record the commit so we can test it later
commit=$(ostree --repo=/home/output/ostree rev-parse ${REF})
cat << EOF > /home/output/logs/ostree.props
builtcommit=$commit
image2boot=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/images/$imgname.qcow2
image_name=$imgname.qcow2
EOF
