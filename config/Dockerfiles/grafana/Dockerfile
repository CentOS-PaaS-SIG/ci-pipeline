FROM centos:7

ENV USERNAME=grafana
ENV GRAFANA_RPM=${GRAFANA_INSTALL:-influxdb-1.6.2.x86_64.rpm}

RUN yum -y install git unzip nss_wrapper && \
    curl -L -o /tmp/grafana.rpm https://s3-us-west-2.amazonaws.com/grafana-releases/release/${GRAFANA_RPM} && \
    yum -y localinstall /tmp/grafana.rpm && \
    yum -y clean all && \
    rm -rf /var/cache/yum && \
    rm /tmp/grafana.rpm

COPY ./usr/bin/ /usr/bin/
RUN /usr/bin/fix-permissions /var/log/grafana && \
    /usr/bin/fix-permissions /etc/grafana && \
    /usr/bin/fix-permissions /usr/share/grafana && \
    /usr/bin/fix-permissions /usr/sbin/grafana-server

VOLUME ["/var/lib/grafana", "/var/log/grafana", "/etc/grafana"]

EXPOSE 3000

ENTRYPOINT ["/usr/bin/rungrafana"]
