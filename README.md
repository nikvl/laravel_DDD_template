# Laravel API DDD Template

> **Автоматическая установка (не требует локального PHP/Composer):**
> ```bash
> # Быстрый старт
> curl -sL https://raw.githubusercontent.com/nikvl/laravel_DDD_template/install.sh | bash -s -- my-project
> 
> # Или вручную
> git clone https://github.com/nikvl/laravel_DDD_template.git my-project
> cd my-project
> bash install.sh my-project
> ```
>
> **Что делает скрипт:**
> 1. Создаёт Laravel 13 проект через `laravel.build` (не нужен локальный Composer)
> 2. Устанавливает все пакеты через Docker
> 3. **Заменяет Laravel Sail на Server Side Up Docker** (production-ready)
> 4. Создаёт DDD структуру, конфигурационные файлы, пример домена
> 5. Настраивает CI/CD, тесты, миграции
>
> **Server Side Up Docker преимущества:**
> - ✅ Автоматические миграции при деплое (AUTOBOOT)
> - ✅ Встроенная поддержка Horizon и Scheduler
> - ✅ Health checks из коробки
> - ✅ Оптимизирован для production

## Описание проекта

---

## 1. Общие сведения

### 1.1. Назначение проекта
Создание шаблонного проекта (boilerplate) на Laravel с архитектурой Domain-Driven Design (DDD), реализующего паттерны CQRS и Event Sourcing для построения масштабируемых и поддерживаемых API-приложений.

**Важно:** Проект ориентирован исключительно на REST API (без server-side rendering, без Blade).

### 1.2. Целевая аудитория
- PHP/Laravel разработчики, начинающие новые API-проекты
- Команды, переходящие на DDD-архитектуру
- Проекты со сложной бизнес-логикой и требованиями к безопасности
- Микросервисные архитектуры

---

## 2. Технологический стек

| Компонент | Технология | Версия |
|-----------|------------|--------|
| Язык | PHP | 8.5+ |
| Фреймворк | Laravel | 13.x+ |
| База данных | PostgreSQL | 14+ |
| Кэш/Очереди | Redis | 6.2+ |
| Поиск | Elasticsearch / Meilisearch | 8.x / 1.x |
| Контейнеризация | Docker, Docker Compose | 24+ |

### 2.1. Основные пакеты

```json
{
  "require": {
    "laravel/framework": "^13.0",
    "spatie/laravel-data": "^4.0",
    "spatie/laravel-event-sourcing": "^10.0",
    "spatie/laravel-permission": "^7.0",
    "thecodingmachine/safe": "^2.0"
  },
  "require-dev": {
    "laravel/pint": "^1.0",
    "phpstan/phpstan": "^2.0",
    "phpstan/phpstan-strict-rules": "^2.0",
    "phpstan/phpstan-phpunit": "^2.0",
    "pestphp/pest": "^3.0",
    "pestphp/pest-plugin-laravel": "^3.0",
    "pestphp/pest-plugin-type-coverage": "^3.0",
    "infection/infection": "^0.29.0",
    "infection/phpstan-adapter": "^0.29.0",
    "infection/pest-adapter": "^0.29.0"
  }
}
```

### 2.2. Инструменты контроля качества

**Обязательное использование для всего кода:**

| Инструмент | Назначение | Команда |
|------------|------------|---------|
| **Laravel Pint** | Автоформатирование кода | `pint` |
| **PHPStan** | Статический анализ (level 9) | `phpstan analyse --level=9` |
| **Pest** | Тестирование (unit, integration, E2E) | `pest` |
| **Type Coverage** | Проверка покрытия типами | `pest --type-coverage` |
| **Infection** | Мутационное тестирование | `infection` |

**Требования:**
- 100% код покрывается Laravel Pint (PSR-12)
- PHPStan level 9 без ошибок (baseline запрещён)
- Покрытие тестами ≥ 80%
- Покрытие типами (type coverage) ≥ 90%
- MSI (Mutation Score Indicator) ≥ 90%

---

## 3. Архитектура проекта

### 3.1. Структура доменов

```
src/
└── Domains/
    └── [DomainName]/
        ├── Application/
        │   ├── Commands/       # Command DTO + Command Handlers
        │   ├── Queries/        # Query DTO + Query Handlers
        │   └── Services/
        ├── Domain/
        │   ├── Entities/
        │   ├── ValueObjects/
        │   ├── Aggregates/
        │   ├── Events/
        │   └── Repositories/
        ├── Infrastructure/
        │   ├── Persistence/
        │   ├── Eloquent/
        │   └── External/
        └── Interfaces/
            ├── Http/
            │   ├── Controllers/
            │   └── DTOs/       # Response DTO
            └── CLI/
```

