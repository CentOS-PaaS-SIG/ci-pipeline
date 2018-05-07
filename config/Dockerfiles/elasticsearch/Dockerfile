FROM centos:7

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.10
ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/jre-1.8.0-openjdk
ENV ELASTICSEARCH_VERSION 6.2.4

RUN set -ex; \
	yum -y install nc epel-release wget java-1.8.0-openjdk-headless unzip which; \
    yum clean all;

RUN groupadd -g 1000 elasticsearch && \
    adduser -u 1000 -g 1000 -d /usr/share/elasticsearch elasticsearch

WORKDIR /usr/share/elasticsearch

USER 1000

# Download and extract defined ES version.
RUN curl -fsSL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.2.4.tar.gz | \ 
    tar zx --strip-components=1

RUN set -ex && for esdirs in config data logs; do \
        mkdir -p "$esdirs"; \
    done

# Install the ingest-{agent,geoip} modules required for Filebeat
RUN for PLUGIN in ingest-user-agent ingest-geoip; do \
      elasticsearch-plugin install --batch "$PLUGIN"; done

COPY elasticsearch.yml log4j2.properties config/

COPY bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

USER 0

RUN chown -R elasticsearch:0 . && \
    chown -R elasticsearch:0 /usr/local/bin/docker-entrypoint.sh && \
    chmod -R g=u /usr/share/elasticsearch

RUN chmod 0775 /usr/share/elasticsearch && \
    chgrp 0 /usr/share/elasticsearch

# Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
# Allow ENTRYPOINT (and ES) to run even with a different user
RUN chmod g=u /etc/passwd && \
    chmod 0775 /usr/local/bin/docker-entrypoint.sh

EXPOSE 9200 9300

VOLUME /usr/share/elasticsearch/data

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Dummy overridable parameter parsed by entrypoint
CMD ["eswrapper"]
