FROM fedora:25
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use upstreamfirst tests to test packages, \
provided a package name and an image to test against."

# Install all package requirements
RUN for i in {1..5} ; do dnf -y install ansible \
        curl \
        findutils \
        git \
        sudo \
        wget \
        && dnf clean all \
        && break || sleep 10 ; done

# Copy the build script to the container
COPY image_package_test.sh /home/image_package_test.sh

# Run the build script
ENTRYPOINT ["bash", "/home/image_package_test.sh"]

# Call the container as follows:
# docker run --privileged -v /dir/on/localhost/artifacts:/tmp/artifacts -t -i -e package=sed -e image_location=http://somewhere/image.qcow2 container_tag
