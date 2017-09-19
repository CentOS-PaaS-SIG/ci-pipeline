FROM centos:7
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to generate an ostree compose"

ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV GIT_SSL_NO_VERIFY=true
ENV HOME=/root

WORKDIR $HOME

COPY epel-release-7-2.noarch.rpm $HOME/
RUN yum -y install $HOME/epel-release-7-2.noarch.rpm
COPY atomic7-testing.repo /etc/yum.repos.d
COPY walters-buildtools.repo /etc/yum.repos.d

RUN yum clean expire-cache
RUN yum -y localinstall https://kojipkgs.fedoraproject.org//packages/python-distro/1.0.1/2.el7/noarch/python2-distro-1.0.1-2.el7.noarch.rpm
RUN yum -y localinstall https://kojipkgs.fedoraproject.org/packages/bodhi/2.10.1/2.el7/noarch/bodhi-client-2.10.1-2.el7.noarch.rpm https://kojipkgs.fedoraproject.org/packages/bodhi/2.10.1/2.el7/noarch/python2-bodhi-2.10.1-2.el7.noarch.rpm
RUN yum -y install --disablerepo=epel-testing rsync mock libsolv glib2 ostree rpm-ostree rpm-ostree-toolbox fedpkg PyYAML rpmdistro-gitoverlay libgsystem genisoimage ansible

RUN git clone https://github.com/CentOS-PaaS-SIG/ci-pipeline

# Copy the build script to the container
COPY ostree-compose.sh $HOME/ci-pipeline/

# Run the build script
ENTRYPOINT ["bash", "/root/ci-pipeline/ostree-compose.sh"]
