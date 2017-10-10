FROM centos:7
MAINTAINER "Brent Baude" <bbaude@redhat.com>
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to boot a qcow2 image"

ENV container docker
ENV HOME=/home

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

RUN yum -y update && yum clean all
RUN yum -y install systemd 
RUN yum -y install libvirt-daemon-driver-* libvirt-daemon libvirt-daemon-config-network libvirt-daemon-kvm qemu-kvm socat && yum clean all; \
(cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*; \
systemctl enable libvirtd; \
systemctl enable virtlockd 

RUN pip install ara

COPY ostree-boot-image.sh $HOME/

EXPOSE 16509

RUN echo "listen_tls = 0" >> /etc/libvirt/libvirtd.conf; \
echo 'listen_tcp = 1' >> /etc/libvirt/libvirtd.conf; \
echo 'tls_port = "16514"' >> /etc/libvirt/libvirtd.conf; \ 
echo 'tcp_port = "16509"' >> /etc/libvirt/libvirtd.conf; \
echo 'auth_tcp = "none"' >> /etc/libvirt/libvirtd.conf

RUN echo 'LIBVIRTD_ARGS="--listen"' >> /etc/sysconfig/libvirtd
RUN mkdir -p /var/lib/libvirt/images/

# Edit the service file which includes ExecStartPost to chmod /dev/kvm
RUN sed -i "/Service/a ExecStartPost=\/bin\/chmod 666 /dev/kvm" /usr/lib/systemd/system/libvirtd.service

VOLUME [ "/sys/fs/cgroup", "/var/run/libvirt"]
CMD ["/usr/sbin/init"]