### 3.2. Слои архитектуры

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│              (Controllers, DTOs)                         │
├─────────────────────────────────────────────────────────┤
│                   Application Layer                      │
│            (Commands, Queries, DTOs, Services)           │
├─────────────────────────────────────────────────────────┤
│                      Domain Layer                        │
│         (Entities, ValueObjects, Aggregates, Events)     │
├─────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                    │
│          (Persistence, Eloquent, External Services)      │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Паттерны и принципы

### 4.1. Domain-Driven Design (DDD)

**Требования:**
- Выделение ограниченных контекстов (Bounded Contexts)
- Агрегаты как единицы согласованности
- Value Objects для неизменяемых значений
- Domain Events для фиксации фактов

**Пример агрегата:**
```php
namespace Domains\User\Domain\Aggregates;

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
}
```

### 4.2. CQRS (Command Query Responsibility Segregation)

**Требования:**
- Разделение команд (изменение состояния) и запросов (чтение)
- Команды возвращают только ID или void
- Запросы возвращают DTO/Resource
- Отдельные обработчики для команд и запросов

**Структура:**
```
Application/
├── Commands/
│   ├── CreateUserCommand.php
│   └── CreateUserHandler.php
├── Queries/
│   ├── GetUserQuery.php
│   └── GetUserHandler.php
└── DTOs/
    ├── CreateUserDTO.php
    └── UserDTO.php
```

**Пример команды:**
```php
namespace Domains\User\Application\Commands;

use Domains\User\Application\DTOs\CreateUserDTO;
use Domains\User\Domain\Aggregates\UserAggregate;
use Spatie\EventSourcing\CommandBus\Commands\CommandHandler;

final class CreateUserHandler implements CommandHandler
{
    public function __invoke(CreateUserDTO $dto): string
    {
        $userId = Str::uuid();
        
        UserAggregate::create(
            $userId,
            $dto->email,
            $dto->name,
        )->persist();
        
        return $userId;
    }
}
```

**Пример запроса:**
```php
namespace Domains\User\Application\Queries;

use Domains\User\Application\DTOs\UserDTO;
use Domains\User\Infrastructure\Eloquent\UserModel;

final class GetUserHandler implements QueryHandler
{
    public function __invoke(GetUserQuery $query): ?UserDTO
    {
        $user = UserModel::find($query->userId);
        
        return $user ? UserDTO::from($user) : null;
    }
}
```

### 4.3. Event Sourcing

**Требования:**
- Все изменения состояния через события
- Projectors для создания read-моделей
- Reactors для реакции на события
- Snapshotting для производительности

**Пример события:**
```php
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
```

**Пример проектора:**
```php
namespace Domains\User\Infrastructure\Projection;

use Domains\User\Domain\Events\UserCreated;
use Domains\User\Infrastructure\Eloquent\UserModel;
use Spatie\EventSourcing\Projectors\Projector;

final class UserProjector implements Projector
{
    #[EventHandling(UserCreated::class)]
    public function onUserCreated(UserCreated $event): void
    {
        UserModel::create([
            'id' => $event->userId,
            'email' => $event->email,
            'name' => $event->name,
        ]);
    }
}
```

### 4.4. Spatie DTO

**Требования:**
- Использование `spatie/laravel-data` для всех DTO
- Валидация данных на уровне DTO (вместо Form Request)
- Response DTO для ответов API (вместо API Resources)
- Command DTO (для команд) находятся в `Application/Commands`
- Query DTO (для запросов) находятся в `Application/Queries`
- Response DTO (для ответов) находятся в `Interfaces/Http/DTOs`
- Command DTO автоматически создаются из Request через атрибуты параметров

**Пример Command DTO:**
```php
namespace Domains\User\Application\Commands;

use Spatie\LaravelData\Attributes\Validation\Email;
use Spatie\LaravelData\Attributes\Validation\Required;
use Spatie\LaravelData\Attributes\Validation\MinLength;
use Spatie\LaravelData\Attributes\Validation\Sometimes;
use Spatie\LaravelData\Data;

final class CreateUserCommand extends Data
{
    public function __construct(
        #[Required, Email]
        public readonly string $email,

        #[Required, MinLength(2)]
        public readonly string $name,

        #[Sometimes]
        public readonly ?string $phone = null,
    ) {}
}
```

