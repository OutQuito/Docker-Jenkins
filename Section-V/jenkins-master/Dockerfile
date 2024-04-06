FROM debian:buster
LABEL maintainer="out.quito@outlook.com"

ENV LANG C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    zip \
    openssh-client \
    unzip \
    openjdk-11-jdk \
    ca-certificates-java \
    && rm -rf /var/lib/apt/lists/*

RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure
RUN mkdir /var/log/jenkins
RUN mkdir /var/cache/jenkins
RUN chown -R jenkins:jenkins /var/log/jenkins 
RUN chown -R jenkins:jenkins /var/cache/jenkins

USER jenkins

ENV JAVA_OPTS="-Xmx8192m"
ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log --webroot=/var/cache/jenkins/war"