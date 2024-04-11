# СТВОРЕННЯ JENKINS всередині ефемерного DOCKER-контейнера

ВИМОГИ:

Передбачає, що ви починаєте з того місця, де ми зупинилися в минулому розділу. Це означає, що у вас є:

    Функціональне середовище Jenkins та знання його роботи

    Функціональна Docker для Mac або Docker для Windows інсталяція

    Базове розуміння Docker і того, як створювати образи та файли Docker

    Попередні навчальні проекти, створені локально

# I. СТВОРЕННЯ ОБРАЗУ DOCKER BUILDSLAVE

У цьому підручнику наші підлеглі будуть досить простими. Я використовуватиму базове середовище Centos 7 з Java 1.8, яке підходить для запуску агента Jenkins Slave. Підключеннями до підлеглого буде керувати плагін Docker, який використовує комбінацію команд docker create/run і exec для запуску зворотного JNLP-з'єднання з головним сервером Jenkins. Це означає, що вам не потрібно налаштовувати на підлеглому сервері нічого складного, наприклад, SSH, щоб він працював як середовище збірки. Нам також потрібно, щоб цей підлеглий сервер працював від імені користувача без прав суперкористувача з міркувань безпеки.

Давайте створимо наш Dockerfile:

    1. Перейдіть до кореневого каталогу проекту

    2. mkdir jenkins-slave && cd jenkins-slave

    3. Скористайтеся улюбленим редактором, щоб створити новий Dockerfile

    4. Додайте наступний текст і збережіть:

    FROM centos:centos7
    LABEL maintainer="mstewart@riotgames.com"

    # Install Essentials
    RUN yum update -y && \
        yum clean all

    # Install Packages
    RUN yum install -y git && \
        yum install -y wget && \
        yum install -y java-1.8.0-openjdk && \
        yum install -y sudo && \
        yum clean all

    ARG user=jenkins
    ARG group=jenkins
    ARG uid=1000
    ARG gid=1000

    ENV JENKINS_HOME /home/${user}

    # Jenkins is run with user `jenkins`, uid = 1000
    RUN groupadd -g ${gid} ${group} \
        && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

    RUN chown -R ${user}:${user} /home/${user}

    # Add the jenkins user to sudoers
    RUN echo "${user}    ALL=(ALL)    ALL" >> etc/sudoers

    # Set Name Servers
    COPY /files/resolv.conf /etc/resolv.conf

# =============== -1- ===============

#Зменшуємо кітькість кроків коду що вказаний вище, це допоможе зменшити розмір кінцевого образу, а саме:

    # Install Packages
    RUN yum install -y git && \
        yum install -y wget && \
        yum install -y java-1.8.0-openjdk && \
        yum install -y sudo && \
        yum clean all

Змінюємо на:

    RUN yum update -y && \
        yum install -y git wget java-1.8.0-openjdk sudo && \
        yum clean all

# =============== -1- ===============

Пройдемося по структурі коду

ПАКЕТИ ВСТАНОВЛЕННЯ:

    RUN yum update -y && \
        yum install -y git wget java-1.8.0-openjdk sudo && \
        yum clean all

java 1.8 - openjdk - для підлеглих пристроїв Jenkins 

Git - мій улюблений клієнт керування джерелами

Wget – я часто використовую це в сценаріях збірки та створенні Dockerfile 

sudo – можливо, нам знадобиться підвищити привілеї для певних функцій збирання, тому це добре мати 

НАЛАШТУВАННЯ ЛОКАЛЬНОГО КОРИСТУВАЧА JENKINS

    ARG user=jenkins
    ARG group=jenkins
    ARG uid=1000
    ARG gid=1000

    ENV JENKINS_HOME /home/${user}

    # Jenkins is run with user `jenkins`, uid = 1000
    RUN groupadd -g ${gid} ${group} \
        && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}
    RUN chown -R ${user}:${user} /home/${user}

    # Add the jenkins user to sudoers
    RUN echo "${user}    ALL=(ALL)    ALL" >> etc/sudoers

Здебільшого це стандартні налаштування користувача. Зауважте, що ми повторно використовуємо параметри збірки, які ми мали в образі jenkins-master, щоб визначити користувача Jenkins (це дає вам можливість легко змінити).