**Пример Command DTO для обновления:**
```php
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

    /**
     * Создание команды с ID пользователя
     */
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
```

**Пример Response DTO:**
```php
namespace Domains\User\Interfaces\Http\DTOs;

use Domains\User\Domain\Entities\User;
use Spatie\LaravelData\Attributes\WithTransformer;
use Spatie\LaravelData\Data;
use Spatie\LaravelData\Attributes\Wrap;

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

    /**
     * Создание Response DTO из Entity
     */
    public static function fromEntity(User $user): static
    {
        return new static(
            id: $user->id(),
            email: $user->email(),
            name: $user->name(),
            phone: $user->phone(),
            created_at: $user->createdAt(),
        );
    }

    /**
     * Создание Response DTO из Eloquent модели
     */
    public static function fromModel(\Domains\User\Infrastructure\Eloquent\UserModel $user): static
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
```

**Пример Response DTO для коллекции:**
```php
namespace Domains\User\Interfaces\Http\DTOs;

use Spatie\LaravelData\Data;
use Spatie\LaravelData\Attributes\Wrap;

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
     * @param \Illuminate\Pagination\LengthAwarePaginator<\Domains\User\Domain\Entities\User> $paginator
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
```

**Использование в контроллере (с Response DTO):**
```php
namespace Domains\User\Interfaces\Http\Controllers;

use Domains\User\Application\Commands\CreateUserCommand;
use Domains\User\Application\Commands\UpdateUserCommand;
use Domains\User\Application\Queries\GetUserQuery;
use Domains\User\Interfaces\Http\DTOs\UserResponseDTO;
use Illuminate\Routing\Controller;

final class UserController extends Controller
{
    /**
     * Создание пользователя
     * CreateUserCommand автоматически создаётся из Request и валидируется
     */
    public function store(CreateUserCommand $command): UserResponseDTO
    {
        // Command отправляется через Command Bus, который находит соответствующий Handler
        $userId = dispatch_sync($command);

        // Возвращаем Response DTO
        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($userId))
        );
    }

    /**
     * Обновление пользователя
     */
    public function update(string $id, UpdateUserCommand $command): UserResponseDTO
    {
        // Command отправляется через Command Bus
        dispatch_sync($command->withId($id));

        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($id))
        );
    }

    /**
     * Получение пользователя
     */
    public function show(string $id): UserResponseDTO
    {
        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($id))
        );
    }

    /**
     * Список пользователей с пагинацией
     */
    public function index(\Illuminate\Http\Request $request): UserListResponseDTO
    {
        return UserListResponseDTO::fromPaginator(
            dispatch(new ListUsersQuery($request->query()))
        );
    }
}
```

**Пример команды-обработчика (Command Handler):**
```php
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
```

**Пример команды-обработчика для обновления:**
```php
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
```

---

## 5. Требования к коду

### 5.1. Стандарты кодирования

- **PSR-12** — базовый стандарт кодирования
- **PSR-4** — автозагрузка классов
- **Strict types** — `declare(strict_types=1);`
- **Иммутабельность** — `readonly` свойства где возможно

### 5.2. Laravel Pint (автоформатирование)

**Требование:** Весь код должен проходить проверку Pint без ошибок.

```bash
# Проверка
pint --test

# Автоформатирование
pint
```

**Конфигурация (pint.json):**
```json
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
```

### 5.3. PHPStan (статический анализ)

**Требование:** Level 9 без ошибок, baseline запрещён.

```bash
# Проверка
phpstan analyse --level=9 --memory-limit=2G

# Проверка с отчётом
phpstan analyse --level=9 --error-format=table > phpstan-report.txt
```

**Конфигурация (phpstan.neon):**
```neon
parameters:
  level: 9
  paths:
    - src/
    - tests/
  strictRules:
    allRules: true
  typeCoverage:
    minimum: 90
```

### 5.4. Тестирование (Pest)

**Требования:**
- Покрытие тестами ≥ 80%
- Unit-тесты для доменной логики
- Integration-тесты для команд/запросов
- E2E-тесты для HTTP-эндпоинтов
- Type coverage ≥ 90%

**Структура тестов:**
```
tests/
├── Unit/
│   └── Domains/
│       └── [Domain]/
│           ├── Domain/
│           └── Application/
├── Integration/
│   └── Domains/
│       └── [Domain]/
│           ├── Commands/
│           └── Queries/
└── E2E/
    └── Http/
```

