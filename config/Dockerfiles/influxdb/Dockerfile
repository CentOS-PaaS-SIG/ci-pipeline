FROM centos:7

ENV HOME=/var/lib/influxdb
ENV INFLUX_BINARY=${INFLUXDB_BINARY:-influxdb-1.6.2.x86_64.rpm}

RUN curl https://dl.influxdata.com/influxdb/releases/${INFLUX_BINARY} > /${INFLUX_BINARY} && \
    yum -y localinstall /${INFLUX_BINARY} && \
    yum -y clean all && \
    rm -rf /var/cache/yum && \
    rm -f /${INFLUX_BINARY} && \
    chmod 664 /etc/passwd

COPY influxdb.conf /etc/influxdb/influxdb.conf

EXPOSE 8086

VOLUME /var/lib/influxdb

COPY entrypoint.sh init-influxdb.sh /

ENTRYPOINT ["/entrypoint.sh"]

CMD ["influxd"]
