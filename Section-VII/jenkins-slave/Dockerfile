FROM centos:centos7
LABEL maintainer="out.quito@outlook.com"

RUN yum update -y && \
    yum install -y git wget java-1.8.0-openjdk sudo && \
    yum clean all

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

ENV JENKINS_HOME /home/${user}

RUN groupadd -g ${gid} ${group} \
    && useradd -d "${JENKINS_HOME}" -u ${uid} -g ${gid} -m -s /bin/bash ${user}
RUN chown -R ${user}:${user} /home/${user}
RUN echo "${user}   ALL=(ALL)   ALL" >> /etc/sudors

COPY /files/resolv.conf /etc/resolv.conf