# 3x-ui Docker

Docker-стек для панели 3x-ui с nginx (stream-мастер «всё через 443») и certbot (Let's Encrypt).

## Структура

```
├── install.sh                   # Интерактивная установка с GitHub
├── docker-compose.yml          # Основной файл стека
├── inbound-xray.sh             # Скрипт настройки Xray-инбаундов (на хосте)
├── docker/
│   ├── nginx/Dockerfile        # nginx:stable + nginx-full + stream
│   ├── nginx/entrypoint.sh     # Ожидание 3x-ui перед стартом
│   └── .env.example            # Шаблон переменных
├── db/                         # БД панели (volume)
├── cert/                       # Сертификаты (volume)
├── nginx/                      # Конфиги nginx (volume)
├── letsencrypt/                # LE сертификаты (volume)
└── var/www/landing/            # HTML-заглушка
```

## Быстрый старт

### Автоматическая установка (рекомендуется)

```bash
curl -sSL https://raw.githubusercontent.com/aplesovskih/3x-ui-docker/main/install.sh | bash
```

Скрипт интерактивно запросит IP, домен и порты, создаст `.env` и запустит стек.

### Ручная установка

1. Скопировать и заполнить переменные:
   ```bash
   cp docker/.env.example .env
   nano .env
   ```

2. Запустить стек:
   ```bash
   docker compose -f docker/docker-compose.yml up -d
   ```

3. Проверить:
   ```bash
   docker compose -f docker/docker-compose.yml ps
   docker compose -f docker/docker-compose.yml logs nginx
   ```

4. Настроить инбаунды:
   ```bash
   bash inbound-xray.sh
   ```

## Архитектура

```
Интернет :443
    │
    ▼
┌──────────────────────────────────────┐
│  docker network: proxy-net (bridge)  │
│                                      │
│  ┌─────────┐    ┌────────────────┐   │
│  │  nginx   │───▶│  3x-ui (xray)  │   │
│  │  :443    │    │  :10000+       │   │
│  │  :8443   │    │  :45212 (panel)│   │
│  └────┬─────┘    └────────────────┘   │
│       │                               │
│  ┌────┴─────┐                         │
│  │ certbot   │                        │
│  └──────────┘                         │
└──────────────────────────────────────┘
```

- **nginx**: stream-мастер (ssl_preread + proxy_protocol), маршрутизация по SNI
- **3x-ui**: панель + xray, инбаунды слушают на 0.0.0.0 (доступны из nginx)
- **certbot**: обновление сертификатов Let's Encrypt

## Управление

```bash
# Старт
docker compose -f docker/docker-compose.yml up -d

# Логи
docker compose -f docker/docker-compose.yml logs -f nginx
docker compose -f docker/docker-compose.yml logs -f 3xui

# Перезапуск
docker compose -f docker/docker-compose.yml restart

# Остановка
docker compose -f docker/docker-compose.yml down

# Обновление образов
docker compose -f docker/docker-compose.yml pull
docker compose -f docker/docker-compose.yml up -d
```

## inbound-xray.sh

Скрипт работает на хосте и автоматически определяет Docker-режим по наличию `docker/docker-compose.yml`. В Docker-режиме:

- xray слушает на `0.0.0.0` (доступен из nginx через bridge-сеть)
- nginx-конфиги пишутся в смонтированные volume'ы
- Перезапуск панели: `docker compose restart 3x-ui`
- Валидация nginx: `docker compose exec nginx nginx -t`
- Firewall не управляется (порты через docker-compose.yml)

## Порты

| Порт | Сервис | Назначение |
|------|--------|------------|
| 443 | nginx | Stream-мастер (все TLS-потоки) |
| 80 | nginx | Certbot HTTP-01 challenge |

Порты инбаундов (10000+) НЕ публикуются — трафик идёт через nginx :443.

## Сертификаты

LE-сертификаты обновляются через certbot-контейнер:

```bash
docker compose -f docker/docker-compose.yml run --rm certbot renew
docker compose -f docker/docker-compose.yml exec nginx nginx -s reload
```
