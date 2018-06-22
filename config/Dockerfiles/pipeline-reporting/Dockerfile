FROM fedora:27

LABEL io.openshift.s2i.scripts-url=image:///usr/libexec/s2i

RUN dnf -y install cronie-anacron git python3

RUN pip-3 install influxdb

RUN mkdir /opt/openshift \
    && chown -R 1001:0 /opt/openshift \
    && chmod 664 /etc/passwd

ADD ./s2i /usr/libexec/s2i

USER 1001

WORKDIR /opt/openshift

RUN git clone https://github.com/joejstuart/pipeline-reporting.git
