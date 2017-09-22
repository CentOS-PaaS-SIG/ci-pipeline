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

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]
