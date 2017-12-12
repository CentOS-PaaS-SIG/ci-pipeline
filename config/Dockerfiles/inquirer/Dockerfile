FROM fedora:26
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This simple container is meant to poll remote_file, \
exiting when it exists. If the file does not exist after $timeout, \
the container exits 1.  It also has a script to use repoquery to get \
the NVR of a package from a remote repo."

RUN yum -y install coreutils \
        curl \
        yum-utils \
        && yum clean all

COPY poller.sh /tmp/poller.sh
COPY find_nvr.sh /tmp/find_nvr.sh

ENTRYPOINT ["bash", "/tmp/poller.sh"]
