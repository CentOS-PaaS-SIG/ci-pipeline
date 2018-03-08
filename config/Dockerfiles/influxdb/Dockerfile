FROM centos:7

ENV INFLUXDB_BINARY influxdb-1.5.0.x86_64.rpm

RUN curl https://dl.influxdata.com/influxdb/releases/${INFLUXDB_BINARY} > /${INFLUXDB_BINARY} && \
    yum -y localinstall /${INFLUXDB_BINARY} && \
    yum -y clean all && \
    rm -rf /var/cache/yum && \
    rm -f /${INFLUXDB_BINARY}

COPY influxdb.conf /etc/influxdb/influxdb.conf

EXPOSE 8086

VOLUME /var/lib/influxdb

COPY entrypoint.sh init-influxdb.sh /

ENTRYPOINT ["/entrypoint.sh"]

CMD ["influxd"]
