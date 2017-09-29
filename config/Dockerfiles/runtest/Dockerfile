FROM fedora:25
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
run both package level tests on a specified package \
or run general atomic host level integration tests. \
This is a tmp version that includes provisioning the host."

# Get repo for restraint-rhts
ADD https://copr.fedorainfracloud.org/coprs/bpeck/restraint/repo/fedora-25/bpeck-restraint-fedora-25.repo /etc/yum.repos.d/

# Install all package requirements
RUN for i in {1..5} ; do dnf -y update && dnf clean all && break || sleep 10 ; done
RUN for i in {1..5} ; do dnf -y install ansible \
        beakerlib \
        curl \
        findutils \
        git \
        libguestfs \
        libguestfs-tools-c \
        libvirt-client \
        openssh-clients \
        net-tools \
        python-devel \
        python-pip \
        python2-setuptools \
        restraint-rhts \
        sed \
        sshpass \
        sudo \
        virt-install \
        which \
        && dnf clean all \
        && break || sleep 10 ; done
#RUN dnf -y install standard-test-roles \
#        --enablerepo=updates-testing \
#        && dnf clean all
RUN pip install ara==0.13.0

# Clone the general atomic host tests repo
RUN git clone https://github.com/projectatomic/atomic-host-tests /atomic-host-tests

# Set up build env
ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV MNT_DIR=/root

# Libvirt setup
RUN echo 'uri_default = "qemu+tcp://libvirtd/system"' >> /etc/libvirt/libvirt.conf
VOLUME [ "/sys/fs/cgroup" ]

# Copy the test scripts to the container
COPY tmp-atomic-host-tests.sh /tmp/tmp-atomic-host-tests.sh
#COPY tmp-package-tests.sh /tmp/tmp-package-tests.sh
COPY selector.sh /tmp/selector.sh

# Run the build script
ENTRYPOINT ["bash", "/tmp/selector.sh"]
# docker run --privileged -ti --link libvirtd:libvirtd -v /dir/for/artifacts:${MNT_DIR} -e state=present -e image2boot=${image2boot} -e suite=package -e package=sed container_tag
