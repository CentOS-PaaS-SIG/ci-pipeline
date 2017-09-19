FROM centos:7
LABEL maintainer "https://github.com/CentOS-PaaS-SIG/ci-pipeline"
LABEL description="This container is meant to rsync content to/from"

ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV HOME=/root

WORKDIR $HOME

RUN yum clean expire-cache
RUN yum -y install rsync 

# Copy the build script to the container
COPY rsync.sh /tmp/rsync.sh

# Run the build script
ENTRYPOINT ["bash", "/tmp/rsync.sh"]
