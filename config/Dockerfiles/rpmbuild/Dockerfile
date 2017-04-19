FROM fedora:25
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/aos-ci"
LABEL description="This container is meant to \
use fedpkg mock to create rpms."

# Install all package requirements
RUN dnf -y update && dnf clean all
RUN dnf -y install ansible \
        @buildsys-build \
        createrepo \
        docker \
        fedpkg \
        gcc \
        git \
        glib2 \
        go \
        libsolv \
        mock \
        pyxdg \
        PyYAML \
        rpm-build \
        rsync \
        sed \
        sudo \
        virt-install \
        which \
        && dnf clean all

# Change some mock settings
RUN echo "config_opts['package_manager'] = 'dnf'" >> /etc/mock/site-defaults.cfg
RUN echo "config_opts['plugin_conf']['lvm_root_opts']['size'] = '16G'" >> /etc/mock/site-defaults.cfg

# Copy the build script to the container
COPY rpmbuild-test.sh /home/rpmbuild-test.sh

# Run the build script
ENTRYPOINT ["bash", "/home/rpmbuild-test.sh"]
