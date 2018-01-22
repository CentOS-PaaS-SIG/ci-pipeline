FROM centos:7
MAINTAINER "Brent Baude" <bbaude@redhat.com>
ENV container docker
ENV HOME=/home
WORKDIR $HOME

COPY epel-release-7-2.noarch.rpm $HOME/
RUN yum -y install $HOME/epel-release-7-2.noarch.rpm

COPY atomic7-testing.repo /etc/yum.repos.d
COPY walters-buildtools.repo /etc/yum.repos.d
COPY paas7-openshift-origin36-testing.repo /etc/yum.repos.d

RUN yum -y install libguestfs libguestfs-tools-c \
                   git ostree rpm-ostree libvirt-client \
                   PyYAML python2-setuptools virt-install \
                   python-pip python-devel gcc net-tools \
                   openssh-clients sshpass && yum clean all

RUN yum -y install systemd

#START:  linchpin specific installations and workspace setups
RUN yum install -y libselinux-python \
                   python-devel \
                   libffi-devel \
                   redhat-rpm-config \
                   openssl-devel \
                   openssh-server \
                   libyaml-devel \
                   python-lxml \
                   libvirt \
                   libvirt-devel \
                   rpm-build \
                   bash-completion \
                   libvirt-python \
                   && yum groupinstall -y "Virtualization Tools"
RUN yum install -y python34 --nogpgcheck
RUN pip install pip --upgrade && pip install setuptools --upgrade
RUN ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
RUN printf "Host *\n    StrictHostKeyChecking no" > /root/.ssh/config
ADD linchpin_workspace15 /root/linchpin_workspace
WORKDIR "/root/linchpin_workspace/hooks/ansible/"
RUN git clone -b release-3.6 https://github.com/openshift/openshift-ansible
RUN git clone -b v1.1 https://github.com/samvarankashyap/paas-sig-ci
WORKDIR "/tmp/"
#RUN git clone -b file_module_patch https://github.com/samvarankashyap/linchpin
RUN git clone -b develop https://github.com/samvarankashyap/linchpin
WORKDIR "/tmp/linchpin"
RUN "$PWD/install.sh"
RUN cd /tmp/linchpin && python /tmp/linchpin/setup.py install
WORKDIR "/root/linchpin_workspace/"
#END: Linchpin specific workspace installations

#START: Install origin-tests rpms
# installs latest origin-tests rpm
RUN yum install -y origin-tests
#END: Linchpin specific workspace installations

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
COPY default.xml /etc/libvirt/qemu/networks/
RUN mkdir -p /var/lib/libvirt/images/
RUN mkdir -p /var/lib/libvirt/images/linchpin/

# Edit the service file which includes ExecStartPost to chmod /dev/kvm
RUN sed -i "/Service/a ExecStartPost=\/bin\/chmod 666 /dev/kvm" /usr/lib/systemd/system/libvirtd.service
VOLUME [ "/sys/fs/cgroup"]
CMD ["/usr/sbin/init"]
