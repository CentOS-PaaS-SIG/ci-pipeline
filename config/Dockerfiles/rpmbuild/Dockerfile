FROM fedora:27
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to \
use fedpkg mock to create rpms.  It also rsyncs \
them to artifacts.ci.centos.org."
USER root

# Install all package requirements
RUN for i in {1..5} ; do dnf -y update && dnf clean all && break || sleep 10 ; done
RUN for i in {1..5} ; do dnf -y install ansible \
        @buildsys-build \
        createrepo \
        docker \
        fedora-packager \
        fedpkg \
        gcc \
        git \
        glib2 \
        go \
        hostname \
        libsolv \
        mock \
        ncurses-devel \
        perl \
        python-krbV \
        pyxdg \
        PyYAML \
        rpm-build \
        rpmlint \
        rsync \
        sed \
        sudo \
        virt-install \
        which \
        yum-utils \
        && dnf clean all \
        && break || sleep 10 ; done

# Change some mock settings
RUN echo "config_opts['package_manager'] = 'dnf'" >> /etc/mock/site-defaults.cfg
RUN echo "config_opts['plugin_conf']['lvm_root_opts']['size'] = '16G'" >> /etc/mock/site-defaults.cfg
RUN echo "config_opts['plugin_conf']['lvm_root_opts']['poolmetadatasize'] = '30G'" >> /etc/mock/site-defaults.cfg
RUN echo "config_opts['use_nspawn'] = False" >> /etc/mock/site-defaults.cfg

# Change the anongiturl for fedpkg
# See https://bugzilla.redhat.com/show_bug.cgi?id=1495378
# and https://pagure.io/fedpkg/issue/145
#
RUN sed -i 's@anongiturl.*$@anongiturl = https://src.fedoraproject.org/%(module)s@g' /etc/rpkg/fedpkg.conf

# Copy the build script to the container
COPY rpmbuild-test.sh rpmbuild-local.sh pull_old_task.sh repoquery.sh koji_build_pr.sh /tmp/

# Run the build script
ENTRYPOINT ["bash", "/tmp/rpmbuild-test.sh"]
#
# Run the container as follows
# docker run --privileged -v /log/parent/dir:/home -e fed_repo=${packagename} -e fed_branch=${fed_branch} -e fed_rev=${fed_rev} -e RSYNC_PASSWORD=${rsync_password} HTTP_BASE="${HTTP_BASE}" -e RSYNC_USER="${RSYNC_USER}" -e RSYNC_SERVER="${RSYNC_SERVER}" -e RSYNC_DIR="${RSYNC_DIR}" container_tag
