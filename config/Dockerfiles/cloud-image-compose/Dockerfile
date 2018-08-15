FROM centos:7
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to generate a fedora image \
with a custom rpm, specified with $package, located at $rpm_repo."

RUN yum -y install epel-release

COPY atomic7-testing.repo /etc/yum.repos.d
COPY walters-buildtools.repo /etc/yum.repos.d

RUN yum -y install curl \
        dnsmasq \
        git \
        imagefactory \
        imagefactory-plugins \
        imagefactory-plugins-TinMan \
        libguestfs \
        libguestfs-tools-c \
        libvirt-client \
        libvirt-daemon \
        libvirt-daemon-driver-* \
        libvirt-daemon-kvm \
        libvirt-daemon-qemu \
        pykickstart \
        PyYAML \
        qemu-kvm \
        yum-utils \
        wget \
        && yum clean all

COPY default.xml /etc/libvirt/qemu/networks/

COPY cloud-image-compose.sh virt-customize.sh /tmp/

VOLUME [ "/sys/fs/cgroup" ]

ENTRYPOINT ["bash", "/tmp/cloud-image-compose.sh"]
