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
ARG JENKINS_SHA=8126628e9e2f8ee2f807d489ec0a6e37fc9f5d6ba84fa8f3718e7f3e2a27312e
ARG JENKINS_URL=https://get.jenkins.io/war-stable/2.440.2/jenkins.war

ENV JENKINS_VERSION ${JENKINS_VERSION}
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JAVA_OPTS="-Xmx8192m -Djenkins.install.runSetupWizard=false"
ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log  --webroot=/var/cache/jenkins/war"
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

RUN curl -fsSL https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 -o /usr/local/bin/dumb-init && \
    chmod +x /usr/local/bin/dumb-init
RUN curl -fsSL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.15/jenkins-plugin-manager-2.12.15.jar -o /usr/local/bin/jenkins-plugin-manager-2.12.15.jar && \
    chmod +x /usr/local/bin/jenkins-plugin-manager-2.12.15.jar
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
COPY jenkins-plugin-cli /usr/local/bin/jenkins-plugin-cli

RUN chmod +x /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy \
    && chmod +x /usr/local/bin/jenkins-support \
    && chmod +x /usr/local/bin/plugins.sh \
    && chmod +x /usr/local/bin/jenkins.sh \
    && chmod +x /usr/local/bin/jenkins-plugin-cli

COPY plugins.txt /usr/local/bin/plugins.txt

RUN java -jar /usr/local/bin/jenkins-plugin-manager-2.12.15.jar --plugin-file /usr/local/bin/plugins.txt --jenkins-update-center ${JENKINS_UC}

USER ${user}

ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "/usr/local/bin/jenkins.sh"]
