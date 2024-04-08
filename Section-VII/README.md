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