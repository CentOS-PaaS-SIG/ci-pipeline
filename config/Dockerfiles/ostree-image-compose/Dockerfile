FROM centos:7
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to generate an image from an ostree compose"

ENV HOME=/root

WORKDIR $HOME

COPY epel-release-7-2.noarch.rpm $HOME/
RUN yum -y install $HOME/epel-release-7-2.noarch.rpm

COPY atomic7-testing.repo /etc/yum.repos.d
COPY walters-buildtools.repo /etc/yum.repos.d

RUN yum -y install dnsmasq libvirt-daemon-driver-* libvirt-daemon \
                   libvirt-daemon-kvm qemu-kvm libguestfs libguestfs-tools-c \
                   libvirt-daemon-qemu git ostree rpm-ostree libvirt-cliet \
                   imagefactory imagefactory-plugins imagefactory-plugins-TinMan \
                   libvirt-daemon-config-network PyYAML wget && yum clean all

RUN git clone https://github.com/CentOS-PaaS-SIG/ci-pipeline

COPY ostree-image-compose.sh /tmp/ostree-image-compose.sh

VOLUME [ "/sys/fs/cgroup" ]

ENTRYPOINT ["bash", "/tmp/ostree-image-compose.sh"]
