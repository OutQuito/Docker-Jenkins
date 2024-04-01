FROM jenkins/jenkins:2.440.2-jdk17
LABEL maintainer="out.quito@outlook.com"

USER root

RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
RUN mkdir /var/log/jenkins
RUN mkdir /var/cache/jenkins 
RUN chown -R jenkins:jenkins /var/log/jenkins 
RUN chown -R jenkins:jenkins /var/cache/jenkins

USER jenkins

RUN jenkins-plugin-cli --plugins "blueocean docker-workflow"

ENV JAVA_OPTS="-Xmx8192m"
ENV JENKINS_OPTS="--handlerCountMax=300 --logfile=/var/log/jenkins/jenkins.log --webroot=/var/cache/jenkins/war"