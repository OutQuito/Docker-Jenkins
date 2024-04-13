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

#Похибку було усунуто, завдяки людському фактору. Частина коду від Dockerfile /jenkins-master була випадково перевіщена до Dockerfile /docer-proxy.

Dockerfile /jenkins-master:

    .....
    ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log  --webroot=/var/cache/jenkins/war"
    ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

    RUN curl -fsSL https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 -o /usr/local/bin/dumb-init && \
        chmod +x /usr/local/bin/dumb-init

    RUN curl -fsSL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.15/jenkins-plugin-manager-2.12.15.jar -o /usr/local/bin/jenkins-plugin-manager-2.12.15.jar && \
        chmod +x /usr/local/bin/jenkins-plugin-manager-2.12.15.jar
    .....

Dockerfile /docker-proxy:

    FROM centos:centos7
    LABEL maintainer="mstewart@riotgames.com"

    RUN yum -y install socat && \
        yum clean all

    VOLUME /var/run/docker.sock

    EXPOSE 2375

    ENTRYPOINT ["socat", "TCP-LISTEN:2375,reuseaddr,fork","UNIX-CLIENT:/var/run/docker.sock"]

Ось всі зміний...

# =============== -4- ===============

Ви помітите, що під час збірки jenkins-master ми маємо невелику затримку під час встановлення стандартних плагінів jenkins. Це тому, що ми активно завантажуємо файли плагіна під час процесу створення образу.

# IV. НАЛАШТУВАННЯ JENKINS