**Пример теста:**
```php
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
```

### 5.5. Infection (мутационное тестирование)

**Требование:** MSI (Mutation Score Indicator) ≥ 90%

**Что такое мутационное тестирование:**
Infection создаёт мутации (изменения) в вашем коде и проверяет, могут ли тесты обнаружить эти изменения. Если тесты не обнаруживают мутацию — значит, тест недостаточен.

**Пример мутаций:**
- `===` → `==`
- `&&` → `||`
- `+` → `-`
- `return true` → `return false`
- Удаление условий

**Конфигурация (infection.json5):**
```json5
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
```

**Запуск:**
```bash
# Запуск мутационного тестирования
infection

# Запуск с кэшированием (быстрее для повторных запусков)
infection --coverage --min-msi=90

# Запуск только для изменённых файлов (в CI)
infection --only-covered --test-framework-options="--filter=changed"

# Вывод всех мутаций (включая выжившие)
infection --show-mutations
```

**Пример отчёта:**
```
Mutation Score Generator
========================

Total Mutation Score: 92% (450/489)

Total Mutations: 489
  - Killed: 450 (92%)
  - Escaped: 25 (5%)
  - Timed Out: 2 (1%)
  - Not Covered: 12 (2%)

Result: PASS ✅ (MSI ≥ 90%)
```

**Интеграция с CI/CD:**
```yaml
- name: Run Infection (Mutation Testing)
  run: composer infection -- --min-msi=90 --min-covered-msi=90
```

### 5.6. CI/CD Pipeline

**Требование:** Все проверки должны проходить в CI перед мержем.

**Пример GitHub Actions (`.github/workflows/ci.yml`):**
```yaml
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
```

**Конфигурация `.env.ci`:**
```env
APP_ENV=testing
APP_KEY=base64:...

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
```

**Скрипты composer.json:**
```json
{
  "scripts": {
    "pint": "pint",
    "pint:test": "pint --test",
    "phpstan": "phpstan analyse --level=9 --memory-limit=2G",
    "test": "pest",
    "test:coverage": "pest --coverage --min=80",
    "type-coverage": "pest --type-coverage --min=90",
    "infection": "infection --min-msi=90 --min-covered-msi=90",
    "qa": [
      "@pint:test",
      "@phpstan",
      "@test:coverage",
      "@type-coverage",
      "@infection"
    ],
    "qa:fast": [
      "@pint:test",
      "@phpstan",
      "@test:coverage",
      "@type-coverage"
    ]
  }
}
```

---

## 6. Инфраструктура

### 6.1. Docker-окружение

**Требования:**
- **PostgreSQL** — основная база данных (обязательно)
- **Redis** — кэш, сессии, очереди (обязательно)
- Все сервисы запускаются через Docker Compose
- **Рекомендуется:** [Server Side Up Docker PHP](https://serversideup.net/open-source/docker-php/docs/framework-guides/laravel/automations)

**Рекомендуемый базовый образ:**
```dockerfile
# docker/php/Dockerfile
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
```

**Автоматизации Server Side Up:**

1. **Автоматический запуск (Auto-Boot):**
   - Миграции БД выполняются автоматически при старте
   - Кэш очищается автоматически
   - Оптимизация выполняется в production

2. **Конфигурация через переменные окружения:**
```env
# Server Side Up автоматизации
AUTOBOOT=true
AUTOBOOT_RUN_MIGRATIONS=true
AUTOBOOT_OPTIMIZE_CACHE=true

# Laravel Horizon
HORIZON_ENABLED=true
HORIZON_BALANCE=max_shifts
HORIZON_BALANCE_MAX_SHIFT=10
HORIZON_BALANCE_COOLDOWN=300

# Laravel Scheduler
SCHEDULER_ENABLED=true
```

3. **Health Checks:**
```yaml
# docker-compose.yml
services:
  app:
    image: serversideup/php:8.5-fpm-nginx
    healthcheck:
      test: ["CMD", "/usr/bin/php", "/var/www/html/artisan", "health:check"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
```

**Полный docker-compose.yml:**
```yaml
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
```

**Конфигурация .env:**
```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=app
DB_USERNAME=app
DB_PASSWORD=secret

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
REDIS_DB=0

CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

### 6.2. Миграции

```php
// database/migrations/2024_01_01_000000_create_users_table.php
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('email')->unique();
            $table->string('name');
            $table->string('phone')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }
};
```

---

## 7. API-интерфейс

### 7.1. REST API

**Требования:**
- Только API (без server-side rendering)
- Spatie DTO для ответов API (вместо API Resources)
- Spatie DTO для валидации (вместо Form Request)
- Command DTO автоматически создаются из Request (через атрибуты параметров)
- Response DTO с пагинацией для списков
- JSON:API или стандартная REST-конвенция

**Пример контроллера:**
```php
namespace Domains\User\Interfaces\Http\Controllers;

