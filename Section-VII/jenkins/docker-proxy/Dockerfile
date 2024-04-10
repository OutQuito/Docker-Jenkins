FROM centos:centos7
LABEL maintainer="out.quito@outlook.com"

# Install socat and tini
RUN yum -y install socat && \
    yum -y install wget && \
    wget -O /usr/local/bin/tini-static https://github.com/krallin/tini/releases/download/v0.19.0/tini-static && \
    chmod +x /usr/local/bin/tini-static && \
    yum clean all

# Set entrypoint with tini
ENTRYPOINT ["/usr/local/bin/tini-static", "--"]

# Continue with your configuration
VOLUME /var/run/docker.sock
EXPOSE 2375
CMD ["socat", "TCP-LISTEN:2375,reuseaddr,fork","UNIX-CLIENT:/var/run/docker.sock"]
