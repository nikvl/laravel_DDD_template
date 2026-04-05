#!/usr/bin/env bash

################################################################################
# Laravel API DDD Template Installer
# Автоматическая установка проекта с архитектурой DDD + CQRS + Event Sourcing
#
# Использование:
#   curl -sL https://raw.githubusercontent.com/nikvl/laravel_DDD_template/install.sh | bash -s -- project-name
#   # или
#   bash install.sh project-name
################################################################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка наличия аргумента
if [ -z "$1" ]; then
    log_error "Не указано имя проекта!"
    echo "Использование: bash $0 <project-name>"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/${PROJECT_NAME}"

log_info "Создание проекта: ${PROJECT_NAME}"
log_info "Путь: ${PROJECT_DIR}"

################################################################################
# Проверка .env / .env.example
################################################################################
if [ ! -f ".env" ] && [ ! -f ".env.example" ]; then
    log_info ".env.example не найден, загружаем из репозитория..."
    if ! curl -sL "https://raw.githubusercontent.com/nikvl/laravel_DDD_template/main/.env.example" -o .env.example 2>/dev/null || [ ! -f ".env.example" ]; then
        log_warning "Не удалось загрузить .env.example, создаём с настройками по умолчанию..."
        cat > .env.example << 'ENVEOF'
################################################################################
# Laravel API DDD Template - Environment Configuration
################################################################################

# ─── Application ──────────────────────────────────────────────────────────────
APP_NAME="Laravel"
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

# ─── Server Side Up Docker ────────────────────────────────────────────────────
DOCKER_PHP_VERSION=8.4
APP_PORT=8080
HOST_UID=1000
HOST_GID=1000
AUTOBOOT=true
AUTOBOOT_RUN_MIGRATIONS=true
HORIZON_ENABLED=true
SCHEDULER_ENABLED=true

# ─── Logging & Error Handling ─────────────────────────────────────────────────
LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

# ─── Database (PostgreSQL) ────────────────────────────────────────────────────
DB_CONNECTION=pgsql
DB_VERSION=17
DB_HOST=db
DB_PORT=5433
DB_DATABASE=app
DB_USERNAME=app
DB_PASSWORD=secret

# ─── Redis ────────────────────────────────────────────────────────────────────
REDIS_VERSION=8-alpine
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=secret
REDIS_SCHEME=tls

# ─── Cache & Session ─────────────────────────────────────────────────────────
CACHE_DRIVER=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

# ─── Queue ────────────────────────────────────────────────────────────────────
QUEUE_CONNECTION=redis

# ─── Mail ─────────────────────────────────────────────────────────────────────
# MAIL_MAILER=log
# MAIL_HOST=127.0.0.1
# MAIL_PORT=2525
# MAIL_USERNAME=null
# MAIL_PASSWORD=null
# MAIL_ENCRYPTION=null
# MAIL_FROM_ADDRESS="hello@example.com"
# MAIL_FROM_NAME="${APP_NAME}"

# ─── AWS S3 (Optional) ───────────────────────────────────────────────────────
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_DEFAULT_REGION=us-east-1
# AWS_BUCKET=
# AWS_USE_PATH_STYLE_ENDPOINT=false

# ─── Pusher (Optional) ───────────────────────────────────────────────────────
# PUSHER_APP_ID=
# PUSHER_APP_KEY=
# PUSHER_APP_SECRET=
# PUSHER_HOST=
# PUSHER_PORT=443
# PUSHER_SCHEME=https
# PUSHER_APP_CLUSTER=mt1

# ─── Vite (Optional) ─────────────────────────────────────────────────────────
# VITE_APP_NAME="${APP_NAME}"

# ─── Load Testing (k6) ───────────────────────────────────────────────────────
LOAD_TEST_BASE_URL=http://localhost:8080
LOAD_TEST_API_TOKEN=test-token

# ─── Code Quality Thresholds ─────────────────────────────────────────────────
# PHPStan static analysis level (0-9)
PHPSTAN_LEVEL=9

# Minimum type coverage percentage
TYPE_COVERAGE_MINIMUM=90

# Minimum test coverage percentage
TEST_COVERAGE_MINIMUM=80

# Infection mutation testing thresholds
INFECTION_MIN_MSI=90
INFECTION_MIN_COVERED_MSI=90
ENVEOF
        log_success ".env.example создан"
    else
        log_success ".env.example загружен из репозитория"
    fi
fi

################################################################################
# Шаг 0/13: Определение версии PHP
################################################################################
log_info "Шаг 0/13: Определение версии PHP..."

CURRENT_PHP_VERSION=""
if command -v php &> /dev/null; then
    CURRENT_PHP_VERSION=$(php -v | head -n 1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
fi

# Приоритет: аргумент > .env > .env.example > дефолт 8.4
PHP_VERSION_TARGET=""

if [ -n "$2" ]; then
    PHP_VERSION_TARGET="$2"
elif [ -f ".env" ] && grep -q "^DOCKER_PHP_VERSION=" .env 2>/dev/null; then
    PHP_VERSION_TARGET=$(grep "^DOCKER_PHP_VERSION=" .env | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d "'")
elif [ -f ".env.example" ] && grep -q "^DOCKER_PHP_VERSION=" .env.example 2>/dev/null; then
    PHP_VERSION_TARGET=$(grep "^DOCKER_PHP_VERSION=" .env.example | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

# Если версия не определена или некорректна — дефолт 8.4
if [ -z "$PHP_VERSION_TARGET" ]; then
    PHP_VERSION_TARGET="8.4"
fi

case "$PHP_VERSION_TARGET" in
    8.3)
        LARAVEL_VERSION="^11.0"
        SPATIE_DATA_VERSION="^4.0"
        SPATIE_EVENT_SOURCING_VERSION="^7.0"
        SPATIE_PERMISSION_VERSION="^7.0"
        SAFECODE_VERSION="^2.0"
        PEST_VERSION="^3.0"
        PEST_PLUGIN_VERSION="^3.0"
        INFECTION_VERSION="^0.29.0"
        DOCKER_PHP_VERSION="8.3"
        log_info "Используется PHP 8.3 + Laravel 11 (стабильная)"
        ;;
    8.5)
        LARAVEL_VERSION="^13.0"
        SPATIE_DATA_VERSION="^4.0"
        SPATIE_EVENT_SOURCING_VERSION="^7.0"
        SPATIE_PERMISSION_VERSION="^7.0"
        SAFECODE_VERSION="^3.0"
        PEST_VERSION="^4.0"
        PEST_PLUGIN_VERSION="^4.0"
        INFECTION_VERSION="^0.30.0"
        DOCKER_PHP_VERSION="8.5"
        log_info "Используется PHP 8.5 + Laravel 13 (последняя)"
        ;;
    *)
        PHP_VERSION_TARGET="8.4"
        LARAVEL_VERSION="^12.0"
        SPATIE_DATA_VERSION="^4.0"
        SPATIE_EVENT_SOURCING_VERSION="^7.0"
        SPATIE_PERMISSION_VERSION="^7.0"
        SAFECODE_VERSION="^2.0"
        PEST_VERSION="^3.0"
        PEST_PLUGIN_VERSION="^3.0"
        INFECTION_VERSION="^0.29.0"
        DOCKER_PHP_VERSION="8.4"
        log_info "Используется PHP 8.4 + Laravel 12 (по умолчанию)"
        ;;
