from fedora:25

RUN yum install -y procps net-tools iproute fedmsg-relay && yum clean all -y

EXPOSE 4001
EXPOSE 2003

RUN useradd fedmsg2 -d /home/fedmsg2 && \
    mkdir -p /home/fedmsg2/ && \
    echo "fedmsg2:fedmsg2" | chpasswd
RUN chmod -R 777 /home/fedmsg2

COPY relay.py /etc/fedmsg.d/relay.py
COPY ssl.py /etc/fedmsg.d/ssl.py
COPY endpoints.py /etc/fedmsg.d/endpoints.py

RUN chmod -R 777 /etc/fedmsg.d

COPY entrypoint.sh /usr/bin/entrypoint.sh

ENTRYPOINT ["/bin/sh", "/usr/bin/entrypoint.sh"]

USER fedmsg2
