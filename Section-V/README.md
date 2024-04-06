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

# =============== -1- ===============

#На момент читання статьї (06.04.24) тег openjbk занадто сильно змінився, вподальшому потрібно враховувати всі залежності які змінили версії своїх публікаций.

    23-ea-17-jdk-oraclelinux9, 23-ea-17-oraclelinux9, 23-ea-jdk-oraclelinux9, 23-ea-oraclelinux9, 23-jdk-oraclelinux9, 23-oraclelinux9, 23-ea-17-jdk-oracle, 23-ea-17-oracle, 23-ea-jdk-oracle, 23-ea-oracle, 23-jdk-oracle, 23-oracle

# =============== -1- ===============

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

# =============== -2- ===============

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

# =============== -2- ===============

3. Цей Dockerfile короткий і приємний. Ми бачимо ще один файл Docker у ланцюжку залежностей під назвою buildpack-deps:stretch-curl. Але крім цього, цей Dockerfile лише встановлює шість речей.

    1. bzr
    2. git
    3. mercurial
    4. openssh-client
    5. subversion
    6. procps
    
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

# =============== -3- ===============

#Сподіваюсь що образ з використанням теоретичної зборки, враховуючи оновлені версії на даний час, будут працювати.

    debian:(versian)
    buildpack-deps:buster-curl
    buildpack-deps:buster-scm
    openjdk:jdk-23
    jenkins/jenkins:lts
    jenkins-master (our image)

# =============== -3- ===============

Не забувайте: ми обернули образ Дженкінса нашим власним файлом Dockerfile у попередніх уроках, тому нам потрібно пам’ятати це для наступного кроку, а саме створення власного файлу Dockerfile. 

# СТВОРЕННЯ ВЛАСНОГО DOCKERFILE

Завдяки всім дослідженням залежностей ми тепер можемо створити власний Dockerfile. Найпростішим способом було б просто вирізати та вставити все разом і пропустити пропозиції FROM. Це спрацювало б, але також створило б деякі зайві команди та дурниці. Ми можемо оптимізувати розмір зображення, видаливши деякі речі, які нам, можливо, не потрібні. 

Ми підтвердили, що весь ланцюжок зображень створено на основі Debian, і в цьому підручнику я розповім, як контролювати це налаштування. Наприкінці я надам посилання на альтернативу, створену на основі CentOS7, якій я віддаю перевагу через глибоке знайомство з цією ОС завдяки всій роботі, яку ми робимо з нею в Riot. Будь-яка ОС чудова, а потужність Docker полягає в тому, що ви можете вибрати для своїх контейнерів все, що завгодно. 

Отже, давайте почнемо створювати повністю оновлений образ jenkins-master. Для запису, ось файл Docker для jenkins-master, який ми маємо на даний момент (якщо ви дотримувались усіх підручників): 
#(Нижче наведений приклад мого файлу)

    FROM jenkins/jenkins:lts-jdk17
    LABEL maintainer="out.quito@outlook.com"

    USER root

    RUN mkdir /var/log/jenkins
    RUN mkdir /var/cache/jenkins
    RUN chown -R jenkins:jenkins /var/log/jenkins 
    RUN chown -R jenkins:jenkins /var/cache/jenkins

    USER jenkins

    ENV JAVA_OPTS="-Xmx8192m"
    ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log --webroot=/var/cache/jenkins/war"

Крок перший: давайте змінимо пункт FROM на Debian:

1. Відкрийте файл jenkins-master/Docker

2. Замініть речення from на: FROM debian:stretch.

Наступний крок: ми повинні встановити всі наші програми за допомогою apt-get. Давайте створимо новий розділ у верхній частині Dockerfile після LABEL, але перед розділом USER, і додамо наступне: 

    FROM debian:stretch
    LABEL maintainer="out.quito@outlook.com"

    ENV LANG C.UTF-8
    ENV JAVA_VERSION 8u212
    ENV JAVA_DEBIAN_VERSION 8u212-b01-1~deb9u1
    ENV CA_CERTIFICATES_JAVA_VERSION 20170531+nmu1

    RUN apt-get update \
        && apt-get install -y --no-install-recommends \
        wget \
        curl \
        ca-certificates \
        zip \
        openssh-client \
        unzip \
        openjdk-8-jdk="${JAVA_DEBIAN_VERSION}" \
        ca-certificates-java="${CA_CERTIFICATES_JAVA_VERSION} \
        && rm -rf /var/lib/apt/lists/*

    RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure
    RUN mkdir /var/log/jenkins
    RUN mkdir /var/cache/jenkins
    RUN chown -R jenkins:jenkins /var/log/jenkins 
    RUN chown -R jenkins:jenkins /var/cache/jenkins

    USER jenkins

    ENV JAVA_OPTS="-Xmx8192m"
    ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log --webroot=/var/cache/jenkins/war"