esac

log_info "Целевая версия PHP: ${PHP_VERSION_TARGET}"
log_info "Целевая версия Laravel: ${LARAVEL_VERSION}"

# Проверка необходимости установки PHP
PHP_NEED_INSTALL=false
if [ "$CURRENT_PHP_VERSION" != "$PHP_VERSION_TARGET" ]; then
    PHP_NEED_INSTALL=true
    log_info "PHP ${PHP_VERSION_TARGET} не найдена, будет выполнена установка"
fi

################################################################################
# Шаг 1/13: Проверка и установка PHP и Composer
################################################################################
log_info "Шаг 1/13: Проверка PHP и Composer..."

PHP_INSTALLED=false
COMPOSER_INSTALLED=false

# Проверка PHP (текущей версии)
if command -v php &> /dev/null; then
    PHP_VERSION=$(php -v | head -n 1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
    log_info "PHP найден: версия $PHP_VERSION"

    # Проверка на соответствие целевой версии
    if [ "$PHP_VERSION" = "$PHP_VERSION_TARGET" ]; then
        PHP_INSTALLED=true
        log_success "PHP ${PHP_VERSION_TARGET} уже установлена"
    else
        log_warning "Текущая PHP версия ($PHP_VERSION) не соответствует целевой (${PHP_VERSION_TARGET})"
    fi
else
    log_warning "PHP не найден"
fi

# Проверка Composer
if command -v composer &> /dev/null; then
    COMPOSER_INSTALLED=true
    log_info "Composer найден"
else
    log_warning "Composer не найден"
fi

# Установка PHP если выбрана другая версия
if [ "$PHP_NEED_INSTALL" = true ]; then
    log_info "Требуется установка PHP ${PHP_VERSION_TARGET}..."

    # Запрос пароля sudo
    log_info "Запрос прав sudo для установки..."
    sudo -v || {
        log_error "Не удалось получить права sudo"
        exit 1
    }

    log_info "Установка PHP ${PHP_VERSION_TARGET}..."

    # Определение дистрибутива
    if [ -f /etc/debian_version ] || [ -f /etc/ubuntu-version ]; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        
        log_info "Добавление репозитория ondrej/php для PHP ${PHP_VERSION_TARGET}..."
        sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
        sudo apt-get update
        
        sudo apt-get install -y php${PHP_VERSION_TARGET} php${PHP_VERSION_TARGET}-cli php${PHP_VERSION_TARGET}-pgsql \
            php${PHP_VERSION_TARGET}-xml php${PHP_VERSION_TARGET}-mbstring php${PHP_VERSION_TARGET}-curl php${PHP_VERSION_TARGET}-zip php${PHP_VERSION_TARGET}-bcmath \
            php${PHP_VERSION_TARGET}-redis php${PHP_VERSION_TARGET}-intl

        # Переключаем альтернативы на новую версию
        sudo update-alternatives --set php /usr/bin/php${PHP_VERSION_TARGET} 2>/dev/null || true
        
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
        # RHEL/CentOS
        sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
        sudo dnf module install -y php:remi-${PHP_VERSION_TARGET}
        sudo dnf install -y php php-cli php-pgsql php-xml php-mbstring \
            php-curl php-zip php-bcmath php-redis php-intl
        
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        sudo pacman -Syu --noconfirm php${PHP_VERSION_TARGET} php${PHP_VERSION_TARGET}-pgsql php${PHP_VERSION_TARGET}-intl
        
    else
        log_error "Неподдерживаемый дистрибутив Linux"
        log_info "Пожалуйста, установите PHP ${PHP_VERSION_TARGET}+ вручную"
        exit 1
    fi

    PHP_INSTALLED=true
    log_success "PHP ${PHP_VERSION_TARGET} установлена"
fi

# Установка Composer если не установлен
if [ "$COMPOSER_INSTALLED" = false ]; then
    log_info "Установка Composer..."

    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

    COMPOSER_INSTALLED=true
    log_success "Composer установлен"
fi

# Финальная проверка
if [ "$PHP_INSTALLED" = false ] && [ "$PHP_NEED_INSTALL" = false ]; then
    log_error "Не удалось найти PHP"
    exit 1
fi

if [ "$COMPOSER_INSTALLED" = false ]; then
    log_error "Не удалось установить Composer"
    exit 1
fi

log_success "PHP и Composer готовы к работе"

################################################################################
# Шаг 2/13: Создание Laravel проекта
################################################################################
log_info "Шаг 2/13: Создание Laravel проекта..."

# Создаём проект через composer create-project (официальный способ Laravel)
composer create-project "laravel/laravel:${LARAVEL_VERSION}" "${PROJECT_NAME}" --prefer-dist

cd "${PROJECT_DIR}" || exit 1

log_success "Laravel проект создан"

################################################################################
# Шаг 3/13: Установка основных пакетов
################################################################################
log_info "Шаг 3/13: Установка основных пакетов..."

composer require \
    "laravel/framework:${LARAVEL_VERSION}" \
    "spatie/laravel-data:${SPATIE_DATA_VERSION}" \
    "spatie/laravel-event-sourcing:${SPATIE_EVENT_SOURCING_VERSION}" \
    "spatie/laravel-permission:${SPATIE_PERMISSION_VERSION}" \
    "thecodingmachine/safe:${SAFECODE_VERSION}" \
    --no-interaction

log_success "Основные пакеты установлены"

################################################################################
# Шаг 4/13: Установка dev-зависимостей
################################################################################
log_info "Шаг 4/13: Установка dev-зависимостей..."

# Разрешаем плагины
composer config allow-plugins.infection/extension-installer true
composer config allow-plugins.pestphp/pest-plugin true

composer require --dev \
    laravel/pint:^1.0 \
    phpstan/phpstan:^2.0 \
    phpstan/phpstan-strict-rules:^2.0 \
    phpstan/phpstan-phpunit:^2.0 \
    "pestphp/pest:${PEST_VERSION}" \
    "pestphp/pest-plugin-laravel:${PEST_PLUGIN_VERSION}" \
    "pestphp/pest-plugin-type-coverage:${PEST_PLUGIN_VERSION}" \
    "infection/infection:${INFECTION_VERSION}" \
    zircote/swagger-php:^4.0 \
    --no-interaction --with-all-dependencies

log_success "Dev-зависимости установлены"

################################################################################
# Шаг 5/13: Создание структуры доменов
################################################################################
log_info "Шаг 5/13: Создание структуры доменов..."

mkdir -p src/Domains/User/Application/Commands
mkdir -p src/Domains/User/Application/Queries
mkdir -p src/Domains/User/Application/Handlers
mkdir -p src/Domains/User/Domain/Entities
mkdir -p src/Domains/User/Domain/ValueObjects
mkdir -p src/Domains/User/Domain/Aggregates
mkdir -p src/Domains/User/Domain/Events
mkdir -p src/Domains/User/Domain/Repositories
mkdir -p src/Domains/User/Infrastructure/Persistence
mkdir -p src/Domains/User/Infrastructure/Eloquent
mkdir -p src/Domains/User/Infrastructure/Projection
mkdir -p src/Domains/User/Infrastructure/Policies
mkdir -p src/Domains/User/Interfaces/Http/Controllers
mkdir -p src/Domains/User/Interfaces/Http/DTOs
mkdir -p src/Domains/User/Interfaces/CLI

log_success "Структура доменов создана"

################################################################################
# Шаг 6/13: Создание Docker-окружения (Server Side Up)
################################################################################
log_info "Шаг 6/13: Создание Docker-окружения (Server Side Up)..."

# Создаём директорию для Dockerfile
mkdir -p docker/php

# Dockerfile от Server Side Up
cat > docker/php/Dockerfile << DOCKERFILE
FROM serversideup/php:${DOCKER_PHP_VERSION}-fpm-nginx

# Установка расширений PHP
USER root
RUN install-php-extensions \
    pgsql \
    pdo_pgsql \
    redis \
    opcache \
    exif \
    pcntl \
    bcmath \
    gd \
    intl \
    zip

# Очистка кэша
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
USER www-data
DOCKERFILE

# docker-compose.yml для Server Side Up
cat > docker-compose.yml << DOCKERCOMPOSE
version: '3.8'
services:
  app:
    image: serversideup/php:\${DOCKER_PHP_VERSION:-8.4}-fpm-nginx
    user: "\${HOST_UID:-1000}:\${HOST_GID:-1000}"
    volumes:
      - .:/var/www/html
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    env_file:
      - .env
    healthcheck:
      test: ["CMD", "/usr/bin/php", "/var/www/html/artisan", "health:check"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    ports:
      - "\${APP_PORT:-8080}:80"

  db:
    image: postgres:\${DB_VERSION:-17}
    environment:
      POSTGRES_DB: \${DB_DATABASE:-app}
      POSTGRES_USER: \${DB_USERNAME:-app}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-secret}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "\${DB_PORT:-5432}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${DB_USERNAME:-app} -d \${DB_DATABASE:-app}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:\${REDIS_VERSION:-8-alpine}
    command: redis-server --requirepass \${REDIS_PASSWORD:-secret}
    ports:
      - "\${REDIS_PORT:-6379}:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "\${REDIS_PASSWORD:-secret}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
DOCKERCOMPOSE

# .dockerignore
cat > .dockerignore << 'DOCKERIGNORE'
.git
.gitignore
.idea
.vscode
*.md
node_modules
vendor
composer.lock
.env
storage/*
!storage/.gitignore
bootstrap/cache/*
!bootstrap/.gitignore
DOCKERIGNORE

log_success "Docker-окружение создано"

################################################################################
# Шаг 7/13: Создание .env и конфигурационных файлов
################################################################################
log_info "Шаг 7/13: Создание окружения и конфигурационных файлов..."

# Копируем наш .env.example (заменяем стандартный Laravel)
cp .env.example .env 2>/dev/null || true

# Генерируем APP_KEY
php artisan key:generate

# Функция: добавляет переменную в .env только если она ещё не существует
set_env() {
    local key="$1"
    local value="$2"
    if ! grep -q "^${key}=" .env 2>/dev/null; then
        echo "${key}=${value}" >> .env
    fi
}

# Функция: читает значение из .env (если существует)
get_env() {
    local key="$1"
    local default="$2"
    local value
    value=$(grep "^${key}=" .env 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    echo "${value:-$default}"
}

# Server Side Up Docker
set_env "DOCKER_PHP_VERSION" "${DOCKER_PHP_VERSION}"
set_env "APP_PORT" "8080"
set_env "HOST_UID" "$(id -u)"
set_env "HOST_GID" "$(id -g)"
set_env "AUTOBOOT" "true"
set_env "AUTOBOOT_RUN_MIGRATIONS" "true"
set_env "HORIZON_ENABLED" "true"
set_env "SCHEDULER_ENABLED" "true"

# Database
set_env "DB_CONNECTION" "pgsql"
set_env "DB_VERSION" "17"
set_env "DB_HOST" "db"
set_env "DB_PORT" "5433"
set_env "DB_DATABASE" "app"
set_env "DB_USERNAME" "app"
set_env "DB_PASSWORD" "secret"

# Redis
set_env "REDIS_VERSION" "8-alpine"
set_env "REDIS_HOST" "redis"
set_env "REDIS_PORT" "6379"
set_env "REDIS_PASSWORD" "secret"
set_env "REDIS_SCHEME" "tls"

# Cache & Session
set_env "CACHE_DRIVER" "redis"
set_env "SESSION_DRIVER" "redis"
set_env "SESSION_LIFETIME" "120"

# Queue
set_env "QUEUE_CONNECTION" "redis"

# Load Testing
set_env "LOAD_TEST_BASE_URL" "http://localhost:8080"
set_env "LOAD_TEST_API_TOKEN" "test-token"

# Читаем пороги качества из .env
PHPSTAN_LEVEL=$(get_env "PHPSTAN_LEVEL" "9")
TYPE_COVERAGE_MIN=$(get_env "TYPE_COVERAGE_MINIMUM" "90")
TEST_COVERAGE_MIN=$(get_env "TEST_COVERAGE_MINIMUM" "80")
INFECTION_MSI=$(get_env "INFECTION_MIN_MSI" "90")
INFECTION_COVERED_MSI=$(get_env "INFECTION_MIN_COVERED_MSI" "90")

# pint.json
cat > pint.json << 'PINTJSON'
{
  "preset": "laravel",
  "rules": {
    "declare_strict_types": true,
    "strict_comparison": true,
    "strict_param": true,
    "no_unused_imports": true,
    "no_empty_statement": true,
    "no_useless_return": true
  }
}
PINTJSON

# phpstan.neon
cat > phpstan.neon << PHPSTANNEON
parameters:
    level: ${PHPSTAN_LEVEL}
    paths:
        - app/
        - src/
    excludePaths:
        - tests/
PHPSTANNEON

# phpstan-type-coverage.neon
cat > phpstan-type-coverage.neon << PHPSTANNEON
includes:
    - ./vendor/tomasvotruba/type-coverage/config/config.neon

parameters:
    type_coverage:
        minimum: ${TYPE_COVERAGE_MIN}
PHPSTANNEON

# infection.json5
cat > infection.json5 << INFECTIONJSON
{
  "source": {
    "directories": [
      "src"
    ]
  },
  "timeout": 10,
  "logs": {
    "text": "infection.log",
    "summary": "summary.log",
    "json": "infection.json",
    "html": "infection-html",
    "gitlab": "infection-gitlab.json",
    "codeclimate": "infection-codeclimate.json"
  },
  "mutators": {
    "@default": true,
    "IdenticalEqual": true,
    "NotIdenticalNotEqual": true,
    "PublicVisibility": true,
    "ProtectedVisibility": true
  },
  "testFramework": "pest",
  "coverage": {
    "test": "--coverage=phpunit"
  },
  "minMsi": ${INFECTION_MSI},
  "minCoveredMsi": ${INFECTION_COVERED_MSI}
}
INFECTIONJSON

log_success "Окружение и конфигурационные файлы созданы"

################################################################################
# Шаг 8/13: Обновление composer.json скриптов
################################################################################
log_info "Шаг 8/13: Настройка composer скриптов..."

# Читаем текущий composer.json и добавляем скрипты
TEST_COV_MIN="${TEST_COVERAGE_MIN:-80}"
TYPE_COV_MIN="${TYPE_COVERAGE_MIN:-90}"
INF_MSI="${INFECTION_MSI:-90}"
INF_COVERED="${INFECTION_COVERED_MSI:-90}"

php -r "
\$composer = json_decode(file_get_contents('composer.json'), true);
\$composer['scripts']['pint'] = 'pint';
\$composer['scripts']['pint:test'] = 'pint --test';
\$composer['scripts']['phpstan'] = 'phpstan analyse -c phpstan.neon --memory-limit=2G';
\$composer['scripts']['phpstan:type-coverage'] = 'phpstan analyse -c phpstan-type-coverage.neon --memory-limit=2G';
\$composer['scripts']['test'] = 'pest';
\$composer['scripts']['test:coverage'] = 'pest --coverage --min=${TEST_COV_MIN}';
\$composer['scripts']['type-coverage'] = 'pest --type-coverage --min=${TYPE_COV_MIN}';
\$composer['scripts']['infection'] = 'infection --min-msi=${INF_MSI} --min-covered-msi=${INF_COVERED}';
\$composer['scripts']['swagger'] = 'test -d storage/api-docs || mkdir -p storage/api-docs && php vendor/bin/openapi --output storage/api-docs/api-docs.json --bootstrap vendor/autoload.php src/';
\$composer['scripts']['load-test:smoke'] = 'k6 run --tag test_type=smoke load-tests/user-api.js';
\$composer['scripts']['load-test:load'] = 'k6 run --tag test_type=load load-tests/user-api.js';
\$composer['scripts']['load-test:stress'] = 'k6 run --tag test_type=stress load-tests/user-api.js';
\$composer['scripts']['load-test:all'] = ['@load-test:smoke', '@load-test:load', '@load-test:stress'];
\$composer['scripts']['qa'] = ['@pint:test', '@phpstan', '@phpstan:type-coverage', '@test:coverage', '@type-coverage', '@infection'];
\$composer['scripts']['qa:fast'] = ['@pint:test', '@phpstan', '@phpstan:type-coverage', '@test:coverage', '@type-coverage'];
file_put_contents('composer.json', json_encode(\$composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
"

log_success "Composer скрипты настроены"

# Добавляем Domains в autoload
php -r '
$composer = json_decode(file_get_contents("composer.json"), true);
$composer["autoload"]["psr-4"]["Domains\\"] = "src/Domains/";
file_put_contents("composer.json", json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
'
composer dump-autoload --quiet

log_success "Autoload настроен"

################################################################################
# Шаг 9/13: Создание примера домена User
################################################################################
log_info "Шаг 9/13: Создание примера домена User..."

# Command DTO - CreateUserCommand
cat > src/Domains/User/Application/Commands/CreateUserCommand.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Commands;

use Spatie\LaravelData\Attributes\Validation\Email;
use Spatie\LaravelData\Attributes\Validation\Min;
use Spatie\LaravelData\Attributes\Validation\Required;
use Spatie\LaravelData\Data;

final class CreateUserCommand extends Data
{
    public function __construct(
        #[Required, Email]
        public readonly string $email,

        #[Required, Min(2)]
        public readonly string $name,

        public readonly ?string $phone = null,
    ) {}
}
PHP

# Command DTO - UpdateUserCommand
cat > src/Domains/User/Application/Commands/UpdateUserCommand.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Commands;

use Spatie\LaravelData\Attributes\Validation\Email;
use Spatie\LaravelData\Attributes\Validation\Sometimes;
use Spatie\LaravelData\Attributes\Validation\Unique;
use Spatie\LaravelData\Attributes\Validation\Uuid;
use Spatie\LaravelData\Data;

final class UpdateUserCommand extends Data
{
    public function __construct(
        #[Uuid]
        public readonly string $userId,

        #[Sometimes, Email, Unique(table: 'users', column: 'email')]
        public readonly ?string $email = null,

        #[Sometimes]
        public readonly ?string $name = null,

        #[Sometimes]
        public readonly ?string $phone = null,
    ) {}

    public function withId(string $userId): static
    {
        return new static(
            userId: $userId,
            email: $this->email,
            name: $this->name,
            phone: $this->phone,
        );
    }
}
PHP

# Command Handler - CreateUserCommandHandler
cat > src/Domains/User/Application/Handlers/CreateUserCommandHandler.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Handlers;

use Domains\User\Application\Commands\CreateUserCommand;
use Domains\User\Infrastructure\Eloquent\UserModel;

final class CreateUserCommandHandler
{
    public function __invoke(CreateUserCommand $command): string
    {
        /** @var UserModel $user */
        $user = UserModel::create([
            'email' => $command->email,
            'name' => $command->name,
            'phone' => $command->phone,
        ]);

        return $user->id;
    }
}
PHP

