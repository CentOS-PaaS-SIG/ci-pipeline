FROM fedora:latest
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
run standard-test-roles defined tests targeting \
the container namespace instead of the rpms namespace."

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
        rsync \
        standard-test-roles \
        standard-test-roles-inventory-docker \
        sudo \
        systemd \
        wget \
        && dnf clean all

# WORKAROUND: use str from pip
# Official STR does is not ansible 2.4 compatible, ansible 2.5 has no repo
RUN pip install ansible==2.5.8

# Set default ansible inventory for STR
ENV ANSIBLE_INVENTORY=/usr/share/ansible/inventory

# Copy the build scripts to the container
COPY container-test.sh /home/

CMD ["/usr/sbin/init"]
