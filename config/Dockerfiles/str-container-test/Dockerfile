FROM fedora:28
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
run standard-test-roles defined tests targeting \
the container namespace instead of the rpms namespace."

# Copy restraint repo into container
RUN curl -o /etc/yum.repos.d/bpeck-restraint-fedora.repo https://bpeck.fedorapeople.org/restraint/fedora.repo

# Install all package requirements
RUN dnf -y install ansible \
        beakerlib \
        curl \
        dnf-plugins-core \
        docker \
        file \
        findutils \
        git \
        libselinux-python \
        python-dnf \
        python-pip \
        qemu-kvm \
        restraint-rhts \
        rsync \
        standard-test-roles \
        sudo \
        wget \
        && dnf clean all

# WORKAROUND: use str from pip
# Official STR does is not ansible 2.4 compatible, ansible 2.5 has no repo
RUN pip install ansible==2.5.8

# Systemd hacking
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*; \
systemctl enable docker

# Set default ansible inventory for STR
ENV ANSIBLE_INVENTORY=/usr/share/ansible/inventory

# Copy the build scripts to the container
COPY container-test.sh /home/

CMD ["/usr/sbin/init"]
