#!/usr/bin/sh

set -xeuo pipefail

# A shell script that pulls the latest nightly from rcm
# and uses virt-customize to inject rpms into it. It 
# outputs a new qcow2 image for you to use.
#
# Note: This is only configured for rhel8 currently

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi
mkdir -p ${CURRENTDIR}/logs

# Start libvirtd
mkdir -p /var/run/libvirt
libvirtd &
sleep 5
virtlogd &

chmod 666 /dev/kvm

if [$branch != "rawhide"]; then
    branch=${branch:1}
fi

# Define proper install url
if [[ $(curl -q https://dl.fedoraproject.org/pub/fedora/linux/development/ | grep "${branch}/") != "" ]]; then
    INSTALL_URL="https://dl.fedoraproject.org/pub/fedora/linux/development/${branch}/CloudImages/x86_64/images/"
elif [[ $(curl -q https://dl.fedoraproject.org/pub/fedora/linux/releases/ | grep "${branch}/") != "" ]]; then
    INSTALL_URL="https://dl.fedoraproject.org/pub/fedora/linux/releases/${branch}/CloudImages/x86_64/images/"
else
    echo "Could not find installation source! Exiting..."
    exit 1
fi

wget --quiet -r --no-parent -A 'Fedora-Cloud-Base*.qcow2' ${INSTALL_URL}
DOWNLOADED_IMAGE_LOCATION=$(pwd)/$(find dl.fedoraproject.org -name "*.qcow2")

function clean_up {
  set +e
  pushd ${CURRENTDIR}/images
  cp ${DOWNLOADED_IMAGE_LOCATION} .
  ln -sf $(find . -name "*.qcow2") test_subject.qcow2
  popd
  kill $(jobs -p)
  # In case of first build, ensure image_artifacts dir exists
  mkdir -p ${image_artifacts}
  cp -rp ${CURRENTDIR}/images/* ${CURRENTDIR}/logs ${image_artifacts}
  #ln -sf ${ARTIFACT_MNT}/${package}  ${ARTIFACT_MNT}/latest
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

{ #group for tee

mkdir -p ${CURRENTDIR}/images

# Add custom rpms to image
while read rpm ; do
    rpm_name=$(echo $rpm | cut -d ' ' -f 1)
    TIMEDIFF=$(expr $(date '+%s') - $(date '+%s' -d $(echo $rpm | cut -d ' ' -f 2)))
    # Only rpms saved within last day
    if [[ $TIMEDIFF -le 86400 ]]; then
        virt-copy-in -a ${DOWNLOADED_IMAGE_LOCATION} ${ARTIFACT_MNT}/${rpm_name} /etc/yum.repos.d/
        for pkg in $(repoquery --disablerepo=\* --enablerepo=${rpm_name} --repofrompath=${rpm_name},${rpm_repo} --all | grep -v '\-debug\|\-devel' | rev | cut -d '-' -f 3- | rev ) ; do
            if ! virt-customize -a ${DOWNLOADED_IMAGE_LOCATION} --run-command "yum install -y --nogpgcheck --repofrompath=testrepo,file:///etc/yum.repos.d/${rpm_name} ${pkg}" ; then
                if [ $package == $rpm_name ] ; then
                    sed -i "/^${package}/d" ${manifest}
                fi
                exit 1
            fi
        done
    fi
done < $manifest

} 2>&1 | tee ${CURRENTDIR}/logs/console.log #group for tee
