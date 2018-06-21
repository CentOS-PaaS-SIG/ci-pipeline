FROM fedora:27

RUN dnf -y install cronie-anacron git

#RUN mkdir /opt/openshift \
#    && chown -R 1001:0 /opt/openshift \
#    && chown 664 /etc/passwd

#ADD ./s2i /usr/libexec/s2i

#USER 1001

#WORKDIR /opt/openshift

#RUN git clone https://github.com/joejstuart/pipeline-reporting.git

CMD ["ps"]
#ENTRYPOINT ["/usr/bin/dumb-init", "--"]
#CMD ["/usr/libexec/s2i/run", "ps"]