use Domains\User\Application\DTOs\CreateUserDTO;
use Domains\User\Application\Queries\GetUserQuery;
use Domains\User\Interfaces\Http\DTOs\UserResponseDTO;
use Domains\User\Interfaces\Http\DTOs\UserListResponseDTO;
use Illuminate\Routing\Controller;

final class UserController extends Controller
{
    /**
     * Создание пользователя
     * CreateUserDTO автоматически создаётся из Request и валидируется
     */
    public function store(CreateUserDTO $dto): UserResponseDTO
    {
        // DTO уже валидировано, передаём в команду
        $userId = dispatch_sync(new CreateUserCommand($dto));

        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($userId))
        );
    }

    /**
     * Получение пользователя
     */
    public function show(string $id): UserResponseDTO
    {
        return UserResponseDTO::fromEntity(
            dispatch(new GetUserQuery($id))
        );
    }

    /**
     * Список пользователей
     */
    public function index(\Illuminate\Http\Request $request): UserListResponseDTO
    {
        return UserListResponseDTO::fromPaginator(
            dispatch(new ListUsersQuery($request->query()))
        );
    }
}
```

### 7.2. API-документация

**Требования:**
- OpenAPI/Swagger спецификация
- Laravel Scribe или OpenAPI Generator
- Примеры запросов и ответов

### 7.3. API-аутентификация

**Требования:**
- Laravel Sanctum для API-токенов
- OAuth 2.0 (опционально, через Laravel Passport)
- JWT-токены для микросервисов

---

## 8. Безопасность и авторизация

### 8.1. Требования

- Валидация всех входных данных
- Санитизация выходных данных
- Rate limiting для API
- CORS для кросс-доменных запросов
- HTTPS в production
- Шифрование чувствительных данных

### 8.2. RBAC (Role-Based Access Control)

**Пакет:** [spatie/laravel-permission v7](https://spatie.be/docs/laravel-permission/v7/introduction)

**Требования:**
- Роли для группировки разрешений
- Разрешения (permissions) для операций
- Назначение ролей пользователям
- Наследование ролей (опционально)

**Пример использования:**
```php
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

// Создание разрешений
Permission::create(['name' => 'user.create']);
Permission::create(['name' => 'user.edit']);
Permission::create(['name' => 'user.delete']);

// Создание роли
$role = Role::create(['name' => 'admin']);

// Назначение разрешений роли
$role->givePermissionTo(['user.create', 'user.edit', 'user.delete']);

// Назначение роли пользователю
$user->assignRole('admin');

// Проверка в контроллере (с Command DTO)
public function store(CreateUserCommand $command)
{
    // Command уже валидирован

    // Проверка разрешения
    $this->authorize('user.create');

    $userId = dispatch_sync($command);
    // ...
}
```

**Структура разрешений:**
```
[domain].[resource].[action]
- user.create
- user.edit
- user.delete
- user.view
- order.create
- order.edit
- order.cancel
```

### 8.3. ABAC (Attribute-Based Access Control)

**Требования:**
- Политики доступа на основе атрибутов
- Контекстная авторизация (владелец ресурса, время, статус)
- Gate и Policy классы Laravel

**Пример Policy:**
```php
namespace Domains\User\Infrastructure\Policies;

use Domains\User\Domain\Entities\User;
use Illuminate\Auth\Access\HandlesAuthorization;

final class UserPolicy
{
    use HandlesAuthorization;
    
    public function view(User $currentUser, User $targetUser): bool
    {
        // ABAC: пользователь может видеть только свои данные
        // или если он менеджер этого пользователя
        return $currentUser->id === $targetUser->id
            || $currentUser->manages($targetUser);
    }
    
    public function edit(User $currentUser, User $targetUser): bool
    {
        // ABAC: редактирование только если:
        // 1. Это свой пользователь
        // 2. Или текущий пользователь имеет роль менеджера
        // 3. И целевой пользователь не заблокирован
        return ($currentUser->id === $targetUser->id
                || $currentUser->hasRole('manager'))
            && !$targetUser->isLocked();
    }
    
