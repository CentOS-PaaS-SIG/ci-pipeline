#!/usr/bin/sh

set -xeuo pipefail

base_dir="$(pwd)"
mkdir -p $base_dir/logs

# Start libvirtd
mkdir -p /var/run/libvirt
libvirtd &
sleep 5
virtlogd &

pushd ${base_dir}/ostree
python -m SimpleHTTPServer &
popd

chmod 666 /dev/kvm

function clean_up {
  set +e
  pushd ${base_dir}/images
  ln -sf $(ls -tr fedora-atomic-*.qcow2 | tail -n 1) untested-atomic.qcow2
  popd
  kill $(jobs -p)
  for screenshot in /var/lib/oz/screenshots/*.ppm; do
      [ -e "$screenshot" ] && cp $screenshot ${base_dir}/logs
  done
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

{ #group for tee

# A simple shell script to automate v2c converstion
# using Image Factory in a container

# argument 1: Path to file containing the image to be converted

# Factory defaults to wanting a root PW in the TDL - this causes
# problems with converted images - just force it
# TODO: Point the working directories at the bind mounted location?

# Do our thing
if [ "${branch}" = "rawhide" ]; then
    VERSION="rawhide"
else
    VERSION=$(echo $branch | sed -e 's/[a-zA-Z]*//')
fi

REF="fedora/${branch}/x86_64/atomic-host"

touch ${base_dir}/logs/ostree.props

imgdir=/var/lib/imagefactory/storage/

if [ -d "${base_dir}/images" ]; then
    for image in ${base_dir}/images/fedora-atomic-*.qcow2; do
        if [ -e "$image" ]; then
            # Find the last image we pushed
            prev_img=$(ls -tr ${base_dir}/images/fedora-atomic-*.qcow2 | tail -n 1)
            prev_rel=$(echo $prev_img | sed -e 's/.*-\([^-]*\).qcow2/\1/')
            # Don't fail if the previous build has been pruned
            (rpm-ostree db --repo=${base_dir}/ostree diff $prev_rel $ostree_shortsha || echo "Previous build has been pruned") | tee ${base_dir}/logs/packages.txt
        fi
        break
    done
else
    mkdir ${base_dir}/images
fi

# Grab the kickstart file from fedora upstream
curl -o ${base_dir}/logs/fedora-atomic.ks https://pagure.io/fedora-kickstarts/raw/${branch}/f/fedora-atomic.ks

# Put new url into the kickstart file
sed -i "s|^ostreesetup.*|ostreesetup --nogpg --osname=fedora-atomic --remote=fedora-atomic --url=http://$(ip -o a s eth0 | awk '/inet / { print $4 }' | cut -d '/' -f 1):8000/ --ref=$REF|" ${base_dir}/logs/fedora-atomic.ks

# point to upstream
sed -i "s|\(%end.*$\)|ostree remote delete fedora-atomic\nostree remote add --set=gpg-verify=false fedora-atomic ${HTTP_BASE}/${branch}/ostree\n\1|" ${base_dir}/logs/fedora-atomic.ks

# Remove ostree refs create form upstream kickstart
sed -i "s|^ostree refs.*||" ${base_dir}/logs/fedora-atomic.ks
sed -i "s|^ostree admin set-origin.*||" ${base_dir}/logs/fedora-atomic.ks

# Pull down Fedora net install image if needed
if [ ! -e "${base_dir}/netinst" ]; then
    mkdir -p ${base_dir}/netinst
fi

pushd ${base_dir}/netinst
# First try and download iso from development
wget -c -r -nd -A iso --accept-regex "Fedora-Everything-netinst-.*\.iso" "http://dl.fedoraproject.org/pub/fedora/linux/development/${VERSION}/Everything/x86_64/iso/" || true
# If unable to download from development then try downloading from releases
wget -c -r -nd -A iso --accept-regex "Fedora-Everything-netinst-.*\.iso" "http://dl.fedoraproject.org/pub/fedora/linux/releases/${VERSION}/Everything/x86_64/iso/" || true

latest=$(ls --hide Fedora-Everything-netinst-x86_64.iso | tail -n 1)
if [ -n "$latest" ]; then
    ln -sf $latest Fedora-Everything-netinst-x86_64.iso
fi
popd

# Create a tdl file for imagefactory
#       <install type='url'>
#           <url>http://download.fedoraproject.org/pub/fedora/linux/releases/25/Everything/x86_64/os/</url>
#       </install>
cat <<EOF >${base_dir}/logs/fedora-${branch}.tdl
<template>
    <name>${branch}</name>
    <os>
        <name>Fedora</name>
        <version>${VERSION}</version>
        <arch>x86_64</arch>
        <install type='iso'>
            <iso>file://${base_dir}/netinst/Fedora-Everything-netinst-x86_64.iso</iso>
        </install>
        <rootpw>password</rootpw>
        <kernelparam>console=ttyS0</kernelparam>
    </os>
</template>
EOF

#export LIBGUESTFS_BACKEND=direct

imagefactory --debug --imgdir $imgdir --timeout 3000 base_image ${base_dir}/logs/fedora-${branch}.tdl --parameter offline_icicle true --file-parameter install_script ${base_dir}/logs/fedora-atomic.ks

# convert to qcow
qemu-img convert -c -p -O qcow2 $imgdir/*body ${base_dir}/images/$imgname.qcow2

# Record the commit so we can test it later
commit=$(ostree --repo=${base_dir}/ostree rev-parse ${REF})
cat << EOF > ${base_dir}/logs/ostree.props
builtcommit=$commit
image2boot=${HTTP_BASE}/${branch}/images/$imgname.qcow2
image_name=$imgname.qcow2
EOF

# Cleanup older qcow2 images
pushd ${base_dir}/images || exit 1
latest=""
if [ -e "latest-atomic.qcow2" ]; then
    latest=$(readlink latest-atomic.qcow2)
    latest_logdir=$(echo $latest | sed -e 's/.qcow2$//')
fi

# delete images and logs over 7 days old 
# but don't delete what our latest link points to
find . -maxdepth 1 -type f -mtime +7 ! -name "$latest" -exec rm -v {} \;
find . -maxdepth 1 -type d -mtime +7 ! -name "$latest_logdir" -exec rm -rv {} \;
popd

} 2>&1 | tee ${base_dir}/logs/console.log #group for tee
