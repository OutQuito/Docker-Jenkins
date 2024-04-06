# КОНТРОЛЬ ОБРАЗУ DOCKER 

Як провести зворотне проектування того, що міститься в загальнодоступному образі Docker

Як створити власну версію зображення, щоб мінімізувати залежності (і знати, що на ваших зображеннях)

Речі, які варто розглянути, розгортаючи власні зображення Docker 

    Керування стандартним рівнем ОС образу. Якщо Dockerfile покладається на ланцюжок пропозицій FROM, будь-яка з них першою керує ОС. Тому знати все, що входить до використовуваного зображення, необхідно, щоб змінити його.

    Кожне зображення, яке використовується в ланцюжку успадкування, може походити з загальнодоступного джерела та потенційно може бути змінено без попередження та може містити щось небажане. Безумовно, існує загроза безпеці, але для мене це також полягає в тому, щоб не дозволяти змінюватися без попередження.

# I. ВИЯВЛЕННЯ ЗАЛЕЖНОСТЕЙ

Перший крок — звернути увагу на те, що є в списку залежностей для Dockerfile, який у нас є. 

Спочатку нам потрібно знайти Dockerfile, який визначає образ, який ми використовуємо. Dockerhub робить це досить безболісним, і ми будемо використовувати Dockerhub, щоб вести нас до всіх Dockerfiles зображень, які ми шукаємо, починаючи з зображення Jenkins. Щоб зрозуміти, який образ ми використовуємо, все, що потрібно, це поглянути на створений нами раніше Dockerfile jenkins-master. 

    FROM jenkins/jenkins:2.112
    LABEL maintainer=”mstewart@riotgames.com”

    # Prep Jenkins Directories
    USER root
    RUN mkdir /var/log/jenkins
    RUN mkdir /var/cache/jenkins
    RUN chown -R jenkins:jenkins /var/log/jenkins
    RUN chown -R jenkins:jenkins /var/cache/jenkins
    USER jenkins

    # Set Defaults
    ENV JAVA_OPTS="-Xmx8192m"
    ENV JENKINS_OPTS="--handlerCountMax=300 --logfile=/var/log/jenkins/jenkins.log  --webroot=/var/cache/jenkins/war"

Ми бачимо, що пункт FROM вказує на jenkins/jenkins:2.112. У термінах Dockerfile це означає зображення під назвою jenkins/jenkins із тегом 2.112, що є версією Jenkins. Давайте пошукаємо це на Dockerhub.

1. Перейдіть на сторінку: http://hub.docker.com

2. Dockerhub надзвичайно корисний для публічного обміну зображеннями, і якщо ви хочете, ви можете зареєструвати обліковий запис, але цей підручник не вимагає цього.

3. У вікні пошуку введіть назву зображення, в даному випадку: jenkins/jenkins.

4. Повернеться список сховищ зображень. Натисніть Дженкінс/Дженкінс у верхній частині. Будьте обережні, щоб не сплутати зображення jenkinsci/jenkins!

5. Тепер ви повинні побачити опис зображення. Зверніть увагу на вкладку тегів. Усі зображення на Dockerhub містять цей розділ.

6. Натисніть вкладку тегів, щоб отримати список усіх відомих тегів для цього зображення. Ви побачите, що є багато варіантів. Клацніть назад на тег Repo Info.

7. Те, що ми шукаємо, це використання Dockerfile для створення цих зображень. Зазвичай вкладка інформації про сховище містить посилання на github або інший загальнодоступний ресурс, звідки походить «Джерело» зображення. У випадку Jenkins в описі є посилання на документацію. 

8. Перейшовши за посиланням, ви перейдете прямо на сторінку Github з деталями Dockerfile, що є тим, що ми шукаємо. Для стислості це репо зараз доступне за цим посиланням: https://github.com/jenkinsci/docker . Ви можете знайти Dockerfile на верхньому рівні.

