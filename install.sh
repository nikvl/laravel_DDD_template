#!/usr/bin/env bash

################################################################################
# Laravel API DDD Template Installer
# Автоматическая установка проекта с архитектурой DDD + CQRS + Event Sourcing
#
# Использование:
#   curl -sL https://raw.githubusercontent.com/your-repo/install.sh | bash -s -- project-name
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
# Шаг 1: Создание Laravel проекта через Laravel Sail (без локального Composer)
################################################################################
log_info "Шаг 1/12: Создание Laravel проекта (через Laravel Sail)..."

# Используем Laravel Sail для создания проекта без локального Composer
# Это создаст проект с Docker-окружением
curl -s "https://laravel.build/${PROJECT_NAME}?with=pgsql,redis,meilisearch,mailpit" | bash

cd "${PROJECT_DIR}" || exit 1

log_success "Laravel проект создан"

################################################################################
# Шаг 2: Установка основных пакетов через Docker
################################################################################
log_info "Шаг 2/12: Установка основных пакетов..."

# Запускаем контейнеры для установки зависимостей
./vendor/bin/sail up -d

# Ждём готовности контейнера
log_info "Ожидание готовности контейнеров..."
sleep 10

# Устанавливаем пакеты через Sail
./vendor/bin/sail composer require \
    laravel/framework:^13.0 \
    spatie/laravel-data:^4.0 \
    spatie/laravel-event-sourcing:^10.0 \
    spatie/laravel-permission:^7.0 \
    thecodingmachine/safe:^2.0 \
    --no-interaction

log_success "Основные пакеты установлены"

################################################################################
# Шаг 3: Установка dev-зависимостей через Docker
################################################################################
log_info "Шаг 3/12: Установка dev-зависимостей..."

./vendor/bin/sail composer require --dev \
    laravel/pint:^1.0 \
    phpstan/phpstan:^2.0 \
    phpstan/phpstan-strict-rules:^2.0 \
    phpstan/phpstan-phpunit:^2.0 \
    pestphp/pest:^3.0 \
    pestphp/pest-plugin-laravel:^3.0 \
    pestphp/pest-plugin-type-coverage:^3.0 \
    infection/infection:^0.29.0 \
    infection/phpstan-adapter:^0.29.0 \
    infection/pest-adapter:^0.29.0 \
    --no-interaction

log_success "Dev-зависимости установлены"

################################################################################
# Шаг 4: Создание структуры доменов
################################################################################
log_info "Шаг 4/12: Создание структуры доменов..."

mkdir -p src/Domains/User/Application/Commands
mkdir -p src/Domains/User/Application/Queries
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
# Шаг 5: Замена Laravel Sail на Server Side Up Docker
################################################################################
log_info "Шаг 5/13: Замена Sail на Server Side Up Docker..."

# Останавливаем Sail контейнеры
./vendor/bin/sail stop 2>/dev/null || true

# Удаляем docker-compose.yml от Sail
rm -f docker-compose.yml

# Создаём директорию для Dockerfile
mkdir -p docker/php

# Dockerfile от Server Side Up
cat > docker/php/Dockerfile << 'DOCKERFILE'
FROM serversideup/php:8.5-fpm-nginx

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
cat > docker-compose.yml << 'DOCKERCOMPOSE'
version: '3.8'
services:
  app:
    image: serversideup/php:8.5-fpm-nginx
    volumes:
      - .:/var/www/html
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - DB_CONNECTION=pgsql
      - DB_HOST=db
      - DB_PORT=5432
      - DB_DATABASE=app
      - DB_USERNAME=app
      - DB_PASSWORD=secret
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - QUEUE_CONNECTION=redis
      - AUTOBOOT=true
      - AUTOBOOT_RUN_MIGRATIONS=true
      - HORIZON_ENABLED=true
      - SCHEDULER_ENABLED=true
    healthcheck:
      test: ["CMD", "/usr/bin/php", "/var/www/html/artisan", "health:check"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    ports:
      - "8080:80"

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
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

# Удаляем лишние файлы Sail
rm -f docker-compose.override.yml 2>/dev/null || true

log_success "Server Side Up Docker настроен"

################################################################################
# Шаг 6: Создание конфигурационных файлов
################################################################################
log_info "Шаг 6/13: Создание конфигурационных файлов..."

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
cat > phpstan.neon << 'PHPSTANNEON'
parameters:
  level: 9
  paths:
    - src/
    - tests/
  strictRules:
    allRules: true
  typeCoverage:
    minimum: 90
PHPSTANNEON

# infection.json5
cat > infection.json5 << 'INFECTIONJSON'
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
  "minMsi": 90,
  "minCoveredMsi": 90
}
INFECTIONJSON

# .env (копируем из .env.example и добавляем наши переменные)
cp .env.example .env

# Генерируем ключ через docker-compose
docker-compose up -d
log_info "Ожидание готовности контейнеров..."
sleep 15

