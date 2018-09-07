FROM centos:7

ENV HOME /var/lib/influxdb

RUN curl https://dl.influxdata.com/influxdb/releases/${INFLUXDB_BINARY} > /${INFLUXDB_BINARY} && \
    yum -y localinstall /${INFLUXDB_BINARY} && \
    yum -y clean all && \
    rm -rf /var/cache/yum && \
    rm -f /${INFLUXDB_BINARY} && \
    chmod 664 /etc/passwd

COPY influxdb.conf /etc/influxdb/influxdb.conf

EXPOSE 8086

VOLUME /var/lib/influxdb

COPY entrypoint.sh init-influxdb.sh /

ENTRYPOINT ["/entrypoint.sh"]

CMD ["influxd"]
