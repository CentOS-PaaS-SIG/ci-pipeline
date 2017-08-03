FROM fedora:25
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use upstreamfirst tests to test packages, \
provided a package name and an ansible inventory."

# Get repo for restraint-rhts
ADD https://copr.fedorainfracloud.org/coprs/bpeck/restraint/repo/fedora-25/bpeck-restraint-fedora-25.repo /etc/yum.repos.d/

# Install all package requirements
RUN for i in {1..5} ; do dnf -y install ansible \
        beakerlib \
        curl \
        findutils \
        git \
        restraint-rhts \
        sed \
        sudo \
        && dnf clean all \
        && break || sleep 10 ; done

Run dnf -y install standard-test-roles \
        --enablerepo=updates-testing \
        && dnf clean all

# Copy the build script to the container
COPY ansible_package_test.sh /home/ansible_package_test.sh

# Set up build env
ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV TEST_ARTIFACTS=/tmp/artifacts
ENV ANSIBLE_INVENTORY=/usr/share/ansible/inventory

# Run the build script
ENTRYPOINT ["bash", "/home/ansible_package_test.sh"]

# Call the container as follows:
# Note: foo below is some dir on localhost that contains both
# your ansible inventory file AND the ansible ssh private key.
# This is also the dir where the artifacts will be rsynced to
# docker run --privileged -v /foo:/tmp -t -e package=sed container_tag
