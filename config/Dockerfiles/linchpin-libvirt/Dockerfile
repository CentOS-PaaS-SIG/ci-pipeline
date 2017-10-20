FROM centos:7
MAINTAINER "Brent Baude" <bbaude@redhat.com>
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

RUN yum -y install libvirt-daemon-driver-* libvirt-daemon libvirt-daemon-kvm qemu-kvm socat && yum clean all; \
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

COPY default.xml /usr/share/libvirt/networks/

EXPOSE 16509

RUN echo "listen_tls = 0" >> /etc/libvirt/libvirtd.conf; \
echo 'listen_tcp = 1' >> /etc/libvirt/libvirtd.conf; \
echo 'tls_port = "16514"' >> /etc/libvirt/libvirtd.conf; \
echo 'tcp_port = "16509"' >> /etc/libvirt/libvirtd.conf; \
echo 'auth_tcp = "none"' >> /etc/libvirt/libvirtd.conf
RUN echo 'LIBVIRTD_ARGS="--listen"' >> /etc/sysconfig/libvirtd
RUN mkdir -p /var/lib/libvirt/images/
RUN mkdir -p /var/lib/libvirt/images/linchpin/


# Edit the service file which includes ExecStartPost to chmod /dev/kvm
RUN sed -i "/Service/a ExecStartPost=\/bin\/chmod 666 /dev/kvm" /usr/lib/systemd/system/libvirtd.service

RUN yum install -y git net-tools epel-release python-pip \
                       libselinux-python \
                       python-devel \
                       libffi-devel \
                       redhat-rpm-config \
                       openssl-devel \
                       openssh-server \
                       openssh-clients \
                       libyaml-devel \
                       python-lxml \
                       libvirt \
                       libvirt-devel \
                       gcc \
                       rpm-build \
                       bash-completion \
                       libvirt-python \
                       libvirt-client \
                       virt-install \
                       && yum groupinstall -y "Virtualization Tools"
RUN yum install -y python-pip --nogpgcheck
RUN yum install -y python34 --nogpgcheck
RUN pip install pip --upgrade && pip install setuptools --upgrade
RUN ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
RUN printf "Host *\n    StrictHostKeyChecking no" > /root/.ssh/config
#ADD linchpin_workspace linchpin_workspace
ADD linchpin_workspace /root/linchpin_workspace
WORKDIR "/root/linchpin_workspace/hooks/ansible/"
RUN git clone -b release-3.6 https://github.com/openshift/openshift-ansible 
RUN git clone https://github.com/samvarankashyap/paas-sig-ci
WORKDIR "/tmp/"
RUN git clone -b libvirt_cloudconfig5 https://github.com/samvarankashyap/linchpin
WORKDIR "/tmp/linchpin"
RUN "$PWD/install.sh"
RUN cd /tmp/linchpin && python /tmp/linchpin/setup.py install
WORKDIR "/root/linchpin_workspace/"
VOLUME [ "/sys/fs/cgroup"]
CMD ["/usr/sbin/init"]
