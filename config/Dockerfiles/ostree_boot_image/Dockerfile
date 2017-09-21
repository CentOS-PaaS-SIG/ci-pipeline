FROM centos:7
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to boot a qcow2 image"

ENV HOME=/root

WORKDIR $HOME

COPY epel-release-7-2.noarch.rpm $HOME/
RUN yum -y install $HOME/epel-release-7-2.noarch.rpm

COPY atomic7-testing.repo /etc/yum.repos.d
COPY walters-buildtools.repo /etc/yum.repos.d

RUN yum -y install libguestfs libguestfs-tools-c \
                   git ostree rpm-ostree libvirt-client \
                   PyYAML python2-setuptools virt-install \
                   python-pip python-devel gcc net-tools \
                   openssh-clients sshpass && yum clean all

RUN pip install ara

#RUN git clone https://github.com/CentOS-PaaS-SIG/ci-pipeline

RUN echo 'uri_default = "qemu+tcp://libvirtd/system"' >> /etc/libvirt/libvirt.conf

COPY ostree-boot-image.sh $HOME/

VOLUME [ "/sys/fs/cgroup" ]

ENTRYPOINT ["bash", "/root/ostree-boot-image.sh"]
