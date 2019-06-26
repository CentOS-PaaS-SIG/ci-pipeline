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

namespace=${namespace:-"rpms"}

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

# Check if the downloaded qcow2 image is valid
qemu-img check ${DOWNLOADED_IMAGE_LOCATION}

# Make dir for just rpm content
mkdir -p ${CURRENTDIR}/testrepo/${package}
# Do there is no packages to copy when running for tests namespace
if [ "${namespace}" != "tests" ]; then
    cp -rp ${rpm_repo}/*.rpm ${rpm_repo}/repodata ${CURRENTDIR}/testrepo/${package}
fi

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

gpgcheck=1
if [ "${branch}" != "rawhide" ]; then
    if ! virt-customize --selinux-relabel --memsize 4096 -a ${DOWNLOADED_IMAGE_LOCATION} --run-command "dnf config-manager --set-enable updates-testing updates-testing-debuginfo" ; then
        echo "failure enabling updates-testing repo"
        exit 1
    fi
else
    # Don't check GPG key when testing on Rawhide
    virt-customize -a ${DOWNLOADED_IMAGE_LOCATION} --run-command "sed -i s/gpgcheck=.*/gpgcheck=0/ /etc/yum.repos.d/*.repo"
    gpgcheck=0
fi

koji_repo=$(echo ${DIST_BRANCH}-build | sed -e s'/fc/f/')
# Add repo from latest packages built in koji
cat <<EOF > ${CURRENTDIR}/koji-latest.repo
[koji-${koji_repo}]
name=koji-${koji_repo}
baseurl=https://kojipkgs.fedoraproject.org/repos/${koji_repo}/latest/x86_64/
enabled=1
gpgcheck=0
EOF

virt_copy_files="${CURRENTDIR}/testrepo/${package} ${CURRENTDIR}/test-${package}.repo ${CURRENTDIR}/koji-latest.repo /etc/yum.repos.d/"
# If virt-customize.sh is running as part of PR on tests namespace there is no package built, therefore /testrepo/${package} does not exist
if [ "${namespace}" == "tests" ]; then
    virt_copy_files="${CURRENTDIR}/koji-latest.repo /etc/yum.repos.d/"
fi

virt-copy-in -a ${DOWNLOADED_IMAGE_LOCATION} ${virt_copy_files} /etc/yum.repos.d/

# Do install any package if it is tests namespace
if [ "${namespace}" != "tests" ]; then
    for pkg in $(repoquery -q --disablerepo=\* --enablerepo=${package} --repofrompath=${package},${rpm_repo} --all --qf="%{ARCH}:%{NAME}" | sed -e "/^src:/d;/-debug\(info\|source\)\$/d;s/.\+://" | sort -u) ; do
        # check if this package conflicts with any other package from RPM_LIST
        conflict_capability=$(repoquery -q --disablerepo=\* --enablerepo=${package} --repofrompath=${package},${rpm_repo} --conflict $pkg)
        conflict=''
        if [ ! -z "${conflict_capability}" ] ; then
            conflict=$(repoquery -q --qf "%{NAME}" --disablerepo=\* --enablerepo=${package} --repofrompath=${package},${rpm_repo} --whatprovides "$conflict_capability")
        fi
        found_conflict=0
        if [ ! -z "${conflict}" ] && [ ! -z "${RPM_LIST}" ]; then
            for rpm_pkg in ${RPM_LIST} ; do
                if [ "${conflict}" == "$rpm_pkg" ]; then
                    # this pkg conflicts with a package already in RPM_LIST
                    found_conflict=1
                    continue
                fi
            done
            if [ ${found_conflict} ]; then
                echo "INFO: will not install $pkg as it conflicts with $conflict."
                continue
            fi
        fi
        RPM_LIST="${RPM_LIST} ${pkg}"
    done
    if ! virt-customize -v --selinux-relabel --memsize 4096 -a ${DOWNLOADED_IMAGE_LOCATION} --run-command "dnf install -y --best --allowerasing --nogpgcheck ${RPM_LIST} && dnf clean all" ; then
        echo "failure installing rpms"
        exit 1
    fi
fi

} 2>&1 | tee ${CURRENTDIR}/logs/console.log #group for tee
