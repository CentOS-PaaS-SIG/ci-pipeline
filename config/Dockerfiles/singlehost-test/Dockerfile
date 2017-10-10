FROM fedora:26
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use dist-git tests to test packages, \
provided a package name and an image to test against. \
If there are no dist-git tests, it checks \
upstreamfirst.fedorainfracloud.org. It also can run \
integration tests from the projectatomic repo by calling \
the integration-test.sh script."

# Copy restraint repo into container
RUN curl -o /etc/yum.repos.d/bpeck-restraint-fedora-26.repo https://copr.fedorainfracloud.org/coprs/bpeck/restraint/repo/fedora-26/bpeck-restraint-fedora-26.repo

# Install all package requirements
RUN for i in {1..5} ; do dnf -y install ansible \
        beakerlib \
        curl \
        file \
        findutils \
        git \
        restraint-rhts \
        rsync \
        standard-test-roles \
        sudo \
        wget \
        && dnf clean all \
        && break || sleep 10 ; done

#Run dnf -y install standard-test-roles \
#        --enablerepo=updates-testing \
#        && dnf clean all

# Copy the build script to the container
COPY package-test.sh /tmp/package-test.sh
COPY integration-test.sh /tmp/integration-test.sh

COPY standard-inventory-qcow2 /usr/share/ansible/inventory/standard-inventory-qcow2

# Run the build script
ENTRYPOINT ["bash", "/tmp/package-test.sh"]

# Call the container as follows:
# docker run --privileged -t -v /artifacts/parent/dir:/container/artifacts/parent/dir -e package=sed -e fed_branch=f26 -e TEST_SUBJECTS=http://somewhere/image.qcow2 container_tag
# Note: Highly recommended to mount qcow2 image in container and use path to it as TEST_SUBJECTS instead to avoid time spent wget'ing the image