# Command Handler - UpdateUserCommandHandler
cat > src/Domains/User/Application/Handlers/UpdateUserCommandHandler.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Handlers;

use Domains\User\Application\Commands\UpdateUserCommand;
use Domains\User\Infrastructure\Eloquent\UserModel;

final class UpdateUserCommandHandler
{
    public function __invoke(UpdateUserCommand $command): string
    {
        /** @var UserModel|null $user */
        $user = UserModel::find($command->userId);

        if ($user === null) {
            throw new \RuntimeException("User not found: {$command->userId}");
        }

        $user->update([
            'email' => $command->email ?? $user->email,
            'name' => $command->name ?? $user->name,
            'phone' => $command->phone ?? $user->phone,
        ]);

        return $command->userId;
    }
}
PHP

# Query DTO - GetUserQuery
cat > src/Domains/User/Application/Queries/GetUserQuery.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Queries;

final readonly class GetUserQuery
{
    public function __construct(
        public string $userId,
    ) {}
}
PHP

# Query Handler - GetUserQueryHandler
cat > src/Domains/User/Application/Handlers/GetUserQueryHandler.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Handlers;

use Domains\User\Application\Queries\GetUserQuery;
use Domains\User\Infrastructure\Eloquent\UserModel;
use Domains\User\Interfaces\Http\DTOs\UserResponseDTO;

