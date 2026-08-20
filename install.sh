#!/usr/bin/env bash
# =============================================================================
# install.sh — интерактивная установка 3x-ui Docker Stack с GitHub
#
# Использование:
#   curl -sSL https://raw.githubusercontent.com/aplesovskih/3x-ui-docker/main/install.sh | bash
#   или
#   bash install.sh
# =============================================================================
set -euo pipefail

# --- Цвета ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }

# --- Интерактивный read (работает при curl | bash) ---
ask() {
    local var="$1" prompt="$2" default="$3"
    local val
    read -rp "$prompt [$default]: " val </dev/tty
    echo "${val:-$default}"
}

# --- Проверка root ---
if [[ $EUID -ne 0 ]]; then
    error "Запустите от root:"
    echo "  curl -sSL https://raw.githubusercontent.com/aplesovskih/3x-ui-docker/main/install.sh | sudo bash"
    exit 1
fi

REPO_URL="https://github.com/aplesovskih/3x-ui-docker.git"
DEFAULT_DIR="/opt/3x-ui-docker"

# --- Проверка/установка Docker ---
if ! command -v docker >/dev/null 2>&1; then
    info "Docker не найден. Устанавливаю..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker >/dev/null 2>&1 && systemctl start docker
    ok "Docker установлен: $(docker --version)"
else
    ok "Docker: $(docker --version)"
fi

if ! docker compose version >/dev/null 2>&1; then
    error "Docker Compose V2 не найден. Обновите Docker до последней версии."
    exit 1
fi
ok "Docker Compose: $(docker compose version --short)"

# --- Клонирование / обновление репозитория ---
PROJECT_DIR=$(ask PROJECT_DIR "Куда установить" "$DEFAULT_DIR")

if [[ -d "$PROJECT_DIR/.git" ]]; then
    info "Репозиторий уже существует — обновляю..."
    git -C "$PROJECT_DIR" pull --ff-only || {
        warn "git pull не удался. Попробуйте вручную: cd $PROJECT_DIR && git pull"
    }
else
    info "Клонирую репозиторий в $PROJECT_DIR..."
    git clone "$REPO_URL" "$PROJECT_DIR"
fi
cd "$PROJECT_DIR"

# --- Интерактивный ввод переменных ---
echo ""
echo "=== Настройка переменных ==="
echo ""

SERVER_IP=$(ask SERVER_IP "IP-адрес сервера" "")
if [[ -z "$SERVER_IP" ]]; then
    info "Определяю IP автоматически..."
    SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
    if [[ -n "$SERVER_IP" ]]; then
        ok "Определён IP: $SERVER_IP"
    else
        warn "Не удалось определить IP. Укажите позже в .env"
    fi
fi

PANEL_HOST=$(ask PANEL_HOST "Домен панели" "")
PANEL_PORT=$(ask PANEL_PORT "Порт панели 3x-ui" "45212")
STREAM_MASTER_PORT=$(ask STREAM_MASTER_PORT "Порт stream-мастера nginx" "443")
CERTBOT_EMAIL=$(ask CERTBOT_EMAIL "E-mail для Let's Encrypt" "")

# --- Запись .env ---
cat > .env <<EOF
# Автоматически создано install.sh — $(date -Iseconds)
SERVER_IP=${SERVER_IP}
PANEL_HOST=${PANEL_HOST}
PANEL_PORT=${PANEL_PORT}
STREAM_MASTER_PORT=${STREAM_MASTER_PORT}
CERTBOT_EMAIL=${CERTBOT_EMAIL}
PROJECT_DIR=${PROJECT_DIR}
EOF
ok ".env создан: $PROJECT_DIR/.env"

# --- Создание каталогов ---
info "Создаю каталоги..."
for d in db cert letsencrypt nginx/shm var/www/landing; do
    mkdir -p "$d"
done
ok "Каталоги готовы"

# --- Запуск стека ---
echo ""
info "Собираю и запускаю docker compose..."
docker compose -f docker/docker-compose.yml up -d --build

# --- Проверка статуса ---
echo ""
info "Проверяю статус контейнеров..."
sleep 3
docker compose -f docker/docker-compose.yml ps

# --- Итоги ---
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  3x-ui Docker Stack успешно установлен!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
if [[ -n "$SERVER_IP" ]]; then
    echo -e "  Панель: ${BLUE}http://${SERVER_IP}:${PANEL_PORT}${NC}"
fi
if [[ -n "$PANEL_HOST" ]]; then
    echo -e "  Домен:  ${BLUE}https://${PANEL_HOST}${NC}"
fi
echo ""
echo "  Следующие шаги:"
echo "    1. Откройте панель в браузере"
echo "    2. Залогиньтесь (admin / admin)"
echo "    3. Запустите настройку инбаундов:"
echo ""
echo -e "       ${BLUE}cd $PROJECT_DIR && bash inbound-xray.sh${NC}"
echo ""
