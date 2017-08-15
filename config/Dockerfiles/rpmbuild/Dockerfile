FROM fedora:24
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use fedpkg mock to create rpms."

# Install all package requirements
RUN for i in {1..5} ; do dnf -y update && dnf clean all && break || sleep 10 ; done
RUN for i in {1..5} ; do dnf -y install ansible \
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
        rpmlint \
        rsync \
        sed \
        sudo \
        virt-install \
        which \
        && dnf clean all \
        && break || sleep 10 ; done

# Change some mock settings
RUN echo "config_opts['package_manager'] = 'dnf'" >> /etc/mock/site-defaults.cfg
RUN echo "config_opts['plugin_conf']['lvm_root_opts']['size'] = '16G'" >> /etc/mock/site-defaults.cfg
RUN echo "config_opts['plugin_conf']['lvm_root_opts']['poolmetadatasize'] = '30G'" >> /etc/mock/site-defaults.cfg
RUN echo "config_opts['basedir'] = '/home/rpmbuild/'" >> /etc/mock/site-defaults.cfg

# Copy the build script to the container
COPY rpmbuild-test.sh /home/rpmbuild-test.sh

# Run the build script
ENTRYPOINT ["bash", "/home/rpmbuild-test.sh"]
# test
# test2
# test3
# test4
# test5
# test6
# test7
# test8
# test9
# test10