final class GetUserQueryHandler
{
    public function __invoke(GetUserQuery $query): ?UserResponseDTO
    {
        /** @var UserModel|null $user */
        $user = UserModel::find($query->userId);

        return $user ? UserResponseDTO::fromModel($user) : null;
    }
}
PHP

# Query DTO - ListUsersQuery
cat > src/Domains/User/Application/Queries/ListUsersQuery.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Queries;

final class ListUsersQuery
{
    /**
     * @param array<string, mixed> $filters
     */
    public function __construct(
        private readonly array $filters = [],
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function getFilters(): array
    {
        return $this->filters;
    }
}
PHP

# Query Handler - ListUsersQueryHandler
cat > src/Domains/User/Application/Handlers/ListUsersQueryHandler.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Handlers;

use Domains\User\Application\Queries\ListUsersQuery;
use Domains\User\Infrastructure\Eloquent\UserModel;
use Illuminate\Pagination\LengthAwarePaginator;

final class ListUsersQueryHandler
{
    public function __invoke(ListUsersQuery $query): LengthAwarePaginator
    {
        return UserModel::query()
            ->orderBy('created_at', 'desc')
            ->paginate(15);
    }
}
PHP

# Domain Event - UserCreated
cat > src/Domains/User/Domain/Events/UserCreated.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Domain\Events;

final class UserCreated
{
    public function __construct(
        public readonly string $userId,
        public readonly string $email,
        public readonly string $name,
    ) {}
}
PHP

# Domain Aggregate - UserAggregate
cat > src/Domains/User/Domain/Aggregates/UserAggregate.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Domain\Aggregates;

final class UserAggregate
{
    public function __construct(
        private string $userId = '',
        private string $email = '',
        private string $name = '',
    ) {}