docker-compose exec -T app php artisan key:generate

# Добавляем переменные для Server Side Up автоматизаций
cat >> .env << ENVVARS

# Server Side Up
AUTOBOOT=true
AUTOBOOT_RUN_MIGRATIONS=true
HORIZON_ENABLED=true
SCHEDULER_ENABLED=true
ENVVARS

log_success "Конфигурационные файлы созданы"

################################################################################
# Шаг 7: Обновление composer.json скриптов
################################################################################
log_info "Шаг 7/13: Настройка composer скриптов..."

# Читаем текущий composer.json и добавляем скрипты через docker-compose
docker-compose exec -T app php -r '
$composer = json_decode(file_get_contents("composer.json"), true);
$composer["scripts"]["pint"] = "pint";
$composer["scripts"]["pint:test"] = "pint --test";
$composer["scripts"]["phpstan"] = "phpstan analyse --level=9 --memory-limit=2G";
$composer["scripts"]["test"] = "pest";
$composer["scripts"]["test:coverage"] = "pest --coverage --min=80";
$composer["scripts"]["type-coverage"] = "pest --type-coverage --min=90";
$composer["scripts"]["infection"] = "infection --min-msi=90 --min-covered-msi=90";
$composer["scripts"]["qa"] = ["@pint:test", "@phpstan", "@test:coverage", "@type-coverage", "@infection"];
$composer["scripts"]["qa:fast"] = ["@pint:test", "@phpstan", "@test:coverage", "@type-coverage"];
file_put_contents("composer.json", json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
'

log_success "Composer скрипты настроены"

################################################################################
# Шаг 8: Создание примера домена User
################################################################################
log_info "Шаг 8/12: Создание примера домена User..."

# Command DTO - CreateUserCommand
cat > src/Domains/User/Application/Commands/CreateUserCommand.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Commands;

use Spatie\LaravelData\Attributes\Validation\Email;
use Spatie\LaravelData\Attributes\Validation\MinLength;
use Spatie\LaravelData\Attributes\Validation\Required;
use Spatie\LaravelData\Data;

final class CreateUserCommand extends Data
{
    public function __construct(
        #[Required, Email]
        public readonly string $email,

        #[Required, MinLength(2)]
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
cat > src/Domains/User/Application/Commands/CreateUserCommandHandler.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Commands;

use Domains\User\Domain\Aggregates\UserAggregate;
use Spatie\EventSourcing\Commands\CommandHandler;

final class CreateUserCommandHandler implements CommandHandler
{
    public function __invoke(CreateUserCommand $command): string
    {
        $userId = \Str::uuid();

        UserAggregate::create(
            $userId,
            $command->email,
            $command->name,
        )->persist();

        return $userId;
    }
}
PHP

# Command Handler - UpdateUserCommandHandler
cat > src/Domains/User/Application/Commands/UpdateUserCommandHandler.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Commands;

use Domains\User\Domain\Aggregates\UserAggregate;
use Spatie\EventSourcing\Commands\CommandHandler;

final class UpdateUserCommandHandler implements CommandHandler
{
    public function __invoke(UpdateUserCommand $command): string
    {
        UserAggregate::retrieve($command->userId)
            ->update(
                email: $command->email,
                name: $command->name,
                phone: $command->phone,
            )
            ->persist();

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
cat > src/Domains/User/Application/Queries/GetUserQueryHandler.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Application\Queries;

use Domains\User\Interfaces\Http\DTOs\UserResponseDTO;
use Domains\User\Infrastructure\Eloquent\UserModel;

final class GetUserQueryHandler
{
    public function __invoke(GetUserQuery $query): ?UserResponseDTO
    {
        $user = UserModel::find($query->userId);

        return $user ? UserResponseDTO::fromModel($user) : null;
    }
}
PHP

# Domain Event - UserCreated
cat > src/Domains/User/Domain/Events/UserCreated.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Domain\Events;

use Spatie\EventSourcing\StoredEvents\ShouldBeStored;

final class UserCreated extends ShouldBeStored
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

use Domains\User\Domain\Events\UserCreated;
use Spatie\EventSourcing\AggregateRoot;

final class UserAggregate extends AggregateRoot
{
    public static function create(
        string $userId,
        string $email,
        string $name,
    ): static {
        return (new static())
            ->recordThat(new UserCreated($userId, $email, $name));
    }

    public function update(
        ?string $email = null,
        ?string $name = null,
        ?string $phone = null,
    ): static {
        // Логика обновления
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
use Spatie\LaravelData\Attributes\Wrap;
use Spatie\LaravelData\Data;

#[Wrap('data')]
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

use Spatie\LaravelData\Attributes\Wrap;
use Spatie\LaravelData\Data;

#[Wrap('data')]
final class UserListResponseDTO extends Data
{
    public function __construct(
        /** @var array<int, UserResponseDTO> */
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
use Domains\User\Interfaces\Http\DTOs\UserListResponseDTO;
use Domains\User\Interfaces\Http\DTOs\UserResponseDTO;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

final class UserController extends Controller
{
    public function store(CreateUserCommand $command): UserResponseDTO
    {
        $userId = dispatch_sync($command);

        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($userId))
        );
    }

    public function update(string $id, UpdateUserCommand $command): UserResponseDTO
    {
        dispatch_sync($command->withId($id));

        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($id))
        );
    }

    public function show(string $id): UserResponseDTO
    {
        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($id))
        );
    }

    public function index(Request $request): UserListResponseDTO
    {
        return UserListResponseDTO::fromPaginator(
            dispatch(new \Domains\User\Application\Queries\ListUsersQuery($request->query()))
        );
    }
}
PHP

# Eloquent Model - UserModel
cat > src/Domains/User/Infrastructure/Eloquent/UserModel.php << 'PHP'
<?php

declare(strict_types=1);

namespace Domains\User\Infrastructure\Eloquent;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

final class UserModel extends Model
{
    use SoftDeletes;

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
use Spatie\EventSourcing\Projectors\Projector;
use Spatie\EventSourcing\Projectors\ProjectsEvents;

#[ProjectsEvents(on: Domains\User\Domain\Projection\UserProjection::class)]
final class UserProjector implements Projector
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
        return $currentUser->id === $targetUser->id
            || $currentUser->hasRole('admin')
            || $currentUser->hasRole('manager');
    }

    public function edit(UserModel $currentUser, UserModel $targetUser): bool
    {
        return ($currentUser->id === $targetUser->id
                || $currentUser->hasRole('manager'))
            && $targetUser->is_active;
    }

    public function delete(UserModel $currentUser, UserModel $targetUser): bool
    {
        return $currentUser->hasRole('admin')
            && $targetUser->is_active === false;
    }
}
PHP

log_success "Пример домена User создан"

################################################################################
# Шаг 9: Создание миграций
################################################################################
log_info "Шаг 9/13: Создание миграций..."

docker-compose exec -T app php artisan make:migration create_users_table
docker-compose exec -T app php artisan make:migration create_permission_tables
docker-compose exec -T app php artisan make:migration create_projected_events_table
docker-compose exec -T app php artisan make:migration create_stored_events_table

log_success "Миграции созданы"

################################################################################
# Шаг 10: Настройка маршрутов
################################################################################
log_info "Шаг 10/12: Настройка маршрутов..."

cat >> routes/api.php << 'ROUTES'

// User routes
use Domains\User\Interfaces\Http\Controllers\UserController;

Route::prefix('users')->group(function () {
    Route::post('/', [UserController::class, 'store'])->middleware(['permission:user.create']);
    Route::get('/{id}', [UserController::class, 'show'])->middleware(['permission:user.view']);
    Route::put('/{id}', [UserController::class, 'update'])->middleware(['permission:user.edit']);
    Route::get('/', [UserController::class, 'index'])->middleware(['permission:user.view']);
});
ROUTES

log_success "Маршруты настроены"

################################################################################
# Шаг 11: Создание тестов
################################################################################
log_info "Шаг 11/12: Создание тестов..."

mkdir -p tests/Integration/Domains/User/Commands

cat > tests/Integration/Domains/User/Commands/CreateUserTest.php << 'PHP'
<?php

declare(strict_types=1);

namespace Tests\Integration\Domains\User\Commands;

use Domains\User\Application\Commands\CreateUserCommand;
use Tests\TestCase;

final class CreateUserTest extends TestCase
{
    public function test_create_user(): void
    {
        $command = new CreateUserCommand(
            email: 'test@example.com',
            name: 'Test User',
        );

        $userId = dispatch_sync($command);

        $this->assertDatabaseHas('users', [
            'id' => $userId,
            'email' => 'test@example.com',
        ]);
    }
}
PHP

log_success "Тесты созданы"

################################################################################
# Шаг 12: Создание GitHub Actions workflow
################################################################################
log_info "Шаг 12/12: Настройка CI/CD..."

mkdir -p .github/workflows

cat > .github/workflows/ci.yml << 'YAML'
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
        image: postgres:15
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
        image: redis:7-alpine
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
          php-version: '8.5'
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

log_success "CI/CD настроен"

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
echo "2. Запустите Docker контейнеры (Server Side Up):"
echo "   docker-compose up -d"
echo ""
echo "3. Запустите миграции:"
echo "   docker-compose exec app php artisan migrate"
echo ""
echo "4. Запустите все проверки качества:"
echo "   docker-compose exec app composer qa"
echo ""
echo "5. Или быстрая проверка (без мутационного тестирования):"
echo "   docker-compose exec app composer qa:fast"
echo ""
log_info "Документация: README.md"
log_info "Docker команды: docker-compose exec app <command>"
echo ""