Оскільки завдання збирання виконуватимуться від імені користувача jenkins, ми надаємо йому привілеї sudo, щоб ці завдання могли підвищувати свої дозволи. Вам це може не знадобитися залежно від характеру роботи, яку виконують ваші будівельні завдання. 

НАЛАШТУВАННЯ СЕРВЕРНИХ ІМЕН

    # Set Name Servers
    COPY /files/resolv.conf /etc/resolv.conf

Я стикався з кількома цікавими ситуаціями, коли контейнерам Docker важко було правильно маршрутизувати або розпізнавати DNS-імена, тому я переконався, що правильні DNS-сервери додано до моїх підлеглих комп’ютерів. У своїх середовищах Riot я використовую внутрішні сервери імен, але для цієї демонстрації ми використовуватимемо загальнодоступні сервери Google. Незабаром ми створимо вихідний файл для цього. 

СТВОРЕННЯ ФАЙЛУ resolv.conf

Ось файл resolv.conf для демонстраційних цілей, він просто зіставляється з DNS-серверами Google: 

    nameserver 8.8.8.8
    nameserver 8.8.4.4

Створіть новий каталог для цього файлу, додайте та видаліть записи відповідно до вашої локальної мережі. Наприклад, у більшості випадків ми використовуємо внутрішні DNS-сервери Riot, щоб ми могли маршрутизувати до нашого сховища артефактів, репозиторіїв зображень та інших необхідних елементів. 

ТЕСТУЄМО СВІЙ SLAVE BUILD

Поверніться до кореневого каталогу вашого проекту та створіть slave. 

    docker build -t testslave jenkins-slave 

Якщо припустити, що все пройшло без помилок, тепер ви готові додати підлеглий пристрій до проекту Docker Compose. 

# =============== -2- ===============

    [+] Building 101.5s (11/11) FINISHED                                            docker:default
    => [internal] load build definition from Dockerfile
    => => transferring dockerfile: 544B
    => [internal] load metadata for docker.io/library/centos:centos7
    => [internal] load .dockerignore
    => => transferring context: 2B
    => CACHED [1/6] FROM docker.io/library/centos:centos7@sha256:be65f488b7764ad3638f236b7b
    => [internal] load build context
    => => transferring context: 110B
    => [2/6] RUN yum update -y &&     yum install -y git wget java-1.8.0-openjdk sudo &&
    => [3/6] RUN groupadd -g 1000 jenkins     && useradd -d "/home/jenkins" -u 1000 -g 1000
    => [4/6] RUN chown -R jenkins:jenkins /home/jenkins 
    => [5/6] RUN echo "jenkins   ALL=(ALL)   ALL" >> /etc/sudors
    => [6/6] COPY /files/resolv.conf /etc/resolv.conf
    => exporting to image
    => => exporting layers
    => => writing image sha256:a26f4df5e170f7aaf2f0853e749fefae11e1e04238680bc75f584b01e9ca
    => => naming to docker.io/library/testslave

Тест пройшов УСПІШНО!

# =============== -2- ===============

# II. СТВОРЕННЯ КОНТЕЙНЕРА DOCKER-PROXY ТА ОНОВЛЕННЯ DOCKER-

Нам потрібно буде додати ще один контейнер до вашої екосистеми Jenkins. Проблема, яку нам потрібно вирішити, полягає в тому, що Дженкінс після налаштування захоче спілкуватися з хостом Docker, щоб надати підлеглі як частину його налаштування для плагіна Docker. Єдиний хост Docker, який ми маємо, — це ваше середовище розробки з Docker для Mac або Docker для Windows.

За замовчуванням Docker для Mac і Docker для Windows не надають загальнодоступний порт 2375 для Docker. Хоча Docker для Windows дозволяє ввімкнути це як функцію, Docker для Mac не робить це з міркувань безпеки. За відсутності рішення, яке б однаково працювало на обох платформах, найпростішим рішенням для Docker для Windows є ввімкнення доступу до порту, про що я розповім у кінці цього розділу). Якщо ви використовуєте Docker для Mac, вам доведеться трохи попрацювати. Хороша новина полягає в тому, що ви миттєво вирішите цю проблему за допомогою нових можливостей docker-compose та Dockerfile.