    public static function create(
        string $userId,
        string $email,
        string $name,
    ): self {
        return new self($userId, $email, $name);
    }

    public static function retrieve(string $userId): self
    {
        return new self($userId);
    }

    public function update(
        ?string $email = null,
        ?string $name = null,
        ?string $phone = null,
    ): self {
        return $this;
    }
}
PHP

# Response DTO - UserResponseDTO
cat > src/Domains/User/Interfaces/Http/DTOs/UserResponseDTO.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Interfaces\Http\DTOs;

use Domains\User\Infrastructure\Eloquent\UserModel;
use Spatie\LaravelData\Data;

final class UserResponseDTO extends Data
{
    public function __construct(
        public readonly string $id,
        public readonly string $email,
        public readonly string $name,
        public readonly ?string $phone,
        public readonly \DateTimeImmutable $created_at,
    ) {}

    public static function fromModel(UserModel $user): static
    {
        return new static(
            id: $user->id,
            email: $user->email,
            name: $user->name,
            phone: $user->phone,
            created_at: $user->created_at->toDateTimeImmutable(),
        );
    }
}
PHP

# Response DTO - UserListResponseDTO
cat > src/Domains/User/Interfaces/Http/DTOs/UserListResponseDTO.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Interfaces\Http\DTOs;

use Spatie\LaravelData\Data;

final class UserListResponseDTO extends Data
{
    /**
     * @param array<int, UserResponseDTO> $users
     */
    public function __construct(
        public readonly array $users,
        public readonly int $total,
        public readonly int $page,
        public readonly int $perPage,
    ) {}

