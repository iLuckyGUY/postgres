# PostgreSQL 19 в Portainer

Стек для **Docker Standalone** в Portainer и Docker Compose. Используется стабильный официальный образ PostgreSQL 19.0 на Debian Trixie. Базовый стек не требует каталогов на Docker-хосте. [Образ PostgreSQL и поддерживаемые архитектуры](https://hub.docker.com/_/postgres)

## Деплой

1. Выберите нужное окружение Docker в Portainer. Откройте **Stacks → Add stack → Git Repository**.
2. Выберите этот репозиторий, ветку `refs/heads/main` и путь `docker-compose.yml`. Для обновлений по вашему решению оставьте **GitOps updates** выключенным.
3. В **Environment variables** загрузите приватный `postgres.env` через **Load variables from .env file**. Список переменных есть в [.env.example](.env.example). `POSTGRES_PASSWORD` обязателен. Ограничьте права локального файла до `0600` и храните его вне Git.
4. Нажмите **Deploy the stack**. Дождитесь статуса `healthy` и проверьте подключение клиента.

[Документация Portainer](https://docs.portainer.io/user/docker/stacks/add)

## Пароль

Значение `POSTGRES_PASSWORD` доступно администраторам Docker через конфигурацию контейнера. `POSTGRES_USER`, `POSTGRES_PASSWORD` и `POSTGRES_DB` задают начальные параметры кластера на пустом томе. Для смены пароля действующей роли используйте `\password` в `psql` и обновите настройки клиентов.

## Подключение

Хостовый порт `PGBIND_PORT` по умолчанию равен `5434` и слушает только `127.0.0.1`. Для такого ограничения используйте Docker Engine 28.0.0 или новее. С другой машины подключайтесь через SSH-туннель. [Публикация портов Docker](https://docs.docker.com/engine/network/port-publishing/)

Для приложений на том же Docker-хосте укажите имя существующей bridge-сети в `POSTGRES_NETWORK` и задайте `POSTGRES_NETWORK_EXTERNAL=true`. Подключите к этой сети нужные сервисы приложений. Адрес базы внутри сети — `postgres:5432`. Используйте отдельные роли с минимальными правами для каждого приложения.

## Том и повторное развёртывание

Compose использует том `postgres_data` на Docker-хосте и создаёт его при первом развёртывании. Имя тома фиксировано, поэтому используйте этот стек для одного экземпляра PostgreSQL на хосте. Имя контейнера `PostgreSQL` должно быть свободно при первом развёртывании. Проверить конфигурацию локально можно командой `docker compose --env-file postgres.env config --quiet`. [Тома Docker](https://docs.docker.com/engine/storage/volumes/)
