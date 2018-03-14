FROM centos:7

ENV TELEGRAF_INSTALL telegraf-1.5.2-1.x86_64.rpm

RUN curl https://dl.influxdata.com/telegraf/releases/${TELEGRAF_INSTALL} > /${TELEGRAF_INSTALL} && \
    yum -y localinstall /${TELEGRAF_INSTALL} && \
    yum -y clean all && \
    rm -rf /var/cache/yum && \
    rm -f /${TELEGRAF_INSTALL}

EXPOSE 8125/udp 8092/udp 8094

COPY entrypoint.sh /entrypoint.sh

COPY telegraf.conf /etc/telegraf/telegraf.conf

ENTRYPOINT ["/entrypoint.sh"]

CMD ["telegraf"]