    /**
     * @param \Illuminate\Pagination\LengthAwarePaginator $paginator
     */
    public static function fromPaginator(
        \Illuminate\Pagination\LengthAwarePaginator $paginator
    ): static {
        return new static(
            users: UserResponseDTO::collect($paginator->items()),
            total: $paginator->total(),
            page: $paginator->currentPage(),
            perPage: $paginator->perPage(),
        );
    }
}
PHP

# Controller - UserController
cat > src/Domains/User/Interfaces/Http/Controllers/UserController.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Interfaces\Http\Controllers;

use Domains\User\Application\Commands\CreateUserCommand;
use Domains\User\Application\Commands\UpdateUserCommand;
use Domains\User\Application\Queries\GetUserQuery;
use Domains\User\Application\Queries\ListUsersQuery;
use Domains\User\Interfaces\Http\DTOs\UserListResponseDTO;
use Domains\User\Interfaces\Http\DTOs\UserResponseDTO;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use OpenApi\Attributes as OA;

#[OA\Tag(
    name: 'Users',
    description: 'API endpoints for user management'
)]
final class UserController extends Controller
{
    #[OA\Post(
        path: '/api/users',
        operationId: 'createUser',
        tags: ['Users'],
        summary: 'Create a new user',
        description: 'Creates a new user with the provided data',
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['email', 'name'],
                properties: [
                    new OA\Property(property: 'email', type: 'string', format: 'email', example: 'user@example.com'),
                    new OA\Property(property: 'name', type: 'string', minLength: 2, example: 'John Doe'),
                    new OA\Property(property: 'phone', type: 'string', nullable: true, example: '+1234567890'),
                ]
            )
        ),
        responses: [
            new OA\Response(
                response: 201,
                description: 'User created successfully',
                content: new OA\JsonContent(ref: '#/components/schemas/UserResponseDTO')
            ),
            new OA\Response(
                response: 422,
                description: 'Validation error',
                content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')
            ),
        ]
    )]
    public function store(CreateUserCommand $command): UserResponseDTO
    {
        $userId = dispatch_sync($command);

        $userDto = dispatch(new GetUserQuery($userId));

        if ($userDto === null) {
            abort(404, 'User not found');
        }

        return $userDto;
    }

    #[OA\Put(
        path: '/api/users/{id}',
        operationId: 'updateUser',
        tags: ['Users'],
        summary: 'Update a user',
        description: 'Updates an existing user with the provided data',
        parameters: [
            new OA\Parameter(
                name: 'id',
                in: 'path',
                required: true,
                description: 'User UUID',
                schema: new OA\Schema(type: 'string', format: 'uuid')
            ),
        ],
        requestBody: new OA\RequestBody(
            required: false,
            content: new OA\JsonContent(
                properties: [
                    new OA\Property(property: 'email', type: 'string', format: 'email', nullable: true, example: 'user@example.com'),
                    new OA\Property(property: 'name', type: 'string', nullable: true, example: 'John Doe'),
                    new OA\Property(property: 'phone', type: 'string', nullable: true, example: '+1234567890'),
                ]
            )
        ),
        responses: [
            new OA\Response(
                response: 200,
                description: 'User updated successfully',
                content: new OA\JsonContent(ref: '#/components/schemas/UserResponseDTO')
            ),
            new OA\Response(response: 404, description: 'User not found'),
            new OA\Response(
                response: 422,
                description: 'Validation error',
                content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')
            ),
        ]
    )]
    public function update(string $id, UpdateUserCommand $command): UserResponseDTO
    {
        dispatch_sync($command->withId($id));

        $userDto = dispatch(new GetUserQuery($id));

        if ($userDto === null) {
            abort(404, 'User not found');
        }

        return $userDto;
    }

    #[OA\Get(
        path: '/api/users/{id}',
        operationId: 'getUser',
        tags: ['Users'],
        summary: 'Get a user by ID',
        description: 'Retrieves a user by their UUID',
        parameters: [
            new OA\Parameter(
                name: 'id',
                in: 'path',
                required: true,
                description: 'User UUID',
                schema: new OA\Schema(type: 'string', format: 'uuid')
            ),
        ],
        responses: [
            new OA\Response(
                response: 200,
                description: 'User retrieved successfully',
                content: new OA\JsonContent(ref: '#/components/schemas/UserResponseDTO')
            ),
            new OA\Response(response: 404, description: 'User not found'),
        ]
    )]
    public function show(string $id): UserResponseDTO
    {
        $userDto = dispatch(new GetUserQuery($id));

        if ($userDto === null) {
            abort(404, 'User not found');
        }

        return $userDto;
    }

    #[OA\Get(
        path: '/api/users',
        operationId: 'listUsers',
        tags: ['Users'],
        summary: 'List all users',
        description: 'Retrieves a paginated list of users',
        parameters: [
            new OA\Parameter(
                name: 'page',
                in: 'query',
                required: false,
                description: 'Page number',
                schema: new OA\Schema(type: 'integer', default: 1)
            ),
            new OA\Parameter(
                name: 'per_page',
                in: 'query',
                required: false,
                description: 'Items per page',
                schema: new OA\Schema(type: 'integer', default: 15)
            ),
        ],
        responses: [
            new OA\Response(
                response: 200,
                description: 'Users list retrieved successfully',
                content: new OA\JsonContent(ref: '#/components/schemas/UserListResponseDTO')
            ),
            new OA\Response(response: 401, description: 'Unauthorized'),
        ]
    )]
    public function index(Request $request): UserListResponseDTO
    {
        return dispatch(new ListUsersQuery($request->query()));
    }

    #[OA\Delete(
        path: '/api/users/{id}',
        operationId: 'deleteUser',
        tags: ['Users'],
        summary: 'Delete a user',
        description: 'Deletes a user by their UUID',
        parameters: [
            new OA\Parameter(
                name: 'id',
                in: 'path',
                required: true,
                description: 'User UUID',
                schema: new OA\Schema(type: 'string', format: 'uuid')
            ),
        ],
        responses: [
            new OA\Response(response: 204, description: 'User deleted successfully'),
            new OA\Response(response: 404, description: 'User not found'),
        ]
    )]
    public function destroy(string $id): \Illuminate\Http\JsonResponse
    {
        // TODO: Implement DeleteCommand
        return response()->noContent();
    }
}
PHP

