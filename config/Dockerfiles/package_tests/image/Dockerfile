FROM fedora:25
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use upstreamfirst tests to test packages, \
provided a package name and an image to test against."

# Copy restraint repo into container
RUN curl -o /etc/yum.repos.d/bpeck-restraint-fedora-25.repo https://copr.fedorainfracloud.org/coprs/bpeck/restraint/repo/fedora-25/bpeck-restraint-fedora-25.repo

# Install all package requirements
RUN for i in {1..5} ; do dnf -y install ansible \
        beakerlib \
        curl \
        file \
        findutils \
        genisoimage \
        git \
        qemu-system-x86 \
        restraint-rhts \
        sudo \
        wget \
        && dnf clean all \
        && break || sleep 10 ; done

Run dnf -y install standard-test-roles \
        --enablerepo=updates-testing \
        && dnf clean all

# Copy the build script to the container
COPY image_package_test.sh /home/image_package_test.sh
ENV ANSIBLE_INVENTORY=/usr/share/ansible/inventory
# TEST_ARTIFACTS must be a mounted volume if you want your output
ENV TEST_ARTIFACTS=/tmp/test_output

# Run the build script
ENTRYPOINT ["bash", "/home/image_package_test.sh"]

# Call the container as follows:
# docker run --privileged -t -v /dir/on/localhost/artifacts:/tmp/test_output -e package=sed -e TEST_SUBJECTS=http://somewhere/image.qcow2 container_tag
# Note: Highly recommended to mount qcow2 image in container and use path to it as TEST_SUBJECTS instead to avoid time spent wget'ing the image
