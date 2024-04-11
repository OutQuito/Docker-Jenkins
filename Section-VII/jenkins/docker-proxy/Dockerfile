FROM debian:bullseye
LABEL maintainer="out.quito@outlook.com"

RUN apt-get update && \
    apt-get install -y socat && \
    apt-get install -y procps && \
    apt-get install -y net-tools && \
    apt-get install -y iproute2 && \
    apt-get install -y tini

ENTRYPOINT ["/usr/bin/tini", "--"]

VOLUME /var/run/docker.sock
EXPOSE 2375
CMD ["socat", "TCP-LISTEN:2375,reuseaddr,fork","UNIX-CLIENT:/var/run/docker.sock"]