# Eloquent Model - UserModel
cat > src/Domains/User/Infrastructure/Eloquent/UserModel.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Infrastructure\Eloquent;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * @method static static|null find($id)
 * @method static static create(array $attributes = [])
 * @method static Builder query()
 */
final class UserModel extends Model
{
    use HasUuids, SoftDeletes;

    protected $table = 'users';

    protected $fillable = [
        'id',
        'email',
        'name',
        'phone',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];
}
PHP

# Projector - UserProjector
cat > src/Domains/User/Infrastructure/Projection/UserProjector.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Infrastructure\Projection;

use Domains\User\Domain\Events\UserCreated;
use Domains\User\Infrastructure\Eloquent\UserModel;

final class UserProjector
{
    public function onUserCreated(UserCreated $event): void
    {
        UserModel::create([
            'id' => $event->userId,
            'email' => $event->email,
            'name' => $event->name,
        ]);
    }
}
PHP

# Policy - UserPolicy
cat > src/Domains/User/Infrastructure/Policies/UserPolicy.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Infrastructure\Policies;

use Domains\User\Infrastructure\Eloquent\UserModel;
use Illuminate\Auth\Access\HandlesAuthorization;

final class UserPolicy
{
    use HandlesAuthorization;

    public function view(UserModel $currentUser, UserModel $targetUser): bool
    {
        return $currentUser->id === $targetUser->id;
    }

    public function edit(UserModel $currentUser, UserModel $targetUser): bool
    {
        return $currentUser->id === $targetUser->id;
    }

    public function delete(UserModel $currentUser, UserModel $targetUser): bool
    {
        return false;
    }
}
PHP

log_success "Пример домена User создан"

################################################################################
# Шаг 10/13: Создание миграций и настройка маршрутов
################################################################################
log_info "Шаг 10/13: Создание миграций и маршрутов..."

# Создаём миграцию users
cat > database/migrations/2024_01_01_000000_create_users_table.php << 'PHP'
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('email')->unique();
            $table->string('name');
            $table->string('phone')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
PHP

# Добавляем маршруты
cat > routes/api.php << 'ROUTES'
<?php

declare(strict_types=1);

use Domains\User\Interfaces\Http\Controllers\UserController;
use Illuminate\Support\Facades\Route;

// User routes
Route::prefix('users')->group(function () {
    Route::post('/', [UserController::class, 'store'])->middleware(['permission:user.create']);
    Route::get('/{id}', [UserController::class, 'show'])->middleware(['permission:user.view']);
    Route::put('/{id}', [UserController::class, 'update'])->middleware(['permission:user.edit']);
    Route::get('/', [UserController::class, 'index'])->middleware(['permission:user.view']);
});
ROUTES

log_success "Миграции и маршруты созданы"

################################################################################
# Шаг 11/13: Создание тестов
################################################################################
log_info "Шаг 11/13: Создание тестов..."

mkdir -p tests/Integration/Domains/User/Handlers

cat > tests/Integration/Domains/User/Handlers/CreateUserTest.php << 'PHP'
<?php

declare(strict_types=1);

namespace Tests\Integration\Domains\User\Handlers;

use Domains\User\Application\Commands\CreateUserCommand;
use Domains\User\Application\Handlers\CreateUserCommandHandler;
use Tests\TestCase;

final class CreateUserTest extends TestCase
{
    public function test_create_user(): void
    {
        $command = new CreateUserCommand(
            email: 'test@example.com',
            name: 'Test User',
        );

        $handler = new CreateUserCommandHandler();
        $userId = $handler($command);

        $this->assertDatabaseHas('users', [
            'id' => $userId,
            'email' => 'test@example.com',
        ]);
    }
}
PHP

log_success "Тесты созданы"

################################################################################
# Шаг 12/13: Создание GitHub Actions workflow и load-тестов
################################################################################
log_info "Шаг 12/13: Настройка CI/CD и нагрузочных тестов..."

mkdir -p .github/workflows
mkdir -p load-tests/results

