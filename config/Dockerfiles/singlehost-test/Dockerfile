FROM centos:7
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use dist-git tests to test packages, \
provided a package name and an image to test against. \
If there are no dist-git tests, it checks \
upstreamfirst.fedorainfracloud.org. It also can run \
integration tests from the projectatomic repo by calling \
the integration-test.sh script."

# Install epel
RUN yum -y install epel-release && yum clean all

# Copy restraint repo into container
RUN curl -o /etc/yum.repos.d/bpeck-restraint-el7.repo https://bpeck.fedorapeople.org/restraint/el7.repo

# Install all package requirements
RUN yum -y install ansible \
        beakerlib \
        curl \
        dnf-plugins-core \
        file \
        findutils \
        git \
        libselinux-python \
        qemu-kvm \
        restraint-rhts \
        rsync \
        standard-test-roles \
        sudo \
        wget \
        && yum clean all

#Run dnf -y install standard-test-roles \
#        --enablerepo=updates-testing \
#        && dnf clean all

# Copy the build scripts to the container
COPY package-test.sh integration-test.sh upstreamfirst-test.sh verify-rpm.sh rpm-verify.yml /tmp/

ENV ANSIBLE_INVENTORY=/usr/share/ansible/inventory/standard-inventory-qcow2

# Run the build script
ENTRYPOINT ["bash", "/tmp/package-test.sh"]

# Call the container as follows:
# docker run --privileged -t -v /artifacts/parent/dir:/container/artifacts/parent/dir -e package=sed -e fed_branch=f26 -e TEST_SUBJECTS=http://somewhere/image.qcow2 container_tag
# Note: Highly recommended to mount qcow2 image in container and use path to it as TEST_SUBJECTS instead to avoid time spent wget'ing the image
