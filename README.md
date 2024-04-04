# JenkinsDocker

# L3: Docker & Jenkins дані, які зберігаються.

# ПІДГОТОВКА ТОМА ДАНИХ

У нас є дві речі, які ми потенційно хочемо зберегти незалежно від того, запускається чи зупиняється наша програма Jenkins. Файли журналів (які ми раніше розмістили в /var/log/jenkins) і самі дані програми Jenkins (саме там зберігаються завдання, встановлення плагінів, конфігурації тощо).

Створення тому данних:

    docker volume create jenkins-data
    docker volume create jenkins-log

Список усіх томів:

    docker volume ls

Видалення томів:

    docker volume rm (назва тому)

Томи даних, які більше не мають власників (контейнери), їх можна видалити за допомогою:

    docker volume prune

# ВИКОРИСТАННЯ ДАНИХ ТА ОБ'ЄМІВ ЖУРНАЛУ

Ми збираємося вказати томи як точки монтування та цілі в нашій команді запуску докера. Ми візьмемо кожен том, який ми створили, і розмістимо його в тому місці каталогу, де ми хочемо, щоб він існував у нашому контейнері. Для розташування нашого журналу скористаємося /var/log/jenkins.

    docker run -p 8080:8080 -p 50000:50000 --name=jenkins-master --mount 
    source=jenkins-log,target=/var/log/jenkins -d myjenkins

Docker досить розумний, щоб застосувати дозволи на читання/запис цільових каталогів, які ми призначили в нашому Dockerfile, коли він монтується в тому. Ви можете переконатися, що все досі працює, повторивши файл журналу: 

    docker exec jenkins-master tail -f /var/log/jenkins/jenkins.log
    docker exec jenkins-master cat /var/log/jenkins/jenkins.log

Дженкінс тепер може аварійно завершувати роботу або бути оновлений, і ми завжди матимемо старий журнал. Звичайно, це означає, що ви повинні очистити цей журнал і каталог журналів, як вважаєте за потрібне, так само, як і на звичайному хості Jenkins.

Не забудьте про docker cp . Якщо у вас є дані в тому, який ви хочете скопіювати, але ви втратили контейнер, який їх монтує, ви можете використовувати будь-який контейнер, щоб монтувати том і скопіювати дані.

    docker run -d --name mylogcopy --mount source=jenkins-log,target=/var/log/jenkins debian:stretch
    docker cp mylogcopy:/var/log/jenkins/jenkins.log jenkins.log

Збереження даних журналу є лише незначною перевагою — ми справді зробили це, щоб зберегти ключові дані Jenkins, такі як плагіни та завдання, між перезавантаженнями контейнера. Використання файлу журналу було простим способом продемонструвати, як все працює.

# РЯТУВАННЯ ДОМУ ДЖЕНКІНСА

Перш ніж ми збережемо наші дані Jenkins, є одна неприємність із зображенням Docker Cloudbee за замовчуванням. Він зберігає нестиснений військовий файл Jenkins у jenkins_home, що означає, що ми зберігаємо ці дані між запусками Jenkins. Це не ідеально, оскільки нам не потрібно зберігати ці дані, і це може спричинити плутанину під час переходу між версіями Jenkins. Отже, давайте використаємо інший параметр запуску Jenkins, щоб перемістити його в /var/cache/jenkins

    ENV JENKINS_OPTS="--handlerCountMax=300 --logfile=/var/log/jenkins/jenkins.log --webroot=/var/cache/jenkins/war"

# ТЕСТУВАННЯ ПОСТІЙКИХ ЗАВДАНЬ ТА КОНФІГУРАЦІЇ МІЖ ЗАПУСКАМИ

    Спрямуйте свій браузер на: http://localhost:8080
    Ви повинні побачити екран налаштування Дженкінса «перша інсталяція».
    Введіть пароль адміністратора, створений для вас у журналі Jenkins
    a. Не пам'ятаєте, як це отримати? Використовуйте Docker!
    Наразі виберіть «встановити запропоновані плагіни».
    Зачекайте, поки встановляться всі плагіни, а потім створіть користувача адміністратора (ви можете продовжувати використовувати пароль, який у вас є, якщо хочете, або створити нового користувача)
    Перейшовши на цільову сторінку Jenkins, створіть нову роботу, натиснувши New Item
    Введіть testjob для назви елемента
    Виберіть програмний проект Freestyle
    Натисніть OK
    Натисніть зберегти

Коли jenkins-master видаляється тут, томи jenkins-log і jenkins-data все ще посилаються на віртуальну файлову систему. Якщо ми хочемо, щоб дані зникли, нам доведеться примусово видалити томи за допомогою команди docker volume rm.

    docker run -p 8081:8080 -p 49999:50000 --name jenkins-docker --mount source=jenkins-log,target=/var/log/jenkins --mount source=jenkins-data,target=/var/jenkins_home -d myjenkins:lts-jdk17

Після входу в систему ми побачимо, що наше тестове завдання все ще є. Місію виконано! 

# ВИСНОВКИ

Підчас виконання L3 було виявлено що контейнер який створений завдяки Dockerfile запускався і зразу завершував роботу, довгий час не було зрозуміло в чому є проблема. Завдяки log-файлу контейнера в docker #docker logs (назва контейнера), стало зрозуміло де щукати цю проблему. ENV JENKINS_OPTS="--handlerCountMax=300..." саме тут була проблема, після видалення частини строки (--handlerCountMax=300) контейнер запрацював у штатному режиму що дозволило пройни L3 без проблем.

Робоча версія Dockerfile #8