    public function delete(User $currentUser, User $targetUser): bool
    {
        // ABAC: удаление только для админов
        // и если пользователь не активен 30+ дней
        return $currentUser->hasRole('admin')
            && $targetUser->inactiveForDays() >= 30;
    }
}
```

**Пример Gate:**
```php
// AppServiceProvider
Gate::define('access-resource', function (User $user, string $resourceType) {
    // ABAC: доступ на основе атрибутов пользователя и ресурса
    return $user->hasRole('admin')
        || ($user->department_id === $resourceType->department_id
            && $user->canAccess($resourceType));
});

// Использование в контроллере
if (Gate::allows('access-resource', $resource)) {
    // доступ разрешён
}
```

### 8.4. Комбинация RBAC + ABAC

**Рекомендуемый подход:**
1. **RBAC** — для базовых разрешений (CRUD операции)
2. **ABAC** — для контекстных проверок (владелец, статус, время)

**Пример middleware:**
```php
namespace Domains\User\Infrastructure\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class AuthorizeResourceAccess
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();
        
        // RBAC: проверка разрешения
        if (!$user->can($permission)) {
            abort(403, 'Insufficient permissions');
        }
        
        // ABAC: проверка контекста (если нужно)
        if ($resource = $request->route('user')) {
            $this->authorizeContext($user, $resource);
        }
        
        return $next($request);
    }
    
    private function authorizeContext(User $user, User $resource): void
    {
        if ($user->cannot('edit', $resource)) {
            abort(403, 'Context access denied');
        }
    }
}
```

---

## 9. Логирование и мониторинг

### 9.1. Логирование

```php
// config/logging.php
'channels' => [
    'stack' => [
        'driver' => 'stack',
        'channels' => ['daily', 'error_log'],
    ],
    
    'domain' => [
        'driver' => 'daily',
        'path' => storage_path('logs/domain.log'),
        'level' => 'debug',
    ],
],
```

### 9.2. Мониторинг

- Laravel Telescope для development
- Sentry для error tracking
- Prometheus + Grafana для метрик

---

## 10. Этапы реализации

### Этап 1: Базовая структура (Week 1)
- [ ] Настройка Docker-окружения (PostgreSQL, Redis)
- [ ] Установка Laravel и базовых пакетов
- [ ] Создание структуры доменов
- [ ] Настройка Laravel Pint
- [ ] Настройка PHPStan (level 9)
- [ ] Настройка Pest с coverage

### Этап 2: DDD Core (Week 2)
- [ ] Реализация базовых классов домена
- [ ] Value Objects
- [ ] Entities и Aggregates
- [ ] Domain Events

### Этап 3: CQRS (Week 3)
- [ ] Command Bus
- [ ] Query Bus
- [ ] Обработчики команд
- [ ] Обработчики запросов

### Этап 4: Event Sourcing (Week 4)
- [ ] Интеграция spatie/laravel-event-sourcing
- [ ] Projectors
- [ ] Reactors
- [ ] Snapshotting

### Этап 5: Spatie DTO (Week 5)
- [ ] Интеграция spatie/laravel-data
- [ ] DTO для всех доменов
- [ ] Валидация на уровне DTO
- [ ] Transformers

### Этап 6: RBAC/ABAC (Week 6)
- [ ] Интеграция spatie/laravel-permission
- [ ] Роли и разрешения
- [ ] Policy классы
- [ ] Gate и ABAC логика
- [ ] Middleware для авторизации

### Этап 7: API Interface (Week 7)
- [ ] Controllers
- [ ] DTO с валидацией (Command DTO)
- [ ] Response DTO для ответов
- [ ] OpenAPI документация
- [ ] API аутентификация (Sanctum)

### Этап 8: Тестирование и CI/CD (Week 8)
- [ ] Unit-тесты (domain logic)
- [ ] Integration-тесты (commands, queries)
- [ ] E2E-тесты (HTTP endpoints)
- [ ] Настройка GitHub Actions
- [ ] Проверка coverage (≥80%)
- [ ] Проверка type coverage (≥90%)
- [ ] Настройка Infection (мутационное тестирование)
- [ ] Проверка MSI (≥90%)

### Этап 9: Документация (Week 9)
- [ ] README с примерами
- [ ] API документация
- [ ] Архитектурные решения (ADR)
- [ ] Примеры использования

---

## 11. Критерии приемки

### 11.1. Функциональные
- [ ] Все команды выполняются корректно
- [ ] Все запросы возвращают данные
- [ ] Event Sourcing работает корректно
- [ ] Read-модели обновляются проекторами
- [ ] RBAC работает через spatie/laravel-permission
- [ ] ABAC политики применяются корректно
- [ ] API возвращает JSON ответы
- [ ] PostgreSQL используется как основное хранилище
- [ ] Redis используется для кэша и очередей

### 11.2. Нефункциональные
- [ ] Laravel Pint проходит без ошибок (100% кода)
- [ ] PHPStan level 9 без ошибок (baseline запрещён)
- [ ] Покрытие тестами ≥ 80%
- [ ] Покрытие типами (type coverage) ≥ 90%
- [ ] Мутационное тестирование (MSI) ≥ 90%
- [ ] Время ответа API < 200ms (p95)
- [ ] Docker-окружение работает из коробки
- [ ] CI/CD pipeline проходит успешно

### 11.3. Документация
- [ ] README с инструкцией по запуску
- [ ] API документация (OpenAPI/Swagger)
- [ ] Примеры авторизации и разрешений
- [ ] Примеры кода для основных сценариев
- [ ] Описание архитектуры
- [ ] CI/CD конфигурация

---

## 12. Пример домена "User"

### 12.1. Полная структура

```
Domains/User/
├── Application/
│   ├── Commands/
│   │   ├── CreateUserCommand.php      # Command DTO
│   │   ├── CreateUserCommandHandler.php
│   │   ├── UpdateUserCommand.php      # Command DTO
│   │   └── UpdateUserCommandHandler.php
│   └── Queries/
│       ├── GetUserQuery.php           # Query DTO
│       ├── GetUserQueryHandler.php
│       ├── ListUsersQuery.php         # Query DTO
│       └── ListUsersQueryHandler.php
├── Domain/
│   ├── Entities/
│   │   └── User.php
│   ├── ValueObjects/
│   │   ├── UserId.php
│   │   ├── Email.php
│   │   └── UserName.php
│   ├── Aggregates/
│   │   └── UserAggregate.php
│   ├── Events/
│   │   ├── UserCreated.php
│   │   ├── UserUpdated.php
│   │   └── UserDeleted.php
│   └── Repositories/
│       └── UserRepositoryInterface.php
├── Infrastructure/
│   ├── Persistence/
│   │   └── EloquentUserRepository.php
│   ├── Eloquent/
│   │   └── UserModel.php
│   ├── Projection/
│   │   └── UserProjector.php
│   └── Policies/
│       └── UserPolicy.php
└── Interfaces/
    ├── Http/
    │   ├── Controllers/
    │   │   └── UserController.php
    │   └── DTOs/
    │       ├── UserResponseDTO.php
    │       └── UserListResponseDTO.php
    └── CLI/
        └── CreateUserCommand.php