# Створення образу-proxy

Спочатку нам потрібно налаштувати образ Docker-Proxy. Мета тут полягає в тому, щоб взяти ваш файл docker.sock і відкрити його на порту 2375 безпечно і лише для Jenkins. Нам потрібно це зробити, тому що плагін Jenkins Docker розраховує спілкуватися з портом через TCP/IP або HTTP. У робочому середовищі це була б певна кінцева точка Docker Swarm, але тут, у локальних налаштуваннях, це лише ваш робочий стіл. Майте на увазі, що ми не хочемо відкривати цей порт на вашому робочому столі для вашої мережі. Отже, коли ми отримаємо образ, ми приєднаємо його до нашої докер-мережі для Jenkins, де він зможе зберегти цей порт приватним.

Ви знаєте, як створити свій імідж. Ми збираємося створити Dockerfile у каталозі та додати це зображення до файлу docker-compose.yml, щоб compose міг створити та запустити його для нас і керувати його мережевими налаштуваннями.

Для початку переконайтеся, що ви перебуваєте в кореневому каталозі проекту: 

    1. mkdir docker-proxy

    2. code docker-proxy/Dockerfile

    Add the following Dockerfile:
    FROM centos:centos7
    LABEL maintainer="yourname@somewhere.com"

    RUN yum -y install socat && \
    yum clean all

    VOLUME /var/run/docker.sock

    # docker tcp port
    EXPOSE 2375

    ENTRYPOINT ["socat", "TCP-LISTEN:2375,reuseaddr,fork","UNIX-CLIENT:/var/run/docker.sock"]

    3. Збережіть файл Docker і вийдіть із редактора

Ви побачите, що це досить просто. Socat — це проста утиліта Linux для передачі даних між двома потоками байтів. Ви можете прочитати більше про це в цій чудовій статті на linux.com . Ми створюємо простий образ докера, щоб розмістити наш docker.sock з робочого столу на одному кінці та TCP-порт 2375 на іншому. Ось чому образи докерів монтують том, який містить файл сокета, з’єднуючи робочий стіл із мережею докерів. 

# Додавання проксі до Docker-Compose

Щоб додати цей проксі до наших налаштувань, ми використаємо кілька чудових мережевих трюків Docker із нашим файлом docker-compose. Відкрийте файл docker-compose.yml і зробіть наступне: 

Додайте наступне, щоб створити запис для вашого нового підлеглого в кінці службового розділу вашого файлу створення:

    slave:
        build: ./jenkins-slave

Додайте наступну службу після налаштування служби «slave:»

    proxy:
    image: ehazlett/docker-proxy:latest
    command: -i
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      jenkins-net:
        aliases:
          - proxy1

Додайте нову службу, яку ми будемо називати проксі. 

Замість посилання на «збірку» він використовує зображення, яке в даному випадку надходить з dockerhub. Засіб docker-compose автоматично видалить цей образ, якщо його не розгорнути (проте запам’ятайте всі мої застереження щодо використання речей, які ви не створювали). 

Він надає команду «запуск докера» «-i» (ми можемо побачити це, прочитавши джерело для докер-проксі). 

Він монтує /var/run/docker.sock у контейнер (це ваш локальний сокет докера). Це тому, що проксі працює, відкриваючи це через HTTP (на порту 2375 за замовчуванням). 

Ми приєднали його до мережі jenkins-net, щоб будь-який контейнер у цій мережі міг бачити його. 

Ми надаємо йому псевдонім DNS proxy1. Це пояснюється тим, що контейнери за замовчуванням використовуватимуть свої назви Docker-compose, підкреслення тощо. Це спричиняє певні проблеми для плагіна Docker, якому для підключення потрібне надійне ім’я tcp://, тому ми просто вибираємо простішу нову назву. 

