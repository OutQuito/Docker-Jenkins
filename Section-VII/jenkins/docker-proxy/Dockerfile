FROM debian:bullseye
LABEL maintainer="out.quito@outlook.com"

RUN apt-get update && apt-get install -y wget && \
    wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 && \
    chmod +x /usr/local/bin/dumb-init && \
    apt-get purge -y wget && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y socat procps net-tools iproute2

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
VOLUME /var/run/docker.sock
EXPOSE 2375
CMD ["socat", "TCP-LISTEN:2375,reuseaddr,fork", "UNIX-CLIENT:/var/run/docker.sock"]