```

### 12.2. Примеры использования RBAC/ABAC

**Создание ролей и разрешений (Seeder):**
```php
namespace Database\Seeders;

use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;
use Illuminate\Database\Seeder;

final class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        // User permissions
        Permission::firstOrCreate(['name' => 'user.view']);
        Permission::firstOrCreate(['name' => 'user.create']);
        Permission::firstOrCreate(['name' => 'user.edit']);
        Permission::firstOrCreate(['name' => 'user.delete']);
        
        // Roles
        $admin = Role::firstOrCreate(['name' => 'admin']);
        $manager = Role::firstOrCreate(['name' => 'manager']);
        $user = Role::firstOrCreate(['name' => 'user']);
        
        // Assign permissions
        $admin->givePermissionTo(Permission::all());
        $manager->givePermissionTo(['user.view', 'user.edit']);
        $user->givePermissionTo(['user.view']);
    }
}
```

**Использование в контроллере:**
```php
namespace Domains\User\Interfaces\Http\Controllers;

use Domains\User\Application\Queries\GetUserQuery;
use Domains\User\Interfaces\Http\Resources\UserResource;
use Illuminate\Routing\Controller;
use Illuminate\Auth\Access\AuthorizationException;

final class UserController extends Controller
{
    /**
     * @throws AuthorizationException
     */
    public function show(string $id): UserResource
    {
        $user = dispatch(new GetUserQuery($id));
        
        // ABAC: проверка через Policy
        $this->authorize('view', $user);
        
        return UserResource::make($user);
    }
}
```

**Middleware для API:**
```php
// bootstrap/app.php
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias([
        'role' => \Spatie\Permission\Middleware\RoleMiddleware::class,
        'permission' => \Spatie\Permission\Middleware\PermissionMiddleware::class,
        'role_or_permission' => \Spatie\Permission\Middleware\RoleOrPermissionMiddleware::class,
    ]);
})
```

---

## 13. Приложения

### Приложение A: Ссылки на ресурсы

- [Laravel Beyond CRUD](https://beyondcrud.com/)
- [Spatie Laravel Data](https://spatie.be/docs/laravel-data)
- [Spatie Event Sourcing](https://spatie.be/docs/laravel-event-sourcing)
- [Spatie Laravel Permission](https://spatie.be/docs/laravel-permission/v7/introduction)
- [Domain-Driven Design](https://domainlanguage.com/ddd/)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)

### Приложение Б: Глоссарий

| Термин | Определение |
|--------|-------------|
| Aggregate | Кластер объектов, обрабатываемых как единое целое |
| Bounded Context | Границы контекста доменной модели |
| Command | Инструкция на изменение состояния |
| Query | Запрос на чтение данных |
| Projector | Обработчик событий для создания read-моделей |
| Reactor | Обработчик событий для побочных эффектов |
| Value Object | Неизменяемый объект, определяемый своими атрибутами |
| RBAC | Role-Based Access Control — управление доступом на основе ролей |
| ABAC | Attribute-Based Access Control — управление доступом на основе атрибутов |
| Permission | Разрешение на выполнение операции (например, user.create) |
| Policy | Класс Laravel для определения правил авторизации |
| Gate | Closure-базированная авторизация Laravel |
| Pint | Инструмент автоформатирования кода от Laravel |
| PHPStan | Инструмент статического анализа PHP-кода |
| Type Coverage | Метрика покрытия типов в коде |
| Infection | Инструмент мутационного тестирования для PHP |
| MSI | Mutation Score Indicator — процент убитых мутаций |
| Мутация | Искусственное изменение кода для проверки тестов |

### Приложение В: Быстрый старт

**Быстрая установка проекта:**
```bash
# Автоматическая установка (не требует локального PHP/Composer)
curl -sL https://raw.githubusercontent.com/nikvl/laravel_DDD_TEMPLATE/install.sh | bash -s -- my-project

