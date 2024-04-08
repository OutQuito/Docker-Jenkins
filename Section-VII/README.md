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