#!/bin/sh
set -e

cd /var/www/html

export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_HOME="${COMPOSER_HOME:-/tmp/composer}"

wait_for_mysql() {
    echo "Aguardando MySQL em ${DB_HOST:-mysql}:${DB_PORT:-3306}..."
    i=0
    while [ "$i" -lt 60 ]; do
        if php -r "
            try {
                new PDO(
                    'mysql:host=' . getenv('DB_HOST') . ';port=' . (getenv('DB_PORT') ?: '3306'),
                    getenv('DB_USERNAME'),
                    getenv('DB_PASSWORD') ?: ''
                );
                exit(0);
            } catch (Throwable \$e) {
                exit(1);
            }
        "; then
            echo "MySQL pronto."
            return 0
        fi
        i=$((i + 1))
        sleep 2
    done
    echo "Timeout aguardando MySQL." >&2
    exit 1
}

# Atualiza/insere chave no .env sem quebrar com aspas, /, &, etc.
write_env_value() {
    key="$1"
    value="$2"
    KEY="$key" VALUE="$value" php -r '
        $key = getenv("KEY");
        $value = getenv("VALUE");
        $path = ".env";
        $lines = file_exists($path) ? file($path, FILE_IGNORE_NEW_LINES) : [];
        $found = false;
        foreach ($lines as $i => $line) {
            if (str_starts_with($line, $key . "=")) {
                $lines[$i] = $key . "=" . $value;
                $found = true;
                break;
            }
        }
        if (!$found) {
            $lines[] = $key . "=" . $value;
        }
        file_put_contents($path, implode("\n", $lines) . "\n");
    '
}

ensure_app() {
    if [ -f artisan ]; then
        return 0
    fi

    echo "TastyIgniter nao encontrado. Executando composer create-project..."
    rm -rf tmp-install
    composer create-project tastyigniter/tastyigniter tmp-install --no-interaction --prefer-dist
    find tmp-install -mindepth 1 -maxdepth 1 -exec mv {} . \;
    rm -rf tmp-install
    echo "Projeto criado."
}

configure_env() {
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
        else
            touch .env
        fi
    fi

    write_env_value "APP_NAME" "\"${APP_NAME:-TastyIgniter}\""
    write_env_value "APP_ENV" "${APP_ENV:-production}"
    write_env_value "APP_DEBUG" "${APP_DEBUG:-false}"
    write_env_value "APP_URL" "${APP_URL:-https://lanchonete.freeddns.org}"

    write_env_value "DB_CONNECTION" "mysql"
    write_env_value "DB_HOST" "${DB_HOST:-mysql}"
    write_env_value "DB_PORT" "${DB_PORT:-3306}"
    write_env_value "DB_DATABASE" "${DB_DATABASE:-tastyigniter}"
    write_env_value "DB_USERNAME" "${DB_USERNAME:-tasty}"
    write_env_value "DB_PASSWORD" "\"${DB_PASSWORD:-secret}\""
    write_env_value "DB_PREFIX" "${DB_PREFIX:-ti_}"

    write_env_value "CACHE_DRIVER" "${CACHE_DRIVER:-file}"
    write_env_value "QUEUE_CONNECTION" "${QUEUE_CONNECTION:-database}"
    write_env_value "SESSION_DRIVER" "${SESSION_DRIVER:-file}"
}

ensure_permissions() {
    mkdir -p \
        storage/framework/cache \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        storage/app/public \
        bootstrap/cache

    chown -R www-data:www-data /var/www/html 2>/dev/null || true
    chmod -R ug+rwx storage bootstrap/cache 2>/dev/null || true
}

wait_for_app_files() {
    i=0
    while [ "$i" -lt 90 ]; do
        if [ -f artisan ]; then
            return 0
        fi
        i=$((i + 1))
        sleep 2
    done
    echo "Timeout aguardando arquivos do TastyIgniter (artisan)." >&2
    exit 1
}

is_installed() {
    php -r '
        try {
            $pdo = new PDO(
                "mysql:host=" . getenv("DB_HOST") . ";port=" . (getenv("DB_PORT") ?: "3306") . ";dbname=" . getenv("DB_DATABASE"),
                getenv("DB_USERNAME"),
                getenv("DB_PASSWORD") ?: ""
            );
            $prefix = getenv("DB_PREFIX") ?: "ti_";
            $stmt = $pdo->query("SHOW TABLES LIKE " . $pdo->quote($prefix . "migrations"));
            exit($stmt && $stmt->fetch() ? 0 : 1);
        } catch (Throwable $e) {
            exit(1);
        }
    '
}

run_install_if_needed() {
    if [ "${SKIP_INSTALL:-false}" = "true" ]; then
        echo "SKIP_INSTALL=true — pulando igniter:install."
        return 0
    fi

    if is_installed; then
        echo "TastyIgniter ja instalado no banco — pulando igniter:install."
        return 0
    fi

    echo "Executando php artisan igniter:install --no-interaction..."
    php artisan igniter:install --no-interaction
    echo "Instalacao concluida."
    echo "Admin padrao do seeder: usuario=admin senha=123456 (altere apos o primeiro login)."
}

# queue / scheduler: esperam o app principal criar os arquivos
if [ "$1" != "php-fpm" ]; then
    wait_for_mysql
    wait_for_app_files
    exec "$@"
fi

wait_for_mysql
ensure_app
configure_env
ensure_permissions
run_install_if_needed
ensure_permissions

exec docker-php-entrypoint "$@"