Наша мета — скопіювати цей файл Docker, але володіти залежностями, тому збережіть текст цього файлу. Ми зберемо наш новий Dockerfile наприкінці цього підручника, коли отримаємо повний список усіх залежностей. До речі, поточний файл Jenkins Docker: 

    FROM openjdk:8-jdk

    RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

    ARG user=jenkins
    ARG group=jenkins
    ARG uid=1000
    ARG gid=1000
    ARG http_port=8080
    ARG agent_port=50000

    ENV JENKINS_HOME /var/jenkins_home
    ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

    # Jenkins is run with user `jenkins`, uid = 1000
    # If you bind mount a volume from the host or a data container,
    # ensure you use the same uid
    RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

    # Jenkins home directory is a volume, so configuration and build history
    # can be persisted and survive image upgrades
    VOLUME /var/jenkins_home

    # `/usr/share/jenkins/ref/` contains all reference configuration we want
    # to set on a fresh new installation. Use it to bundle additional plugins
    # or config file with your custom jenkins Docker image.
    RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

    # Use tini as subreaper in Docker container to adopt zombie processes
    ARG TINI_VERSION=v0.16.1
    COPY tini_pub.gpg /var/jenkins_home/tini_pub.gpg
    RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
    && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
    && gpg --import /var/jenkins_home/tini_pub.gpg \
    && gpg --verify /sbin/tini.asc \
    && rm -rf /sbin/tini.asc /root/.gnupg \
    && chmod +x /sbin/tini

    COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

    # jenkins version being bundled in this docker image
    ARG JENKINS_VERSION
    ENV JENKINS_VERSION ${JENKINS_VERSION:-2.60.3}

    # jenkins.war checksum, download will be validated using it
    ARG JENKINS_SHA=2d71b8f87c8417f9303a73d52901a59678ee6c0eefcf7325efed6035ff39372a

    # Can be used to customize where jenkins.war get downloaded from
    ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

    # could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
    # see https://github.com/docker/docker/issues/8331
    RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
    && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

    ENV JENKINS_UC https://updates.jenkins.io
    ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
    RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

    # for main web interface:
    EXPOSE ${http_port}

    # will be used by attached slave agents:
    EXPOSE ${agent_port}

    ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

    USER ${user}

    COPY jenkins-support /usr/local/bin/jenkins-support
    COPY jenkins.sh /usr/local/bin/jenkins.sh
    COPY tini-shim.sh /bin/tini
    ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

    # from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
    COPY plugins.sh /usr/local/bin/plugins.sh
    
Найважливіше зауважити, що Дженкінс використовує FROM openjdk:8-jdk, який буде наступним файлом Docker, який нам потрібно знайти.

Однак перед тим, як ми це зробимо, ми повинні зрозуміти все в цьому файлі, оскільки ми хочемо відтворити його у нашому власному Dockerfile. Тут багато чого: Cloudbees доклав чимало зусиль, щоб створити надійний образ Docker. Основні моменти, на які варто звернути увагу:

1. Змінні середовища встановлено для JENKINS_HOME, JENKINS_SLAVE_PORT, JENKINS_UC і JENKINS_VERSION.

2. Dockerfile ARG (аргументи часу збірки) налаштовано для:

    1.user

    2.group

    3.uid

    4.gid

    5.http_port

    6.agent_port

    7.TINI_VERSION

    8.JENKINS_VERSION

    9.JENKINS_SHA

    10.JENKINS_URL

3. Зображення використовує Tini , щоб допомогти керувати будь-якими процесами зомбі, що є цікавим доповненням. Ми збережемо це, оскільки для Jenkins необхідний підпроцес.

4. Файл war Jenkins затягуєтья в образі Dockerfile із записом curl.

5. Сам файл встановлює curl і git за допомогою apt-get, що дозволяє нам знати, що ОС є Debian/Ubuntu Linux. 

6. Три файли копіюються в контейнер із джерела: jenkins.sh, plugins.sh та init.groovy. Нам знадобляться версії їх у нашому власному образі, якщо ми хочемо поділитися цією поведінкою. 

7. Кілька портів представлені у вигляді змінних http_port і agent_port (8080 і 50000 відповідно), для Jenkins для прослуховування та Slaves для спілкування з Jenkins відповідно.

Це гарна нагода подумати, скільки роботи потребуватиме керування нашим власним Dockerfile.

Відклавши Jenkins Dockerfile, нам потрібно повторити процес для кожного речення FROM, яке ми знайдемо, поки не дійдемо до базової операційної системи. Це означає повторний пошук Dockerhub наступного зображення: у цьому випадку openjdk:8-jdk