# Перейти в проект
cd my-project

# Запустить Docker (Server Side Up)
docker-compose up -d
```

**Проверка качества кода:**
```bash
# Запуск всех проверок (включая мутационное тестирование)
docker-compose exec app composer qa

# Быстрая проверка (без мутационного тестирования)
docker-compose exec app composer qa:fast

# Или по отдельности:
docker-compose exec app composer pint          # Автоформатирование
docker-compose exec app composer pint:test     # Проверка стиля кода
docker-compose exec app composer phpstan       # Статический анализ
docker-compose exec app composer test          # Тесты
docker-compose exec app composer test:coverage # Тесты с покрытием
docker-compose exec app composer type-coverage # Проверка типов
docker-compose exec app composer infection     # Мутационное тестирование
```

**Полезные Docker команды:**
```bash
# Запуск контейнеров
docker-compose up -d

# Остановка контейнеров
docker-compose stop

# Выполнение команд в контейнере
docker-compose exec app php artisan <command>
docker-compose exec app composer <command>

# Просмотр логов
docker-compose logs -f app

# Перезапуск приложения
docker-compose restart app
```

**Server Side Up автоматизации:**
```bash
# Миграции выполняются автоматически при старте (AUTOBOOT_RUN_MIGRATIONS=true)
# Horizon запускается автоматически (HORIZON_ENABLED=true)
# Scheduler запускается автоматически (SCHEDULER_ENABLED=true)

# Отключить автоматизации (для отладки)
docker-compose exec app bash
echo "AUTOBOOT=false" >> .env
exit
docker-compose restart app
```

**Что делает install.sh:**
1. Создаёт Laravel 13 проект через `laravel.build` (с PostgreSQL, Redis, Mailpit)
2. Устанавливает все пакеты через Docker
3. **Заменяет Laravel Sail на Server Side Up Docker** (production-ready)
4. Создаёт DDD структуру папок
5. Настраивает конфигурационные файлы (pint.json, phpstan.neon, infection.json5)
6. Генерирует пример домена "User" (Commands, Handlers, DTOs, Controllers)
7. Создаёт миграции
8. Настраивает маршруты API
9. Создаёт тесты
10. Настраивает GitHub Actions CI/CD

---

**Версия документа:** 1.12  
**Дата создания:** 2026-03-19  
**Дата обновления:** 2026-03-19  
**Статус:** Черновик