З цим на місці ваш створений файл тепер створить проксі-сервіс, який прослуховує порт 2375, але відкритий лише для контейнерів у вашій мережі jenkins-net. Це зберігає ваше локальне середовище в безпеці, але дозволяє таким програмам, як Jenkins, спілкуватися з вашим хостом Docker! 

    version: "3"
    services:
    master:
        build: ./jenkins-master
        ports:
        - "50000:50000"
        volumes:
        - jenkins-log:/var/log/jenkins
        - jenkins-data:/var/jenkins_home
        networks:
        - jenkins-net
    nginx:
        build: ./jenkins-nginx
        ports:
        - "80:80"
        networks:
        - jenkins-net
    slave:
        build: ./jenkins-slave
    proxy:
        image: ehazlett/docker-proxy:latest
        command: -i
        volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        networks:
        jenkins-net:
            aliases:
            - proxy1
    volumes:
    jenkins-data:
    jenkins-log:
    networks:
    jenkins-net:

Останнє, що ми хочемо зробити, це оновити makefile, щоб переконатися, що він не викликає підлеглого Jenkins, коли ми запускаємо docker-compose. Відкрийте make-файл для редагування та переконайтеся, що він виглядає так: 

    build:
        @docker-compose -p jenkins build
    run:
        @docker-compose -p jenkins up -d nginx master proxy
    stop:
        @docker-compose -p jenkins down
    clean-data: 
        @docker-compose -p jenkins down -v
    clean-images:
        @docker rmi `docker images -q -f "dangling=true"`
    jenkins-log:
        @docker-compose -p jenkins exec master tail -f /var/log/jenkins/jenkins.log

# III. ОНОВИЛЕННЯ ФАЙЛУ DOCKER JENKINS MASTER

З належним чином створеним, перевіреним і доданим докер-компонентним файлом підпорядкованого пристрою нам потрібно внести деякі зміни в докер-файл Jenkins Master. Зокрема, нам потрібно додати дві речі: 

1.Попередньо встановіть плагін Docker і його залежності 

2.Вимкніть майстер запуску Jenkins

# Встановлення плагінів за замовченням

У минулому підручнику я згадав чудову утиліту сценарію оболонки, яку Cloudbees надає у своєму образі Jenkins за замовчуванням, щоб допомогти попередньо завантажити плагіни під час створення нового образу, і ми скористаємося цим тут. 

Ми хочемо встановити плагін Docker, для якого потрібні такі плагіни: 

    jdk-tool

    jclouds-jenkins

    Durable-task

    ssh-slaves

    token-macro

Плагін ssh-slaves сьогодні є частиною стандартної інсталяції Jenkins, але нам потрібно встановити інші чотири. Це легко зробити: 

1.Створіть файл jenkins-master/plugins.txt у вашому улюбленому редакторі 

2. Додайте до нього наступні чотири рядки та збережіть: 

    jdk-tool
    jclouds-jenkins
    token-macro
    durable-task
    docker-plugin

Все, що зараз потрібно, це помістити цей файл в образ Jenkins і запустити сценарій install-plugins.sh, створений в останньому посібнику. Щоб досягти цього, давайте відредагуємо файл Docker jenkins-master і додамо два нових рядки. 

1.Відредагуйте файл jenkins-master/Docker у своєму улюбленому редакторі 

2.Додайте наступні рядки відразу після розділу «# Копіювати в локальні конфігураційні файли»: 

    # Install default plugins
    COPY plugins.txt /tmp/plugins.txt
    RUN /usr/local/bin/install-plugins.sh < /tmp/plugins.txt

    make build 

# =============== -3- ===============

#Виникла помилка те, що скрипт install-plugins.sh більше не підтримується, і ми повинні переключитися на jenkins-plugin-cli. Однак ми використовуєте застарілий спосіб встановлення плагінів у вашому Dockerfile.

Замість використання install-plugins.sh, використовуйте  jenkins-plugin-cli.

1.Видаліть рядок, який містить виклик  install-plugins.sh: 

    RUN /usr/local/bin/install-plugins.sh < /tmp/plugins.txt

2.Замініть його встановленням плагінів за допомогою jenkins-plugin-cli:

    RUN jenkins-plugin-cli --plugin-file /tmp/plugins.txt

3.До файлу jenkins-plugin-cli вносимо такі зміни та зберігаємо його

    jenkins-plugin-cli --plugin-file plugins.txt

