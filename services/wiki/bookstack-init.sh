#!/bin/bash
# services/wiki/bookstack-init.sh
# Script montado en /custom-cont-init.d/ del contenedor BookStack.
# Corre al inicio de BookStack (patron linuxserver.io igual que el Desktop).
# Objetivos:
#   1. Actualizar credenciales del admin
#   2. Crear un token de API conocido para el sidecar configure_wiki.sh

# Esperar a que las migraciones de base de datos esten listas
MAX_TRIES=20
TRIES=0
until php /app/www/artisan migrate:status > /dev/null 2>&1; do
    TRIES=$((TRIES + 1))
    [ $TRIES -ge $MAX_TRIES ] && echo "[!] Timeout esperando migraciones BookStack" && exit 0
    sleep 5
done

echo "[→] BookStack inicializado. Configurando credenciales y token de API..."

# Actualizar email y password del admin (usuario id=1) via DB facade
php /app/www/artisan tinker --execute="
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

\$password = getenv('OPSN_WIKI_PASSWORD') ?: 'Password';
\$domain   = getenv('OPSN_DOMAIN') ?: 'opensec.lab';

DB::table('users')->where('id', 1)->update([
    'email'    => 'admin@' . \$domain,
    'password' => Hash::make(\$password),
]);
echo 'Admin credentials updated' . PHP_EOL;

// Crear token de API para el sidecar de configuracion
// La columna es 'secret' (hash bcrypt); el sidecar usa el valor en texto plano
\$tokenId     = getenv('OPSN_WIKI_TOKEN_ID')     ?: 'opsn_init_id_placeholder';
\$tokenSecret = getenv('OPSN_WIKI_TOKEN_SECRET') ?: 'opsn_init_secret_placeholder';

\$exists = DB::table('api_tokens')->where('token_id', \$tokenId)->exists();
if (!\$exists) {
    DB::table('api_tokens')->insert([
        'user_id'    => 1,
        'name'       => 'opsn-automation',
        'token_id'   => \$tokenId,
        'secret'     => Hash::make(\$tokenSecret),
        'expires_at' => '2099-01-01',
        'created_at' => now(),
        'updated_at' => now(),
    ]);
    echo 'API token created' . PHP_EOL;
} else {
    echo 'API token already exists' . PHP_EOL;
}
" 2>/dev/null || echo "[!] artisan tinker fallo (BookStack puede no estar listo aun)"

echo "[✓] bookstack-init.sh completado."