Це багато речей! Ви помітите, що я об’єднав інсталяції apt-get з усіх файлів Dockerfiles, які ми розглядали, в один набір. Для цього мені довелося спочатку встановити всі необхідні змінні середовища, які використовуються для версій і сертифікатів Java. Я б рекомендував перевірити, чи все встановлюється, перш ніж продовжувати додавати інші матеріали до Dockerfile. 

    docker build jenkins-master/

# =============== -4- ===============

#ПОМИЛКА №1

    => ERROR [2/7] RUN apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-8-jdk="8u212-b  2.7s
    ------
    > [2/7] RUN apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-8-jdk="8u212-b01-1~deb9u1"     ca-certificates-java="20170531+nmu1"     && rm -rf /var/lib/apt/lists/*:
    0.492 Ign:1 http://security.debian.org/debian-security stretch/updates InRelease
    0.530 Ign:2 http://deb.debian.org/debian stretch InRelease
    0.552 Ign:3 http://security.debian.org/debian-security stretch/updates Release
    0.594 Ign:4 http://deb.debian.org/debian stretch-updates InRelease
    0.611 Ign:5 http://security.debian.org/debian-security stretch/updates/main amd64 Packages
    0.664 Ign:6 http://deb.debian.org/debian stretch Release
    0.675 Ign:7 http://security.debian.org/debian-security stretch/updates/main all Packages
    0.736 Ign:8 http://deb.debian.org/debian stretch-updates Release
    0.736 Ign:5 http://security.debian.org/debian-security stretch/updates/main amd64 Packages
    0.807 Ign:7 http://security.debian.org/debian-security stretch/updates/main all Packages
    0.814 Ign:9 http://deb.debian.org/debian stretch/main all Packages
    0.873 Ign:5 http://security.debian.org/debian-security stretch/updates/main amd64 Packages
    0.890 Ign:10 http://deb.debian.org/debian stretch/main amd64 Packages
    0.945 Ign:7 http://security.debian.org/debian-security stretch/updates/main all Packages
    0.960 Ign:11 http://deb.debian.org/debian stretch-updates/main all Packages
    1.002 Ign:5 http://security.debian.org/debian-security stretch/updates/main amd64 Packages
    1.037 Ign:12 http://deb.debian.org/debian stretch-updates/main amd64 Packages
    1.060 Ign:7 http://security.debian.org/debian-security stretch/updates/main all Packages
    1.115 Ign:9 http://deb.debian.org/debian stretch/main all Packages
    1.120 Ign:5 http://security.debian.org/debian-security stretch/updates/main amd64 Packages
    1.179 Ign:7 http://security.debian.org/debian-security stretch/updates/main all Packages
    1.198 Ign:10 http://deb.debian.org/debian stretch/main amd64 Packages
    1.238 Err:5 http://security.debian.org/debian-security stretch/updates/main amd64 Packages
    1.238   404  Not Found [IP: 151.101.66.132 80]
    1.281 Ign:11 http://deb.debian.org/debian stretch-updates/main all Packages
    1.311 Ign:7 http://security.debian.org/debian-security stretch/updates/main all Packages
    1.356 Ign:12 http://deb.debian.org/debian stretch-updates/main amd64 Packages
    1.430 Ign:9 http://deb.debian.org/debian stretch/main all Packages
    1.496 Ign:10 http://deb.debian.org/debian stretch/main amd64 Packages
    1.563 Ign:11 http://deb.debian.org/debian stretch-updates/main all Packages
    1.647 Ign:12 http://deb.debian.org/debian stretch-updates/main amd64 Packages
    1.722 Ign:9 http://deb.debian.org/debian stretch/main all Packages
    1.787 Ign:10 http://deb.debian.org/debian stretch/main amd64 Packages
    1.853 Ign:11 http://deb.debian.org/debian stretch-updates/main all Packages
    1.918 Ign:12 http://deb.debian.org/debian stretch-updates/main amd64 Packages
    1.992 Ign:9 http://deb.debian.org/debian stretch/main all Packages
    2.081 Ign:10 http://deb.debian.org/debian stretch/main amd64 Packages
    2.169 Ign:11 http://deb.debian.org/debian stretch-updates/main all Packages
    2.264 Ign:12 http://deb.debian.org/debian stretch-updates/main amd64 Packages
    2.340 Ign:9 http://deb.debian.org/debian stretch/main all Packages
    2.480 Err:10 http://deb.debian.org/debian stretch/main amd64 Packages
    2.480   404  Not Found [IP: 199.232.18.132 80]
    2.548 Ign:11 http://deb.debian.org/debian stretch-updates/main all Packages
    2.641 Err:12 http://deb.debian.org/debian stretch-updates/main amd64 Packages
    2.641   404  Not Found [IP: 199.232.18.132 80]
    2.645 Reading package lists...
    2.656 W: The repository 'http://security.debian.org/debian-security stretch/updates Release' does not have a Release file.
    2.656 W: The repository 'http://deb.debian.org/debian stretch Release' does not have a Release file.
    2.656 W: The repository 'http://deb.debian.org/debian stretch-updates Release' does not have a Release file.
    2.656 E: Failed to fetch http://security.debian.org/debian-security/dists/stretch/updates/main/binary-amd64/Packages  404  Not Found [IP: 151.101.66.132 80]
    2.656 E: Failed to fetch http://deb.debian.org/debian/dists/stretch/main/binary-amd64/Packages  404  Not Found [IP: 199.232.18.132 80]
    2.656 E: Failed to fetch http://deb.debian.org/debian/dists/stretch-updates/main/binary-amd64/Packages  404  Not Found [IP: 199.232.18.132 80]
    2.656 E: Some index files failed to download. They have been ignored, or old ones used instead.
    ------
    Dockerfile:9
    --------------------
    8 |     
    9 | >>> RUN apt-get update \
    10 | >>>     && apt-get install -y --no-install-recommends \
    11 | >>>     wget \
    12 | >>>     curl \
    13 | >>>     ca-certificates \
    14 | >>>     zip \
    15 | >>>     openssh-client \
    16 | >>>     unzip \
    17 | >>>     openjdk-8-jdk="${JAVA_DEBIAN_VERSION}" \
    18 | >>>     ca-certificates-java="${CA_CERTIFICATES_JAVA_VERSION}" \
    19 | >>>     && rm -rf /var/lib/apt/lists/*
    20 |     
    --------------------
    ERROR: failed to solve: process "/bin/sh -c apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-8-jdk=\"${JAVA_DEBIAN_VERSION}\"     ca-certificates-java=\"${CA_CERTIFICATES_JAVA_VERSION}\"     && rm -rf /var/lib/apt/lists/*" did not complete successfully: exit code: 100

Ця помилка виникає через недоступність деяких репозиторіїв. Здається? намагаємся оновити пакунки з репозиторіїв Debian Stretch, але ці репозиторії більше не підтримуються, оскільки Stretch вже вийшов з активної підтримки.

Рекомендується змінити версію Debian на більш нову, таку як Debian Buster або Debian Bullseye, щоб отримати доступ до оновлених репозиторіїв.

Ось приклад Dockerfile з використанням Debian Buster: 

    FROM debian:buster

    RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        curl \
        ca-certificates \
        zip \
        openssh-client \
        unzip \
        openjdk-8-jdk="${JAVA_DEBIAN_VERSION}" \
        ca-certificates-java="${CA_CERTIFICATES_JAVA_VERSION}" \
        && rm -rf /var/lib/apt/lists/*

#ПОМИЛКА №2

    => ERROR [2/7] RUN apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-8-jdk="8u212-b  7.8s
    ------
    > [2/7] RUN apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-8-jdk="8u212-b01-1~deb9u1"     ca-certificates-java="20170531+nmu1"     && rm -rf /var/lib/apt/lists/*:
    0.618 Get:1 http://deb.debian.org/debian buster InRelease [122 kB]
    0.841 Get:2 http://deb.debian.org/debian-security buster/updates InRelease [34.8 kB]
    0.937 Get:3 http://deb.debian.org/debian buster-updates InRelease [56.6 kB]
    1.036 Get:4 http://deb.debian.org/debian buster/main amd64 Packages [7909 kB]
    3.632 Get:5 http://deb.debian.org/debian-security buster/updates/main amd64 Packages [592 kB]
    3.741 Get:6 http://deb.debian.org/debian buster-updates/main amd64 Packages [8788 B]
    5.013 Fetched 8723 kB in 5s (1856 kB/s)
    5.013 Reading package lists...
    5.790 Reading package lists...
    6.537 Building dependency tree...
    6.674 Reading state information...
    6.788 E: Unable to locate package openjdk-8-jdk
    6.788 E: Version '20170531+nmu1' for 'ca-certificates-java' was not found
    ------
    Dockerfile:9
    --------------------
    8 |     
    9 | >>> RUN apt-get update \
    10 | >>>     && apt-get install -y --no-install-recommends \
    11 | >>>     wget \
    12 | >>>     curl \
    13 | >>>     ca-certificates \
    14 | >>>     zip \
    15 | >>>     openssh-client \
    16 | >>>     unzip \
    17 | >>>     openjdk-8-jdk="${JAVA_DEBIAN_VERSION}" \
    18 | >>>     ca-certificates-java="${CA_CERTIFICATES_JAVA_VERSION}" \
    19 | >>>     && rm -rf /var/lib/apt/lists/*
    20 |     
    --------------------
    ERROR: failed to solve: process "/bin/sh -c apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-8-jdk=\"${JAVA_DEBIAN_VERSION}\"     ca-certificates-java=\"${CA_CERTIFICATES_JAVA_VERSION}\"     && rm -rf /var/lib/apt/lists/*" did not complete successfully: exit code: 100

Ця помилка виникає через те, що пакунок  openjdk-8-jdk відсутній у репозиторіях Debian Buster. Debian Buster за замовчуванням має openjdk-11-jdk, а не openjdk-8-jdk. 

Ось приклад Dockerfile з додаванням репозиторію  contrib для встановлення openjdk-8-jdk:

    FROM debian:buster

    RUN apt-get update \
        && apt-get install -y --no-install-recommends \
        wget \
        curl \
        ca-certificates \
        zip \
        openssh-client \
        unzip \
        openjdk-11-jdk="${JAVA_DEBIAN_VERSION}" \
        ca-certificates-java="${CA_CERTIFICATES_JAVA_VERSION}" \
        && rm -rf /var/lib/apt/lists/*

У цьому Dockerfile встановлюється openjdk-11-jdk з версією, вказаною у змінній  "JAVA_DEBIAN_VERSION", а також ca-certificates-java з версією, вказаною у змінній "CA_CERTIFICATES_JAVA_VERSION". 

#ПОМИЛКА №3

    => ERROR [2/7] RUN apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-c  12.1s
    ------                                                                                                                 
    > [2/7] RUN apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-11-jdk="8u212-b01-1~deb9u1"     ca-certificates-java="20170531+nmu1"     && rm -rf /var/lib/apt/lists/*:
    0.640 Get:1 http://deb.debian.org/debian buster InRelease [122 kB]                                                     
    0.822 Get:2 http://deb.debian.org/debian-security buster/updates InRelease [34.8 kB]                                   
    0.927 Get:3 http://deb.debian.org/debian buster-updates InRelease [56.6 kB]
    1.022 Get:4 http://deb.debian.org/debian buster/main amd64 Packages [7909 kB]
    8.865 Get:5 http://deb.debian.org/debian-security buster/updates/main amd64 Packages [592 kB]
    9.327 Get:6 http://deb.debian.org/debian buster-updates/main amd64 Packages [8788 B]
    10.22 Fetched 8723 kB in 10s (891 kB/s)
    10.22 Reading package lists...
    10.98 Reading package lists...
    11.71 Building dependency tree...
    11.85 Reading state information...
    11.96 E: Version '8u212-b01-1~deb9u1' for 'openjdk-11-jdk' was not found
    11.96 E: Version '20170531+nmu1' for 'ca-certificates-java' was not found
    ------
    Dockerfile:9
    --------------------
    8 |     
    9 | >>> RUN apt-get update \
    10 | >>>     && apt-get install -y --no-install-recommends \
    11 | >>>     wget \
    12 | >>>     curl \
    13 | >>>     ca-certificates \
    14 | >>>     zip \
    15 | >>>     openssh-client \
    16 | >>>     unzip \
    17 | >>>     openjdk-11-jdk="${JAVA_DEBIAN_VERSION}" \
    18 | >>>     ca-certificates-java="${CA_CERTIFICATES_JAVA_VERSION}" \
    19 | >>>     && rm -rf /var/lib/apt/lists/*
    20 |     
    --------------------
    ERROR: failed to solve: process "/bin/sh -c apt-get update     && apt-get install -y --no-install-recommends     wget     curl     ca-certificates     zip     openssh-client     unzip     openjdk-11-jdk=\"${JAVA_DEBIAN_VERSION}\"     ca-certificates-java=\"${CA_CERTIFICATES_JAVA_VERSION}\"     && rm -rf /var/lib/apt/lists/*" did not complete successfully: exit code: 100

Я намагаєтеся встановити openjdk-11-jdk і ca-certificates-java з версіями, які призначені для Debian 9 (stretch), але я використовую образ Debian Buster. Це призводить до помилки, оскільки не можна знайти вказані версії пакунків у репозиторіях Debian Buster.

Щоб виправити цю помилку, видаляю вказані версії пакунків та просто встановлюю openjdk-11-jdk та ca-certificates-java з репозиторіїв за замовчуванням Debian Buster. Ось оновлений варіант Dockerfile:

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

У цьому Dockerfile я видалив змінні JAVA_VERSION,  JAVA_DEBIAN_VERSION і CA_CERTIFICATES_JAVA_VERSION, оскільки вони більше не потрібні. Просто встановлюєте пакунки openjdk-11-jdk та ca-certificates-java без вказування конкретних версій, і Docker вибере найновіші версії з репозиторіїв Debian Buster. 

# =============== -4- ===============

Ми просто перевіряємо, чи все правильно встановлюється, тому це зображення можна викинути. Можливо, ви отримаєте повідомлення про помилку про зниклого користувача Jenkins – це нормально. Оскільки ми змінили базовий образ на ОС Debian, ми видалили (наразі) образ Jenkins, який створював цього користувача. 

Треба багато пройти, тому я буду робити крок за кроком. Спочатку давайте налаштуємо всі наші аргументи збірки та будь-які змінні середовища, які ми можемо. Ми також можемо зберегти поведінку аргументу збірки з образу Cloudbees, оскільки це може бути зручно, якщо ми хочемо використовувати його. Після встановлення та налаштування сертифікатів apt-get додайте такі рядки: 

    ARG user=jenkins
    ARG group=jenkins
    ARG uid=1000
    ARG gid=1000
    ARG http_port=8080
    ARG agent_port=50000
    ARG JENKINS_VERSION=2.112
    ARG TINI_VERSION=v0.17.0

    # jenkins.war checksum, download will be validated using it
    ARG JENKINS_SHA=085f597edeb0d49d54d7653f3742ba31ed72b8a1a2b053d2eb23fd806c6a5393

    # Can be used to customize where jenkins.war get downloaded from
    ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

    ENV JENKINS_VERSION ${JENKINS_VERSION}
    ENV JENKINS_HOME /var/jenkins_home
    ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
    ENV JENKINS_UC https://updates.jenkins.io
    ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
    ENV JAVA_OPTS="-Xmx8192m"
    ENV JENKINS_OPTS="--handlerCountMax=300 --logfile=/var/log/jenkins/jenkins.log  --webroot=/var/cache/jenkins/war"
    ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# =============== -5- ===============

#Я враховував всі зміни версій на теперешній час, звичайно будуть помилки, но як кажуть "Вирішуємо помилки по мірі їх надходження":

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
    ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# =============== -5- ===============

Це досить великий список аргументів і змінних середовища. Я зібрав усе це разом, прочитавши Cloudbees Jenkins Dockerfile. Мені подобається мати якомога більше таких файлів в одному місці в моїх файлах Docker. Основні речі, на які варто звернути увагу: 


    Версія jenkins контролюється аргументом під назвою JENKINS_VERSION, а його SHA відповідності — JENKINS_SHA.

    Змінити версію Jenkins можна за допомогою редагування Dockerfile і перебудови або передачі параметра аргументу build.

    Я змінив аргумент JENKINS_VERSION, щоб мати значення за замовчуванням (порівняно з оригіналом Cloudbees), і я оновив JENKINS_SHA, щоб відповідати.

    Щоб знайти доступні версії та SHA для файлів Jenkins WAR, ви можете перейти тут: http://mirrors.jenkins.io/war/

    Ви побачите, що я включив змінні середовища, такі як JAVA_OPTS і JENKINS_OPTS з наших попередніх файлів тут.

Далі ми повинні встановити Tini. Цікавий факт: Docker має вбудовану підтримку Tini, але для цього потрібно ввімкнути параметр командного рядка: --init. Однак служби Docker і, отже, Docker-compose НЕ підтримують його. Існують обхідні шляхи, але для безпеки я пропоную встановити його так само, як Cloudbees. Якщо ви хочете прочитати більше про це, перегляньте цю проблему github . Зауважте, що я встановлюю Tini дещо інакше, ніж Cloudbees, частково, щоб отримати останню версію, а частково, щоб пропустити перевірку ключа GPG. За бажанням ви можете знову додати перевірку ключа GPG. Повний посібник зі встановлення Tini доступний на github Tini тут . Додайте наступні рядки до вашого Dockerfile відразу після параметрів ENV:

    # Use tini as subreaper in Docker container to adopt zombie processes
    RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
    && chmod +x /sbin/tini

Ви помітите, що версія походить зі списку аргументів, який я вам доручив додати раніше.

Далі я розмістив три записи, необхідні для встановлення Jenkins. Це створює самого користувача Jenkins, створює монтування тому та налаштовує каталог init. 

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

З ними ми можемо запустити команду CURL, щоб отримати потрібний файл jenkins.war. Зауважте, що тут використовується змінна аргументу збірки JENKINS_VERSION, тому, якщо ви захочете змінити це в майбутньому, змініть аргумент збірки за замовчуванням або передайте версію, яку ви хочете використовувати (і відповідність SHA), параметру --build-arg у « збірка докера». 

    #Install Jenkins
    RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
    && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

Далі ми встановлюємо всі права доступу до каталогу та користувача. Вони перенесені з образу jenkins-master, який ми створили в попередніх посібниках, і ми все ще хочемо, щоб вони допомагали краще ізолювати нашу інсталяцію Jenkins. Той, який ми отримуємо з образу Cloudbees, — це каталог jenkins/ref. 

    # Prep Jenkins Directories
    RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref
    RUN mkdir /var/log/jenkins
    RUN mkdir /var/cache/jenkins
    RUN chown -R ${user}:${group} /var/log/jenkins
    RUN chown -R ${user}:${group} /var/cache/jenkins

Не забудьте змінити посилання на аргументи збірки для користувача та групи тепер, коли ми беремо на себе цю відповідальність. Далі ми покажемо порти, які нам потрібні:

    # Expose Ports for web and slave agents
    EXPOSE ${http_port}
    EXPOSE ${agent_port}

Все, що залишилося, це скопіювати службові файли, які Cloudbees містить у своєму образі, встановити користувача Jenkins і запустити команди запуску. Я залишив записи COPY досі згідно з деякими хорошими передовими методами Dockerfile. Вони, ймовірно, зміняться за межами Dockerfile, і якщо вони зміняться, ми не хочемо обов’язково робити недійсним увесь файловий кеш. Ось вони: 

    # Copy in local config files
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

Примітка: поки ми не отримаємо копії цих файлів у наше сховище, вони не працюватимуть, а наш Dockerfile не буде створено. Ми подбаємо про це, коли все перевіримо. Зверніть особливу увагу на те, що я додав команди chmod +x, оскільки це гарантує, що додані файли є виконуваними. Наразі закінчіть установкою користувача Jenkins і точки входу. 

    # Switch to the jenkins user
    USER ${user}

    # Tini as the entry point to manage zombie processes
    ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

Давайте протестуємо всі зміни, які ми щойно внесли під час створення Dockerfile. Пам’ятайте, що ми очікуємо помилок, коли ми дійдемо до команд COPY. 

    docker build jenkins-master/

# =============== -6- ===============

#Так виглядає мій файл перед тестуванням, очикуємо помилки)))

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

    RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
        && chmod +x /sbin/tini
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

    USER ${user}

    ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# =============== -6- ===============

    => ERROR [13/18] COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy
    => ERROR [14/18] COPY jenkins-support /usr/local/bin/jenkins-support
    => ERROR [15/18] COPY plugins.sh /usr/local/bin/plugins.sh
    => ERROR [16/18] COPY jenkins.sh /usr/local/bin/jenkins.sh
    => ERROR [17/18] COPY install-plugins.sh /usr/local/bin/install-plugins.sh    