1. Введіть openjdk у вікно пошуку Dockerhub (переконайтеся, що ви перебуваєте на головній сторінці Dockerhub, а не просто шукаєте в репозиторії Jenkins).

# =============== ВІДСТУП ===============

#На момент читання статьї (06.04.24) тег openjbk занадто сильно змінився, вподальшому потрібно враховувати всі залежності які змінили версії своїх публікаций.

    23-ea-17-jdk-oraclelinux9, 23-ea-17-oraclelinux9, 23-ea-jdk-oraclelinux9, 23-ea-oraclelinux9, 23-jdk-oraclelinux9, 23-oraclelinux9, 23-ea-17-jdk-oracle, 23-ea-17-oracle, 23-ea-jdk-oracle, 23-ea-oracle, 23-jdk-oracle, 23-oracle

# =============== КІНЕЦЬ ===============

2. openjdk повертається як перше сховище. Натисніть на нього. 

3. У розділі Підтримувані теги ми бачимо, що Java має багато різних тегів і зображень. Знайдіть рядок, у якому згадується тег, який ми шукаємо, 8-jdk, і перейдіть за посиланням на його Dockerfile.

Це цікавий образ. Це загальнодоступний образ openjdk 8-jdk, який сам у реченні FROM посилається на ще один публічний образ, buildpack-deps:stretch-scm. Тож нам доведеться шукати інше зображення, але ми ще не з’ясували, що на зображенні, яке ми маємо. 

Це зображення робить кілька речей, на які ми повинні звернути увагу:

1. Встановлює bzip, unzip і xz-utils. 

2. икористовує apt-get для встановлення opendjdk-8 і ca-certificates за допомогою набору складних сценарії

