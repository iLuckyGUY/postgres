# PostgreSQL 19 в Portainer

Стек для **Docker Standalone** в Portainer. Используется стабильный официальный образ PostgreSQL 19.0 на Debian Trixie. Для новой базы Compose создаёт том `<имя-стека>_postgres_data`. Настройки тома рассчитаны на PostgreSQL 18 и новее. [Образ PostgreSQL](https://hub.docker.com/_/postgres) · [Поддерживаемые версии](https://www.postgresql.org/support/versioning/)

## Деплой

1. Выберите нужное окружение Docker в Portainer. Откройте **Stacks → Add stack → Git Repository**.
2. Выберите этот репозиторий, ветку `refs/heads/main` и путь `docker-compose.yml`. Для обновлений по вашему решению оставьте **GitOps updates** выключенным.
3. В **Environment variables** задайте `POSTGRES_PASSWORD` и нужные параметры из [.env.example](.env.example). Можно загрузить приватный env-файл через **Load variables from .env file**. При подготовке локальной копии шаблона ограничьте права до `0600` и храните её вне Git. Пароль доступен администраторам Portainer и Docker.
4. Нажмите **Deploy the stack**. Дождитесь статуса `healthy` и проверьте подключение клиента.

[Документация Portainer](https://docs.portainer.io/user/docker/stacks/add)

## Подключение

Хостовый порт `PGBIND_PORT` по умолчанию равен `5434` и слушает только `127.0.0.1`. Для такого ограничения используйте Docker Engine 28.0.0 или новее. С другой машины подключайтесь через SSH-туннель. [Публикация портов Docker](https://docs.docker.com/engine/network/port-publishing/)

Для приложений на том же Docker-хосте укажите имя существующей bridge-сети в `POSTGRES_NETWORK` и задайте `POSTGRES_NETWORK_EXTERNAL=true`. Подключите к этой сети нужные сервисы приложений. Адрес базы внутри сети — `postgres:5432`. Используйте отдельные роли с минимальными правами для каждого приложения.

## Данные и откат

Новый том создаёт отдельный кластер. Перед заменой существующего стека проверьте его источник данных и версию `PG_VERSION`. Если нужно перенести данные с предыдущей major-версии, сделайте и проверьте резервную копию, затем восстановите её в новый том по процедуре миграции PostgreSQL.

Для резервной копии используйте `pg_dump -Fc` для каждой базы и `pg_dumpall --globals-only` для ролей. Храните копии вне Docker-хоста. Перед обновлением образа зафиксируйте его версию и имя тома. Для отката после несовместимого изменения восстановите проверенную копию в отдельный том на исходной версии PostgreSQL. [Резервное копирование и восстановление](https://www.postgresql.org/docs/19/backup.html)

`POSTGRES_USER`, `POSTGRES_PASSWORD` и `POSTGRES_DB` задают начальные параметры на пустом томе. Для смены пароля действующей роли используйте `\\password` в `psql` и обновите настройки клиентов.