# GitHub Actions CI/CD
cat > .github/workflows/ci.yml << YAML
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  tests:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:\${DB_VERSION:-17}
        env:
          POSTGRES_DB: test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: secret
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:\${REDIS_VERSION:-8-alpine}
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '${DOCKER_PHP_VERSION}'
          extensions: pgsql, redis
          coverage: xdebug
          tools: infection

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Copy environment file
        run: cp .env.ci .env

      - name: Generate application key
        run: php artisan key:generate

      - name: Run migrations
        run: php artisan migrate --force

      - name: Run Pint (code style)
        run: composer pint:test

      - name: Run PHPStan
        run: composer phpstan

      - name: Run tests with coverage
        run: composer test:coverage
        env:
          XDEBUG_MODE: coverage

      - name: Check type coverage
        run: composer type-coverage

      - name: Run Infection (mutation testing)
        run: composer infection
        env:
          XDEBUG_MODE: coverage
YAML

# .env.ci
cat > .env.ci << 'ENVCI'
APP_ENV=testing
APP_KEY=base64:test1234567890test1234567890te=

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=test
DB_USERNAME=postgres
DB_PASSWORD=secret

REDIS_HOST=127.0.0.1
REDIS_PORT=6379

CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
ENVCI

# Load test script (k6)
cat > load-tests/user-api.js << 'K6JS'
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const apiLatency = new Trend('api_latency');

export const options = {
  scenarios: {
    smoke: {
      executor: 'constant-vus',
      vus: 5,
      duration: '30s',
      gracefulStop: '5s',
      tags: { test_type: 'smoke' },
    },
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 50 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 100 },
        { duration: '1m', target: 100 },
        { duration: '30s', target: 0 },
      ],
      gracefulRampDown: '10s',
      tags: { test_type: 'load' },
      startTime: '35s',
    },
  },
  thresholds: {
    http_req_duration: ['p(50)<200', 'p(90)<500', 'p(95)<800'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const API_TOKEN = __ENV.API_TOKEN || 'test-token';

const headers = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'Authorization': `Bearer ${API_TOKEN}`,
};

export default function () {
  const response = http.get(`${BASE_URL}/api/users`, { headers });
  
  check(response, {
    'list users: status is 200': (r) => r.status === 200,
  });
  
  errorRate.add(response.status !== 200);
  apiLatency.add(response.timings.duration);
  
  sleep(1);
}

export function handleSummary(data) {
  return {
    'load-tests/results/user-api-summary.json': JSON.stringify(data, null, 2),
  };
}
K6JS

log_success "CI/CD и нагрузочные тесты настроены"

################################################################################
# Шаг 13/13: Запуск Docker и проверок качества
################################################################################
log_info "Шаг 13/13: Запуск Docker и проверок качества..."

# Проверка доступной команды docker compose
if command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    log_error "Docker Compose не найден. Установите Docker Compose и попробуйте снова."
    exit 1
fi

log_info "Запуск Docker контейнеров..."
$DOCKER_COMPOSE_CMD up -d

log_info "Ожидание готовности контейнеров..."
sleep 10

log_info "Запуск PHPStan (базовый уровень)..."
$DOCKER_COMPOSE_CMD exec -T app composer phpstan || log_warning "PHPStan обнаружил ошибки (это можно исправить вручную)"

log_info "Запуск Pest тестов..."
$DOCKER_COMPOSE_CMD exec -T app composer test || log_warning "Тесты не прошли (это можно исправить вручную)"

log_success "Все проверки качества выполнены"

# Удаление локального PHP если он был установлен этим скриптом
if [ "$PHP_NEED_INSTALL" = true ] && [ "$PHP_INSTALLED" = true ]; then
    log_info "Остановка локального PHP ${PHP_VERSION_TARGET}..."
    sudo systemctl stop php${PHP_VERSION_TARGET}-fpm 2>/dev/null || true
    sudo systemctl disable php${PHP_VERSION_TARGET}-fpm 2>/dev/null || true
    
    log_info "Удаление локального PHP ${PHP_VERSION_TARGET}..."
    if [ -f /etc/debian_version ] || [ -f /etc/ubuntu-version ]; then
        sudo apt-get remove -y php${PHP_VERSION_TARGET}-cli php${PHP_VERSION_TARGET}-fpm \
            php${PHP_VERSION_TARGET}-pgsql php${PHP_VERSION_TARGET}-xml php${PHP_VERSION_TARGET}-mbstring \
            php${PHP_VERSION_TARGET}-curl php${PHP_VERSION_TARGET}-zip php${PHP_VERSION_TARGET}-bcmath \
            php${PHP_VERSION_TARGET}-redis php${PHP_VERSION_TARGET}-intl 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
        sudo dnf remove -y php-cli php-fpm 2>/dev/null || true
    elif [ -f /etc/arch-release ]; then
        sudo pacman -R --noconfirm php 2>/dev/null || true
    fi
    
    log_success "Локальный PHP удалён"
fi

################################################################################
# Завершение
################################################################################
echo ""
log_success "=========================================="
log_success "Проект ${PROJECT_NAME} успешно создан!"
log_success "=========================================="
echo ""
log_info "Следующие шаги:"
echo ""
echo "1. Перейдите в директорию проекта:"
echo "   cd ${PROJECT_NAME}"
echo ""
echo "2. Остановить Docker контейнеры:"
echo "   $DOCKER_COMPOSE_CMD down"
echo ""
echo "3. Запустить Docker контейнеры:"
echo "   $DOCKER_COMPOSE_CMD up -d"
echo ""
echo "4. Запустить миграции:"
echo "   $DOCKER_COMPOSE_CMD exec app php artisan migrate"
echo ""
echo "5. Запустить все проверки качества:"
echo "   $DOCKER_COMPOSE_CMD exec app composer qa"
echo ""
echo "6. Или быстрая проверка:"
echo "   $DOCKER_COMPOSE_CMD exec app composer qa:fast"
echo ""
echo "7. Нагрузочные тесты:"
echo "   $DOCKER_COMPOSE_CMD exec app composer load-test:smoke"
echo "   $DOCKER_COMPOSE_CMD exec app composer load-test:load"
echo "   $DOCKER_COMPOSE_CMD exec app composer load-test:stress"
echo ""
log_info "Документация: README.md"
log_info "Swagger UI: http://localhost:8080/api/documentation"
echo ""