Після багатюх помилок нарешті вдалося створити build, ось так наразі виглядає Dockerfile:

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
    ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
    ENV JAVA_OPTS="-Xmx8192m"
    ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log  --webroot=/var/cache/jenkins/war"
    ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

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

    ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

Хочу зауважити що файл install-plugins.sh був видалений та замінений на jenkins-plugin-cli:

    #!/bin/bash
    ./jenkins-plugin-cli --plugin-file /tmp/plugins.txt

# =============== -3- ===============

    make clean-images 

# Вимикаємо майстер запуску

Під час більшості навчальних посібників я залишав увімкненим майстер запуску Jenkins. У цьому останньому підручнику ми перетворюємо наш Jenkins-in-a-box на справжнє тестове налаштування, і ми не хочемо проходити через майстер запуску кожного разу, коли створюємо або ініціалізуємо наш сервер Jenkins. На щастя, cloudbees пропонує перемикач для вимкнення майстра у змінній середовища JAVA_OPTS. Просто пам’ятайте, що це залишає ваш сервер Jenkins у незахищеному стані. Вам слід додати обліковий запис адміністратора або іншу форму автентифікації, якщо ви збираєтеся використовувати цю установку в робочій версії.

Вимкніть майстер запуску, відредагувавши файл Docker jenkins-master: 

1.Знайдіть рядок для ENV JAVA_OPTS= 
2.Додайте наступний текст після налаштування пам’яті: -Djenkins.install.runSetupWizard=false
3.Збережіть Dockerfile

Як завжди, я використовую CentOS як основний образ. Дивіться мої попередні публікації в блозі про те, як змінити це на те, що вам зручно, як-от Ubuntu або Debian, як вважаєте за потрібне. 

# Cтворюємо

Усі базові файли оновлено, тому ми готові до створення нового проекту. Давайте зробимо це, щоб переконатися, що у нас є свіжий набір зображень.

    make build (або: docker-compose -p jenkins build)

    створити чисті зображення (або: docker rmi docker images -q -f "dangling=true")

# =============== -4- ===============

Creating network "jenkins_jenkins-net" with the default driver
Creating network "jenkins_default" with the default driver
Creating volume "jenkins_jenkins-data" with default driver
Creating volume "jenkins_jenkins-log" with default driver
Pulling proxy (ehazlett/docker-proxy:latest)...
ERROR: The image for the service you're trying to recreate has been removed. If you continue, volume data could be lost. Consider backing up your data before continuing.

#Було змінено Dockerfile директорії docker-proxy

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

У цьому оновленому Dockerfile я встановив tini та додав його як ініціалізаційний процес у середовище контейнера. Також було змінено ім'я завантаженого файлу з GitHub з tini на tini-static.

#Після проведення безліч спроб запустити контейнери, помилка з tini так і не вирішелась. Спробуємо перейти на dumb-init замість tini.

    ERROR: for jenkins_master_1  Cannot start service master: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: exec: "/usr/local/bin/tini": stat /usr/local/bin/tini: no such file or directory: unknown

    ERROR: for master  Cannot start service master: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: exec: "/usr/local/bin/tini": stat /usr/local/bin/tini: no such file or directory: unknown
    ERROR: Encountered errors while bringing up the project.

# =============== -4- ===============

Ви помітите, що під час збірки jenkins-master ми маємо невелику затримку під час встановлення стандартних плагінів jenkins. Це тому, що ми активно завантажуємо файли плагіна під час процесу створення образу.

# IV. НАЛАШТУВАННЯ JENKINS

Ми на останньому етапі. Зі створеними нашими новими образами нам просто потрібно налаштувати плагін Docker у Jenkins, щоб знати, де знаходиться наш Dockerhost на основі Mac/Win, і зіставити наш підлеглий образ збірки з міткою Jenkins. Для цього нам дійсно потрібен запущений Jenkins, тому давайте подбаємо про це. 

    Якщо ваш попередній екземпляр все ще працює, виконайте команду: make clean-data, щоб очистити старі томи та запущені екземпляри

    make run (або: docker-compose -p jenkins up -d nginx data master

    Перейдіть у свій браузер на: http://localhost 

    Завантаження Jenkins може зайняти кілька хвилин 




