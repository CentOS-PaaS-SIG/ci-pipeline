FROM centos:7

# grab gosu for easy step-down from root
ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/jre-1.8.0-openjdk
ENV ELASTICSEARCH_VERSION 6.2.4
ENV TAKE_FILE_OWNERSHIP true

RUN set -ex && \
	yum -y install nc epel-release wget java-1.8.0-openjdk-headless unzip which && \
    yum clean all

WORKDIR /usr/share/elasticsearch

# Download and extract defined ES version.
RUN curl -fsSL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz | \ 
    tar zx --strip-components=1 && \
    for esdirs in config data logs; do \
        mkdir -p "$esdirs"; \
    done && \
    for PLUGIN in ingest-user-agent ingest-geoip; do \
        elasticsearch-plugin install --batch "$PLUGIN";\
    done

COPY elasticsearch.yml log4j2.properties config/

COPY bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 9200 9300

VOLUME /usr/share/elasticsearch/data

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Dummy overridable parameter parsed by entrypoint
CMD ["eswrapper"]
