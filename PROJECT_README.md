# Project Name

Laravel API на основе Domain-Driven Design (DDD) с паттернами CQRS и Event Sourcing.

## Технологический стек

| Компонент | Технология |
|-----------|------------|
| Язык | PHP 8.4+ |
| Фреймворк | Laravel 12.x+ |
| База данных | PostgreSQL 17+ |
| Кэш/Очереди | Redis 8+ |
| Контейнеризация | Docker (Server Side Up) |

### Основные пакеты

- **spatie/laravel-data** — DTO с валидацией
- **spatie/laravel-event-sourcing** — Event Sourcing
- **spatie/laravel-permission** — Роли и права
- **Pest** — Тестирование
- **PHPStan** — Статический анализ (level 9)
- **Infection** — Мутационное тестирование
- **swagger-php** — OpenAPI документация

### Контроль качества

| Инструмент | Назначение | Команда |
|------------|------------|---------|
| Laravel Pint | Автоформатирование | `composer pint` |
| PHPStan | Статический анализ | `composer phpstan` |
| Pest | Тесты | `composer test` |
| Type Coverage | Покрытие типами | `composer type-coverage` |
| Infection | Мутационное тестирование | `composer infection` |

**Требования:**
- Pint: 100% без ошибок
- PHPStan: level 9 (baseline запрещён)
- Тесты: ≥ 80%
- Type coverage: ≥ 90%
- MSI: ≥ 90%

---

## Архитектура

### Структура доменов

```
src/Domains/[Domain]/
├── Application/
│   ├── Commands/       # Command DTO
│   ├── Queries/        # Query DTO
│   └── Handlers/       # Command & Query Handlers
├── Domain/
│   ├── Entities/
│   ├── ValueObjects/
│   ├── Aggregates/
│   ├── Events/
│   └── Repositories/
├── Infrastructure/
│   ├── Persistence/
│   ├── Eloquent/
│   └── Projection/
└── Interfaces/
    ├── Http/
    │   ├── Controllers/
    │   └── DTOs/       # Response DTO
    └── CLI/
```

### Слои

```
┌─────────────────────────────────────────────────┐
│              Presentation Layer                  │
│           (Controllers, DTOs)                    │
├─────────────────────────────────────────────────┤
│              Application Layer                   │
│       (Commands, Queries, Handlers)              │
├─────────────────────────────────────────────────┤
│                 Domain Layer                     │
│  (Entities, ValueObjects, Aggregates, Events)   │
├─────────────────────────────────────────────────┤
│              Infrastructure Layer                │
│    (Persistence, Eloquent, External Services)    │
└─────────────────────────────────────────────────┘
```

---

## Паттерны

### CQRS

- **Commands** — изменяют состояние, возвращают ID или void
- **Queries** — читают данные, возвращают DTO
- Обработчики находятся в `Application/Handlers/`

```php
// Command (изменение)
$userId = dispatch_sync(new CreateUserCommand(...));

// Query (чтение)
$user = dispatch(new GetUserQuery($userId));
```

### Event Sourcing

- Все изменения состояния фиксируются через события
- **Projectors** — создают read-модели из событий
- **Reactors** — реагируют на события (уведомления, интеграции)

### DTO (Spatie Laravel Data)

- Command/Query DTO — в `Application/Commands` и `Application/Queries`
- Response DTO — в `Interfaces/Http/DTOs`
- Валидация через атрибуты, без Form Request

---

## Требования к коду

- `declare(strict_types=1);` во всех PHP файлах
- PSR-12 / PSR-4
- `readonly` свойства где возможно
- Иммутабельность предпочтительна
- Исключения вместо `false` для ошибок

---

## Быстрый старт

```bash
# Запуск контейнеров
docker compose up -d

# Установка зависимостей
docker compose exec app composer install

# Миграции
docker compose exec app php artisan migrate

# Swagger UI
# http://localhost:8080/api/documentation

# Генерация Swagger документации
docker compose exec app composer swagger

# Запуск тестов
docker compose exec app composer test

# Все проверки качества
docker compose exec app composer qa

# Быстрая проверка (без Infection)
docker compose exec app composer qa:fast
```

### Управление контейнерами

```bash
docker compose up -d          # Запуск
docker compose down           # Остановка
docker compose logs -f app    # Логи
docker compose exec app bash  # Войти в контейнер
```

---

## CI/CD

Проект использует `${CI_PLATFORM}` для автоматизации:

| Этап | Описание |
|------|----------|
| Tests | Pest с coverage |
| Quality | Pint, PHPStan, Type Coverage, Infection |
| Load Tests | k6 (smoke, load) |

---

## Нагрузочное тестирование

```bash
docker compose exec app composer load-test:smoke   # Smoke тест
docker compose exec app composer load-test:load    # Load тест
docker compose exec app composer load-test:stress  # Stress тест
docker compose exec app composer load-test:all     # Все тесты
```
