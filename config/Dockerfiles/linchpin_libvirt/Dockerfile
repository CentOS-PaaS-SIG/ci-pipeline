FROM centos:7
MAINTAINER "Brent Baude" <bbaude@redhat.com>
ENV container docker
ARG OSTREE_REPO_SERVER
RUN yum -y update && yum clean all
RUN yum -y install systemd 
#RUN yum -y install libvirt-daemon-driver-{network,interface,storage,qemu} qemu systemd libvirt-daemon && yum clean all; \
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

EXPOSE 16509 2222 8080

RUN echo "listen_tls = 0" >> /etc/libvirt/libvirtd.conf; \
echo 'listen_tcp = 1' >> /etc/libvirt/libvirtd.conf; \
echo 'tls_port = "16514"' >> /etc/libvirt/libvirtd.conf; \ 
echo 'tcp_port = "16509"' >> /etc/libvirt/libvirtd.conf; \
echo 'auth_tcp = "none"' >> /etc/libvirt/libvirtd.conf

RUN echo 'LIBVIRTD_ARGS="--listen"' >> /etc/sysconfig/libvirtd
RUN mkdir -p /var/lib/libvirt/images/

# Edit the service file which includes ExecStartPost to chmod /dev/kvm
RUN sed -i "/Service/a ExecStartPost=\/bin\/chmod 666 /dev/kvm" /usr/lib/systemd/system/libvirtd.service
RUN sed -i "/Unit/a Requires=socat-ssh-guest" /usr/lib/systemd/system/libvirtd.service

COPY socat-ssh-guest.service /etc/systemd/system/
RUN systemctl enable socat-ssh-guest

COPY socat-http-proxy.service /etc/systemd/system/
RUN systemctl enable socat-http-proxy
RUN echo "OSTREE_REPO_SERVER=$OSTREE_REPO_SERVER" > /etc/sysconfig/socat-http-proxy

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
ADD linchpin_workspace linchpin_workspace
WORKDIR "/linchpin_workspace/hooks/ansible/"
RUN git clone -b release-3.6 https://github.com/openshift/openshift-ansible 
RUN git clone https://github.com/samvarankashyap/paas-sig-ci
WORKDIR "/tmp/"
RUN git clone -b libvirt_cloudconfig2 https://github.com/samvarankashyap/linchpin
WORKDIR "/tmp/linchpin"
RUN "$PWD/install.sh"
RUN cd /tmp/linchpin && python /tmp/linchpin/setup.py install
WORKDIR "/linchpin_workspace/"
VOLUME [ "/sys/fs/cgroup", "/var/run/libvirt"]
CMD ["/usr/sbin/init"]