Для довідки, ось весь Dockerfile (27.08.2015): 

    # NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
    #
    # PLEASE DO NOT EDIT IT DIRECTLY.
    #

    FROM buildpack-deps:stretch-scm

    # A few reasons for installing distribution-provided OpenJDK:
    #
    #  1. Oracle.  Licensing prevents us from redistributing the official JDK.
    #
    #  2. Compiling OpenJDK also requires the JDK to be installed, and it gets
    #     really hairy.
    #
    #     For some sample build times, see Debian's buildd logs:
    #       https://buildd.debian.org/status/logs.php?pkg=openjdk-8

    RUN apt-get update && apt-get install -y --no-install-recommends \
            bzip2 \
            unzip \
            xz-utils \
        && rm -rf /var/lib/apt/lists/*

    # Default to UTF-8 file.encoding
    ENV LANG C.UTF-8

    # add a simple script that can auto-detect the appropriate JAVA_HOME value
    # based on whether the JDK or only the JRE is installed
    RUN { \
            echo '#!/bin/sh'; \
            echo 'set -e'; \
            echo; \
            echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
        } > /usr/local/bin/docker-java-home \
        && chmod +x /usr/local/bin/docker-java-home

    # do some fancy footwork to create a JAVA_HOME that's cross-architecture-safe
    RUN ln -svT "/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)" /docker-java-home
    ENV JAVA_HOME /docker-java-home

    ENV JAVA_VERSION 8u162
    ENV JAVA_DEBIAN_VERSION 8u162-b12-1~deb9u1

    # see https://bugs.debian.org/775775
    # and https://github.com/docker-library/java/issues/19#issuecomment-70546872
    ENV CA_CERTIFICATES_JAVA_VERSION 20170531+nmu1

    RUN set -ex; \
        \
    # deal with slim variants not having man page directories (which causes "update-alternatives" to fail)
        if [ ! -d /usr/share/man/man1 ]; then \
            mkdir -p /usr/share/man/man1; \
        fi; \
        \
        apt-get update; \
        apt-get install -y \
            openjdk-8-jdk="$JAVA_DEBIAN_VERSION" \
            ca-certificates-java="$CA_CERTIFICATES_JAVA_VERSION" \
        ; \
        rm -rf /var/lib/apt/lists/*; \
        \
    # verify that "docker-java-home" returns what we expect
        [ "$(readlink -f "$JAVA_HOME")" = "$(docker-java-home)" ]; \
        \
    # update-alternatives so that future installs of other OpenJDK versions don't change /usr/bin/java
        update-alternatives --get-selections | awk -v home="$(readlink -f "$JAVA_HOME")" 'index($3, home) == 1 { $2 = "manual"; print | "update-alternatives --set-selections" }'; \
    # ... and verify that it actually worked for one of the alternatives we care about
        update-alternatives --query java | grep -q 'Status: manual'

    # see CA_CERTIFICATES_JAVA_VERSION notes above
    RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure

    # If you're reading this and have any feedback on how this image could be
    # improved, please open an issue or a pull request so we can discuss it!
    #
    #   https://github.com/docker-library/openjdk/issues

Нам потрібно буде відтворити та/або досягти всього тут. Важливо пам’ятати, що цей Dockerfile створено для стійкості та використання великою кількістю загальнодоступних зображень. Нам, напевно, не потрібна складність, присутня тут, але знати, що встановлено, важливо. Наразі давайте знайдемо наступний файл Docker, це buildpack-deps:stretch-scm. Для цього ми повторюємо процес, який ми вже виконали:

1. Знайдіть buildpack-deps на головній сторінці Dockerhub і виберіть перший результат. 

2. stretch-scm є записом, розташованим далеко в списку підтримуваних тегів. Натисніть посилання, щоб знайти його Dockerfile

# =============== ВІДСТУП ===============

#На момент читання статьї (06.04.24) в тегах stretch-scm незнайдений. Якщо stretch-scm був замінений чимось новим, ймовірно, він був оновлений на більш сучасний базовий образ, наприклад, buster-scm (якщо йдеться про Debian), або можливо був використаний інший підхід для роботи з репозиторіями. buster-scm у списку тегів є, сподіваюсь що це він.
    
    bookworm-curl, stable-curl, curl
    bookworm-scm, stable-scm, scm
    bookworm, stable, latest
    bullseye-curl, oldstable-curl
    bullseye-scm, oldstable-scm
    bullseye, oldstable
    buster-curl, oldoldstable-curl
    buster-scm, oldoldstable-scm
    buster, oldoldstable
    sid-curl, unstable-curl
    sid-scm, unstable-scm
    sid, unstable
    trixie-curl, testing-curl
    trixie-scm, testing-scm
    trixie, testing
    focal-curl, 20.04-curl
    focal-scm, 20.04-scm
    focal, 20.04
    jammy-curl, 22.04-curl
    jammy-scm, 22.04-scm
    jammy, 22.04
    mantic-curl, 23.10-curl
    mantic-scm, 23.10-scm
    mantic, 23.10
    noble-curl, 24.04-curl
    noble-scm, 24.04-scm
    noble, 24.04

Знайшо посилання на stretch-scm https://github.com/docker-library/buildpack-deps/blob/1845b3f918f69b4c97912b0d4d68a5658458e84f/stretch/scm/Dockerfile його Dockerfile:

До уваги що оновлення репо по посиланню було 9 років тому на момент написання цього README.

FROM buildpack-deps:stretch-curl

    # procps is very common in build systems, and is a reasonably small package
    RUN apt-get update && apt-get install -y --no-install-recommends \
            bzr \
            git \
            mercurial \
            openssh-client \
            subversion \
            \
            procps \
        && rm -rf /var/lib/apt/lists/* 

Для порівняння ось Dockerfile buster-scm що міг прийти на заміну stretch-scm:

    FROM buildpack-deps:buster-curl

    RUN set -eux; \
        apt-get update; \
        apt-get install -y --no-install-recommends \
            git \
            mercurial \
            openssh-client \
            subversion \
            \
    # procps is very common in build systems, and is a reasonably small package
            procps \
        ; \
        rm -rf /var/lib/apt/lists/*

Ось коротка різниця цих Dockerfile

1. Версія Debian :  stretch проти  buster.  stretch - це старша стабільна версія Debian, тоді як  buster є новішою версією, що містить більше оновлень та нового програмного забезпечення. 

2. Пакунки за замовчуванням : У першому Dockerfile встановлюється кілька додаткових пакунків, таких як  bzr та  curl, крім тих, що вказані в другому Dockerfile.

3. Програмні залежності: У першому Dockerfile використовується apt-get update && apt-get install, тоді як у другому Dockerfile використовується set -eux; apt-get update; apt-get install. В першому випадку, команди об'єднуються у одну команду за допомогою &&, а в другому використовується set -eux; для встановлення strict mode, де будь-яка помилка в будь-якій команді призведе до виходу з виконання скрипта.

4. Розділення команди : У другому Dockerfile кожна команда встановлення пакунків закінчується  \, що дозволяє розділити їх на кілька рядків для кращої зручності читання.

В іншому випадку обидва Dockerfile роблять схожі речі: встановлюють зазначені пакунки за допомогою apt-get install, а потім очищають кеш apt для зменшення розміру образу.

# =============== КІНЕЦЬ ===============

3. Цей Dockerfile короткий і приємний. Ми бачимо ще один файл Docker у ланцюжку залежностей під назвою buildpack-deps:stretch-curl. Але крім цього, цей Dockerfile лише встановлює шість речей.

    1.bzr

    2.git

    3.mercurial

    4.openssh-client

    5.subversion

    6.procps

Це має сенс, оскільки він виставляється як образ SCM. Це ще одна можливість зважити, чи хочете ви повторити цю конкретну поведінку чи ні. По-перше, образ Cloudbees Jenkins уже інсталює Git. Якщо вам не потрібні базар, mercurial або subversion або ви не використовуєте їх, можливо, вам не потрібно їх встановлювати, і ви можете заощадити місце у своєму образі. Для повноти, ось весь Dockerfile:

    FROM buildpack-deps:stretch-curl

        # procps is very common in build systems, and is a reasonably small package
        RUN apt-get update && apt-get install -y --no-install-recommends \
                bzr \
                git \
                mercurial \
                openssh-client \
                subversion \
                \
                procps \
            && rm -rf /var/lib/apt/lists/* 

Давайте перейдемо до наступної залежності в списку. Повернутися до головної сторінки пошуку Dockerhub.

1. Знайдіть buildpack-deps і перейдіть за першим результатом.

2. Перейдіть за першою ланкою, яка є розтягненням-завитком.
    
    FROM debian:jessie

        RUN apt-get update && apt-get install -y --no-install-recommends \
                ca-certificates \
                curl \
                wget \
            && rm -rf /var/lib/apt/lists/*

Дивлячись на це зображення, ми нарешті знайшли останню залежність. Це зображення містить пункт FROM для debian:jsessie, який є ОС. Ми бачимо, що це зображення має просте призначення: встановити ще кілька програм: 

    1. wget
    2. curl
    3. ca-certificates

Це цікаво, тому що наші інші зображення вже встановлюють усі ці елементи. Нам справді не потрібне це зображення в дереві залежностей, оскільки воно не додає жодної цінності.

Зараз ми завершили сканування залежностей для базового образу Jenkins. Ми знайшли деякі речі, на які нам потрібно звернути увагу та скопіювати, а також ми знайшли деякі речі, які нам просто не потрібні, і ми можемо викинути, створюючи наш власний повний Dockerfile. Для запису ось повний ланцюжок залежностей:

    Рекомендация статьї             Будемо використовувати
    
    debian:(versian)                debian:(versian)
    buildpack-deps:stretch-curl     buildpack-deps:buster-curl
    buildpack-deps:stretch-scm      buildpack-deps:buster-scm
    openjdk:jdk-8                   openjdk:jdk-23
    jenkins/jenkins:1.112           jenkins/jenkins:lts
    jenkins-master (our image)      jenkins-master (our image)

# =============== ВІДСТУП ===============

#Сподіваюсь що образ з використанням теоретичної зборки, враховуючи оновлені версії на даний час, будут працювати.

    debian:(versian)
    buildpack-deps:buster-curl
    buildpack-deps:buster-scm
    openjdk:jdk-23
    jenkins/jenkins:lts
    jenkins-master (our image)

# =============== КІНЕЦЬ ===============

Не забувайте: ми обернули образ Дженкінса нашим власним файлом Dockerfile у попередніх уроках, тому нам потрібно пам’ятати це для наступного кроку, а саме створення власного файлу Dockerfile. 