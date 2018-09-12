#!/usr/bin/sh

set -xeuo pipefail

# A shell script that pulls the latest Fedora cloud build
# and uses virt-customize to inject rpms into it. It
# outputs a new qcow2 image for you to use.

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

if [ $branch != "rawhide" ]; then
    branch=${branch:1}
fi

if [ "${branch}" == "rawhide" ]; then
    curl --connect-timeout 5 --retry 5 --retry-delay 0 --retry-max-time 60 \
         -L -k -O "https://jenkins-continuous-infra.apps.ci.centos.org/job/fedora-rawhide-image-test/lastSuccessfulBuild/artifact/Fedora-Rawhide.qcow2"
    DOWNLOADED_IMAGE_LOCATION="$(pwd)/Fedora-Rawhide.qcow2"
elif [ "${branch}" -ge 28 ]; then
    curl --connect-timeout 5 --retry 5 --retry-delay 0 --retry-max-time 60 \
         -L -k -O "https://jenkins-continuous-infra.apps.ci.centos.org/job/fedora-f${branch}-image-test/lastSuccessfulBuild/artifact/Fedora-${branch}.qcow2"
    DOWNLOADED_IMAGE_LOCATION="$(pwd)/Fedora-${branch}.qcow2"
else
    INSTALL_URL="https://dl.fedoraproject.org/pub/fedora/linux/releases/${branch}/CloudImages/x86_64/images/"
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 --tries 5 --quiet -r --no-parent -A 'Fedora-Cloud-Base*.qcow2' ${INSTALL_URL}
    DOWNLOADED_IMAGE_LOCATION=$(pwd)/$(find dl.fedoraproject.org -name "*.qcow2" | head -1)
fi

function clean_up {
  set +e
  pushd ${CURRENTDIR}/images
  cp ${DOWNLOADED_IMAGE_LOCATION} .
  ln -sf $(find . -name "*.qcow2" | head -1) test_subject.qcow2
  popd
  kill $(jobs -p)
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

{ #group for tee

mkdir -p ${CURRENTDIR}/images

# Make dir for just rpm content
mkdir -p ${CURRENTDIR}/testrepo/${package}
cp -rp ${rpm_repo}/*.rpm ${rpm_repo}/repodata ${CURRENTDIR}/testrepo/${package}

RPM_LIST=""
# Add custom rpms to image
cat <<EOF > ${CURRENTDIR}/test-${package}.repo
[test-${package}]
name=test-${package}
baseurl=file:///etc/yum.repos.d/${package}
priority=0
enabled=1
gpgcheck=0
EOF

koji_repo=${branch}
if [ "${branch}" != "rawhide" ]; then
    koji_repo="f${branch}-build"
    dnf config-manager --set-enable updates-testing updates-testing-debuginfo
fi
# Add repo from latest packages built in koji
cat <<EOF > ${CURRENTDIR}/koji-latest.repo
[koji-${branch}]
name=koji-${branch}
baseurl=https://kojipkgs.fedoraproject.org/repos/${koji_repo}/latest/x86_64/
priority=999
enabled=1
gpgcheck=1
EOF

virt-copy-in -a ${DOWNLOADED_IMAGE_LOCATION} ${CURRENTDIR}/testrepo/${package} ${CURRENTDIR}/test-${package}.repo ${CURRENTDIR}/koji-latest.repo /etc/yum.repos.d/

for pkg in $(repoquery -q --disablerepo=\* --enablerepo=${package} --repofrompath=${package},${rpm_repo} --all --qf="%{ARCH}:%{NAME}" | sed -e "/^src:/d;/-debug\(info\|source\)\$/d;s/.\+://" | sort -u) ; do
    RPM_LIST="${RPM_LIST} ${pkg}"
done
if ! virt-customize -v --selinux-relabel --memsize 4096 -a ${DOWNLOADED_IMAGE_LOCATION} --run-command "yum install -y --best --allowerasing --nogpgcheck ${RPM_LIST} && yum clean all" ; then
    echo "failure installing rpms"
    exit 1
fi

} 2>&1 | tee ${CURRENTDIR}/logs/console.log #group for tee
