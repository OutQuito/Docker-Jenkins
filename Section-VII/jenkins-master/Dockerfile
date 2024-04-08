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

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_VERSION=2.440.2
ARG TINI_VERSION=v0.19.0
ARG JENKINS_SHA=8126628e9e2f8ee2f807d489ec0a6e37fc9f5d6ba84fa8f3718e7f3e2a27312e
ARG JENKINS_URL=https://get.jenkins.io/war-stable/2.440.2/jenkins.war

ENV JENKINS_VERSION ${JENKINS_VERSION}
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war
ENV JAVA_OPTS="-Xmx8192m"
ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log  --webroot=/var/cache/jenkins/war"
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

RUN curl -fsSL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/latest/download/jenkins-plugin-manager.jar -o /usr/local/bin/jenkins-plugin-cli && \
    chmod +x /usr/local/bin/jenkins-plugin-cli

RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}
    
VOLUME /var/jenkins_home

RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
    && echo "${JENKINS_SHA} /usr/share/jenkins/jenkins.war" | sha256sum -c -
RUN chown -R ${user} "${JENKINS_HOME}" /usr/share/jenkins/ref
RUN mkdir /var/log/jenkins
RUN mkdir /var/cache/jenkins
RUN chown -R ${user}:${group} /var/log/jenkins 
RUN chown -R ${user}:${group} /var/cache/jenkins

EXPOSE ${http_port}
EXPOSE ${agent_port}

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy
COPY jenkins-support /usr/local/bin/jenkins-support
COPY plugins.sh /usr/local/bin/plugins.sh
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
RUN chmod +x /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy \
    && chmod +x /usr/local/bin/jenkins-support \
    && chmod +x /usr/local/bin/plugins.sh \
    && chmod +x /usr/local/bin/jenkins.sh \
    && chmod +x /usr/local/bin/install-plugins.sh

COPY plugins.txt /tmp/plugins.txt

RUN jenkins-plugin-cli --plugin-file /tmp/plugins.txt

USER ${user}

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]