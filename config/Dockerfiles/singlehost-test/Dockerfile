FROM fedora:latest
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use dist-git tests to test packages, \
provided a package name and an image to test against. \
If there are no dist-git tests, it checks \
upstreamfirst.fedorainfracloud.org. It also can run \
integration tests from the projectatomic repo by calling \
the integration-test.sh script."

RUN dnf -y module enable standard-test-roles

# Install all package requirements
# rpm-build is required by standard-test-source role
# python3-devel (pathfix.py) is required by some tests that use standard-test-source role
RUN dnf -y install ansible \
        beakerlib \
        curl \
        dnf-plugins-core \
        file \
        findutils \
        git \
        libguestfs-tools-c \
        libselinux-python \
        python-dnf \
        python-pip \
        python3-devel \
        qemu-img \
        qemu-kvm \
        rpm-build \
        rsync \
        standard-test-roles \
        standard-test-roles-inventory-qemu \
        sudo \
        wget \
        && dnf clean all

# WORKAROUND: use str from updatest-testing repo in case you cannot wait for a stable build
# RUN dnf -y update standard-test-roles --enablerepo=updates-testing && \
#     dnf clean all

# Use Ansible version we know it works
RUN pip install ansible==2.7.7

# Copy the build scripts to the container
COPY package-test.sh integration-test.sh upstreamfirst-test.sh verify-rpm.sh rpm-verify.yml resize-qcow2.sh /tmp/

ENV ANSIBLE_INVENTORY=/usr/share/ansible/inventory/standard-inventory-qcow2

# Run the build script
ENTRYPOINT ["bash", "/tmp/package-test.sh"]

# Call the container as follows:
# docker run --privileged -t -v /artifacts/parent/dir:/container/artifacts/parent/dir -e package=sed -e fed_branch=f26 -e TEST_SUBJECTS=http://somewhere/image.qcow2 container_tag
# Note: Highly recommended to mount qcow2 image in container and use path to it as TEST_SUBJECTS instead to avoid time spent wget'ing the image