Ми на останньому етапі. Зі створеними нашими новими образами нам просто потрібно налаштувати плагін Docker у Jenkins, щоб знати, де знаходиться наш Dockerhost на основі Mac/Win, і зіставити наш підлеглий образ збірки з міткою Jenkins. Для цього нам дійсно потрібен запущений Jenkins, тому давайте подбаємо про це. 

    Якщо ваш попередній екземпляр все ще працює, виконайте команду: make clean-data, щоб очистити старі томи та запущені екземпляри

    make run (або: docker-compose -p jenkins up -d nginx data master

    Перейдіть у свій браузер на: http://localhost 

    Завантаження Jenkins може зайняти кілька хвилин 

Перш ніж продовжити, я хочу коротко розповісти про Дженкінса. У Дженкінса є концепція «вузла побудови» та «завдання». Вузли збірки мають N виконавців. Коли Jenkins хоче запустити завдання, він намагається знайти запасного виконавця (на вузлі збірки), щоб виконати це завдання. Стандартна установка Jenkins намагатиметься знайти будь-який резервний виконавець для запуску. Незважаючи на те, що це просто, більшість установників Jenkins змінюють це, тому що вони хочуть, щоб певні завдання запускалися на певних типах вузлів збірки (уявіть, що вам потрібна операційна система Windows, а не операційна система Linux). Для цього «мітки» застосовуються до вузлів побудови, а завдання обмежуються виконанням лише на вузлах побудови з відповідними мітками. 

Для наших ефемерних підлеглих Docker ми збираємося використовувати цю можливість міток, щоб прив’язувати зображення та завдання Docker до цих міток. Завдяки чудовому дизайну плагіна JClouds і плагіна Docker Jenkins перевіряє мітку завдання, коли воно потрапляє в чергу. Плагін переконається, що для завдання немає доступних виконавців, і тому спробує створити вузол збірки з відповідним образом Docker. Новому вузлу буде присвоєно правильну мітку, і завдання збирання в черзі буде запущено. 

Це, по суті, майже як магія! Така поведінка є ключем до того, як працюють ефемерні вузли. 

Тепер ми готові налаштувати наш Dockerhost і перший ефемерний підлеглий сервер на Jenkins. На цільовій сторінці Jenkins виконайте такі дії: 

    Натисніть «Керувати Jenkins».

    Натисніть «Налаштувати систему».

    Прокрутіть униз, доки не знайдете Додати нову хмару як спадне меню (це надходить із плагіна Jclouds)

    Виберіть Docker зі спадного меню

З’являється нова форма. Ця форма є високорівневою інформацією, яку потрібно ввести про ваш Dockerhost. Зауважте, що ви можете створити багато за бажанням хостів Docker. Це один із способів керування образами збірок, які запускаються на яких машинах. Для цього підручника ми зупинимося на одному. 

    У полі Ім’я введіть «LocalDockerHost»

    У полі Docker Host URI введіть: "tcp://proxy1:2375"

# =============== -5- ===============

#Після запуску контейнерів виявилося що jenkins_proxy дав помилку:

    socat[1] E exactly 2 addresses required (there are 3); use option "-h" for help

    FROM centos:centos7
    LABEL maintainer="mstewart@riotgames.com"

    RUN yum -y install socat && \
        yum clean all

    VOLUME /var/run/docker.sock

    EXPOSE 2375

    ENTRYPOINT ["socat", "TCP-LISTEN:2375,reuseaddr,fork", "UNIX-CONNECT:/var/run/docker.sock"]

У цьому варіанті ми видалили адресу TCP з параметра  TCP-LISTEN та змінили параметр  UNIX-CLIENT на  UNIX-CONNECT, щоб відповідати адресі Unix-сокета. Тепер  socat має правильну кількість адрес, та помилка має би бути усунена.

# =============== -5- ===============

Клацніть Перевірити з’єднання, і ви повинні отримати відповідь, у якій буде показано версію та версію API вашого хосту докерів. 

Якщо відповідь не надходить або ви отримуєте повідомлення про помилку, щось пішло не так, і Дженкінс не може спілкуватися з вашим Dockerhost. Я зробив усе можливе, щоб переконатися, що це покрокове керівництво «просто працює», але ось короткий список речей, які можуть бути порушені та вплинути на це:

    У вашому файлі docker-compose є друкарська помилка. Переконайтеся, що для проксі-контейнера встановлено псевдонім «proxy1».

    Ваш докер-проксі з певної причини не запустився. Перевірте docker ps і перевірте, чи запущено проксі-контейнер.

    З якоїсь причини ваш файл docker.sock не знаходиться в /var/run/docker.sock. Цей посібник передбачає інсталяцію Docker для Mac/Win за замовчуванням. Якщо ви переналаштували його, це не працюватиме.

Якщо ви отримали успішну відповідь під час тестування з’єднання, ми можемо продовжити. Ми хочемо додати наш щойно створений образ підпорядкованого пристрою збірки як потенційного кандидата на вузол збірки. 

Якщо ви отримали успішну відповідь під час тестування з’єднання, ми можемо продовжити. (ТЕСТУВАННЯ УСПІШНЕ Версія = 26.0.1, версія API = 1.45) Ми хочемо додати наш щойно створений образ підпорядкованого пристрою збірки як потенційного кандидата на вузол збірки.

    Установіть прапорець «Увімкнено» (за замовчуванням це вимкнено, це зручний спосіб вимкнути хмарного постачальника для обслуговування/тощо в jenkins)

    Натисніть кнопку Docker Agent templates...

    Натисніть кнопку «Додати шаблон Docker».

    У полі «Мітки» введіть testslave

    Переконайтеся, що встановлено прапорець «Увімкнено» (ви можете використовувати його, щоб вимкнути певні зображення, якщо вони спричиняють проблеми)

    Для поля Docker Image введіть: jenkins_slave

    Для кореня віддаленої файлової системи введіть /home/jenkins (це місце, куди буде розміщено робочий простір jenkins у контейнері)

    Для «Використання» виберіть лише завдання побудови з виразами міток, що відповідають цьому вузлу

    Переконайтеся, що для методу підключення встановлено значення Attach Docker Container (це стандартне значення, яке дозволяє Jenkins приєднуватися/виконуватися в контейнері, запускати підпорядкований агент Jenkins і направляти його назад на ваш сервер Jenkins)

        Для користувача введіть jenkins

    Змінити стратегію витягування на Ніколи не витягувати (ми створюємо цей образ, створюючи його, а не витягуючи його з репо)

Натисніть «Зберегти» внизу сторінки конфігурації 

Нам залишилося зробити останню справу, а саме створити завдання, щоб перевірити це налаштування та переконатися, що все працює. 

# СТВОРЕННЯ ТЕСТОВОГО ЗАВДВННЯ

З точки зору Дженкінса, нічого не змінюється у створенні робочих місць. Ми хочемо переконатися, що завдання, яке ми створюємо, обмежене міткою, яку ми встановили на вузлі зображення Docker, який ми налаштували: testslave.

    На цільовій сторінці Jenkins натисніть New Item

    Для назви елемента введіть «testjob»

    Виберіть проект Freestyle

    Натисніть OK

    Переконайтеся, що встановлено прапорець Обмежити, де можна запускати цей проект

    Введіть «testslave» у вираз мітки

    Прокрутіть униз і виберіть «Виконати оболонку» зі спадного списку «Додати крок збірки».

    У полі команди «Виконати оболонку» введіть: ' echo «Привіт, світ! Це перший ефемерний вузол збірки дитини!» && Сон 1'

    Натисніть Зберегти

Тепер ви перейдете на цільову сторінку нових вакансій. Чому я прошу вас додати Sleep 1? Цікавий факт: засіб підготовки Docker Attach настільки швидкий, що якщо ваше завдання збирання займає менше секунди, я виявив, що він має проблеми з очищенням підпорядкованого пристрою збирання, тому це займе трохи часу, щоб зробити впевнений, що у вас немає рабів, які не прибирають.

Тепер ви готові до моменту істини. 

    Натисніть «Побудувати зараз». 

Тестове завдання увійде до черги збірки, і ви можете побачити «очікування доступних виконавців», поки Дженкінс займатиметься підготовкою нової підлеглої збірки. Залежно від вашої системи, це може статися дуже швидко — фактично настільки швидко, що воно може підготуватися, запустити вашу просту команду echo та завершити роботу, перш ніж ви встигнете її переглянути. Або це може зайняти 20-30 секунд. З власного досвіду можу сказати, що це схоже на те, як спостерігати за кипінням води в чайнику. 

Якщо щось пішло не так, завдання буде зависати в черзі збирання, чекаючи на вузол для надання. Налагодження цієї та інших порад професіоналів дійсно може стати ще одним дописом у блозі, але ось кілька вказівок:



    Переконайтеся, що у вибраній мітці немає помилок у головній конфігурації Jenkins або в самій конфігурації завдання. Jenkins повинен підтвердити, що він знайшов підлеглий тестовий сервер в одному провайдері Cloud.

    Двічі, потрійно, чотири рази перевірте, чи під час налаштування хосту Docker надходить позитивна відповідь від Test Connection.

    Переконайтеся, що ім’я зображення, введене в конфігурацію jenkins, збігається з ім’ям зображення, яке ви бачите, коли запускаєте образи Docker у своєму командному рядку для підпорядкованого пристрою збірки (це має бути jenkins_slave).

    Переконайтеся, що ви встановили режим мережі в розділі «Створити параметри контейнера». Це має бути jenkins_jenkins-net.

    Переконайтеся, що ви вибрали Different Jenkins URL у Launch Mode і що для нього встановлено: http://jenkins_master_1:8080/ (слеші мають значення!).

Для глибшого аналізу ви завжди можете перейти до журналів jenkins і побачити, на що скаржиться плагін. Цільова сторінка Jenkins -> Керування Jenkins -> Системний журнал -> Усі журнали Jenkins. Багато чого можна вивести з помилок, які він створює. Ви також можете перевірити журнали в системі в командному рядку, я залишив зручний ярлик make jenkins-log, щоб стежити за журналами jenkins. Або знайдіть контейнери jenkins_slave, які запускаються в docker ps, і запустіть для них команду docker logs, щоб зрозуміти, чому вони не можуть запуститися.

Однак все повинно працювати - якщо це так, заведіть цей переможний танець. 

# Переможний танець!!!