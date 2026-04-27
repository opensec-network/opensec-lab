# OpenSec Lab — Plan 1: Limpieza del Catálogo

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar CTFd, crAPI, Portainer y BookStack del repositorio — dejar el lab limpio, funcional y con tests pasando.

**Architecture:** Ediciones quirúrgicas en `docker-compose.yml`, `opensec-lab.sh`, `config/defaults.env`, `services/dns/configure_dns.sh`, las reglas de Wazuh/Suricata y los tests estáticos. Sin nuevos servicios — solo remoción.

**Tech Stack:** Bash, Docker Compose YAML, XML (Wazuh rules), Suricata rules DSL.

**Spec de referencia:** `docs/superpowers/specs/2026-04-27-lab-redesign-design.md`

---

## Mapa de archivos

| Acción | Archivo |
|--------|---------|
| Modificar | `docker-compose.yml` |
| Modificar | `opensec-lab.sh` |
| Modificar | `config/defaults.env` |
| Modificar | `.env.example` |
| Modificar | `services/dns/configure_dns.sh` |
| Modificar | `services/wazuh/rules/openseclab.xml` |
| Modificar | `services/suricata/rules/openseclab.rules` |
| Modificar | `tests/static.sh` |
| Eliminar | `services/wiki/` (directorio completo) |
| Eliminar | `services/portainer/` (directorio completo) |

---

## Task 1: Eliminar servicios crAPI, Portainer y BookStack de docker-compose.yml

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Paso 1: Eliminar los 7 servicios de crAPI**

Eliminar completamente los bloques de estos `container_name` del archivo:
`opsn-crapi-mongo`, `opsn-crapi-postgres`, `opsn-crapi-mailhog`, `opsn-crapi-identity`, `opsn-crapi-community`, `opsn-crapi-workshop`, `opsn-crapi`

El bloque a eliminar va desde el comentario `# crAPI` hasta (no inclusive) el comentario `# Portainer`.

- [ ] **Paso 2: Eliminar los 2 servicios de Portainer**

Eliminar los bloques de `opsn-portainer` y `opsn-portainer-init`.

- [ ] **Paso 3: Eliminar los 3 servicios de BookStack**

Eliminar los bloques de `opsn-wiki-db`, `opsn-wiki` y `opsn-wiki-init`.

- [ ] **Paso 4: Eliminar los volumes huérfanos**

En la sección `volumes:` al inicio del archivo, eliminar estas 5 líneas:

```yaml
  opsn_crapi_data:
  opsn_crapi_postgres:
  opsn_portainer_data:
  opsn_wiki_db:
  opsn_wiki_data:
```

- [ ] **Paso 5: Verificar sintaxis del compose**

```bash
cp config/defaults.env .env
docker compose config --quiet
echo "Exit code: $?"
rm .env
```

Resultado esperado: sin errores, exit code 0.

- [ ] **Paso 6: Commit**

```bash
git add docker-compose.yml
git commit -m "chore: remove crAPI, Portainer and BookStack from docker-compose"
```

---

## Task 2: Actualizar SERVICES_CATALOG y SERVICE_RAM_MB en opensec-lab.sh

**Files:**
- Modify: `opensec-lab.sh`

- [ ] **Paso 1: Actualizar SERVICES_CATALOG**

Reemplazar el bloque `declare -a SERVICES_CATALOG=(` con:

```bash
declare -a SERVICES_CATALOG=(
    "opsn-dns|Servidor DNS (Technitium)|yes|"
    "opsn-mail|Servidor de correo + Roundcube webmail|yes|opsn-dns"
    "opsn-gophish|GoPhish — framework de phishing con campaña pre-configurada|yes|opsn-dns opsn-mail"
    "opsn-desktop|Escritorio XFCE con Thunderbird pre-configurado|yes|opsn-dns"
    "opsn-dvwa|DVWA — aplicación web vulnerable|no|"
    "opsn-juice-shop|OWASP Juice Shop|no|"
    "opsn-webgoat|WebGoat — plataforma de aprendizaje guiado OWASP|no|"
    "opsn-gitea|Gitea — repos con código vulnerable para análisis estático|yes|"
    "opsn-portal|Portal central — dashboard con links a todos los servicios|yes|"
    "opsn-wazuh|Wazuh SIEM + Suricata IDS — Blue Team (8+ GB RAM)|yes|opsn-dns opsn-suricata"
)
```

- [ ] **Paso 2: Actualizar SERVICE_RAM_MB**

Reemplazar el bloque `declare -A SERVICE_RAM_MB=(` con:

```bash
declare -A SERVICE_RAM_MB=(
    ["opsn-dns"]=200
    ["opsn-mail"]=300
    ["opsn-gophish"]=200
    ["opsn-desktop"]=500
    ["opsn-dvwa"]=200
    ["opsn-juice-shop"]=300
    ["opsn-webgoat"]=400
    ["opsn-gitea"]=200
    ["opsn-portal"]=50
    ["opsn-wazuh"]=2500
)
```

- [ ] **Paso 3: Actualizar META_PROFILES**

Reemplazar el bloque `declare -A META_PROFILES=(` con:

```bash
declare -A META_PROFILES=(
    ["B"]="opsn-wazuh opsn-suricata"
    ["V"]="opsn-dvwa opsn-juice-shop opsn-webgoat"
    ["C"]="opsn-dvwa opsn-juice-shop opsn-webgoat opsn-portal"
    ["F"]="opsn-dns opsn-mail opsn-gophish opsn-desktop opsn-dvwa opsn-juice-shop opsn-webgoat opsn-gitea opsn-portal opsn-wazuh opsn-suricata"
)
```

- [ ] **Paso 4: Limpiar mostrar_credenciales()**

En la función `mostrar_credenciales()`, buscar y eliminar los bloques que muestren credenciales de: Portainer, BookStack (wiki), CTFd.
Mantener: DNS, Mail, GoPhish, Desktop, DVWA, Juice Shop, WebGoat, Gitea, Wazuh.

- [ ] **Paso 5: Verificar sintaxis del script**

```bash
bash -n opensec-lab.sh
echo "Exit code: $?"
```

Resultado esperado: exit code 0, sin errores.

- [ ] **Paso 6: Commit**

```bash
git add opensec-lab.sh
git commit -m "chore: remove crAPI, Portainer, BookStack from service catalog and meta-profiles"
```

---

## Task 3: Limpiar config/defaults.env y .env.example

**Files:**
- Modify: `config/defaults.env`
- Modify: `.env.example`

- [ ] **Paso 1: Eliminar variables de crAPI, Portainer y BookStack en defaults.env**

Eliminar estas líneas del archivo `config/defaults.env`:

```bash
# Líneas a eliminar — Tier 1 (crAPI y Portainer):
OPSN_CRAPI_PORT=8025
OPSN_PORTAINER_PORT=9443
OPSN_PORTAINER_PASSWORD=Password1234

# Líneas a eliminar — Tier 2 (BookStack):
OPSN_WIKI_PORT=6875
OPSN_WIKI_PASSWORD=Password
OPSN_WIKI_DB_PASSWORD=wiki_db_password
OPSN_WIKI_APP_KEY=base64:rmMpNWdjxGApnthwA70jRrCQFJSkbuwY7W7rncXLCws
OPSN_WIKI_TOKEN_ID=opsn_init_id_placeholder
OPSN_WIKI_TOKEN_SECRET=opsn_init_secret_placeholder
```

- [ ] **Paso 2: Aplicar los mismos cambios en .env.example**

Abrir `.env.example` y eliminar las mismas variables que en el paso anterior.

- [ ] **Paso 3: Verificar que las variables restantes sean coherentes**

```bash
grep -E "^OPSN_" config/defaults.env | sort
```

La salida no debe contener ninguna línea con `CRAPI`, `PORTAINER`, `WIKI`.

- [ ] **Paso 4: Commit**

```bash
git add config/defaults.env .env.example
git commit -m "chore: remove crAPI, Portainer and BookStack env vars from defaults"
```

---

## Task 4: Limpiar configure_dns.sh

**Files:**
- Modify: `services/dns/configure_dns.sh`

- [ ] **Paso 1: Eliminar resoluciones de IP para crAPI, Portainer y wiki**

Eliminar estas 3 líneas del bloque de resoluciones al inicio del script:

```bash
CRAPI_IP=$(resolve_host "opsn-crapi")
PORTAINER_IP=$(resolve_host "opsn-portainer")
WIKI_IP=$(resolve_host "opsn-wiki")
```

- [ ] **Paso 2: Eliminar los bloques de registro DNS correspondientes**

Eliminar los 3 bloques condicionales que agregan registros para crapi, portainer y wiki:

```bash
# Eliminar este bloque:
if [ -n "$CRAPI_IP" ]; then
    add_dns_record "A"  "crapi"    "$CRAPI_IP"      ""            "$TTL"
else
    echo "  (crapi omitido — opsn-crapi no está corriendo)" >> /proc/1/fd/1
fi

# Eliminar este bloque:
if [ -n "$PORTAINER_IP" ]; then
    add_dns_record "A"  "portainer" "$PORTAINER_IP" ""            "$TTL"
else
    echo "  (portainer omitido — opsn-portainer no está corriendo)" >> /proc/1/fd/1
fi

# Eliminar este bloque:
if [ -n "$WIKI_IP" ]; then
    add_dns_record "A"  "wiki"      "$WIKI_IP"       ""            "$TTL"
else
    echo "  (wiki omitido — opsn-wiki no está corriendo)" >> /proc/1/fd/1
fi
```

- [ ] **Paso 3: Verificar sintaxis**

```bash
bash -n services/dns/configure_dns.sh
echo "Exit code: $?"
```

Resultado esperado: exit code 0.

- [ ] **Paso 4: Commit**

```bash
git add services/dns/configure_dns.sh
git commit -m "chore: remove crAPI, Portainer and wiki DNS records"
```

---

## Task 5: Limpiar reglas Wazuh — eliminar CTF y crAPI

**Files:**
- Modify: `services/wazuh/rules/openseclab.xml`

- [ ] **Paso 1: Eliminar el grupo de reglas crAPI (100040 y 100041)**

Eliminar el bloque completo que comienza con `<!-- ══ crAPI` hasta el cierre del segundo `</rule>` de crAPI:

```xml
<!-- Eliminar este bloque completo: -->
  <!-- ══ crAPI ═════════════════════════════════════════════════════════ -->

  <rule id="100040" level="10">
    <if_sid>31108</if_sid>
    <url>/community/api/v2/vehicle</url>
    <description>OpenSecLab: Posible BOLA/IDOR en crAPI (acceso a vehiculo de otro usuario)</description>
    <group>attack,idor,openseclab_crapi,</group>
    <mitre>
      <id>T1078</id>
    </mitre>
  </rule>

  <rule id="100041" level="8">
    <if_sid>31108</if_sid>
    <url>/identity/api/v2/user/dashboard</url>
    <description>OpenSecLab: Acceso al dashboard de usuario en crAPI (Excessive Data Exposure)</description>
    <group>openseclab_crapi,</group>
    <mitre>
      <id>T1078</id>
    </mitre>
  </rule>
```

- [ ] **Paso 2: Eliminar la regla CTF (100060)**

Eliminar el bloque completo:

```xml
  <!-- ══ CTF — Actividad de flag hunting ════════════════════════════ -->

  <rule id="100060" level="4">
    <if_sid>31108</if_sid>
    <match>OPSN{</match>
    <description>OpenSecLab: Posible flag CTF encontrado en trafico HTTP</description>
    <group>openseclab_ctf,</group>
  </rule>
```

- [ ] **Paso 3: Eliminar referencia CTF de la regla 100001**

La descripción de la regla 100001 contiene un flag CTF embebido. Reemplazarla:

```xml
<!-- Antes: -->
<description>OpenSecLab: Posible SQL Injection en DVWA (/vulnerabilities/sqli) — CTF: OPSN{su1c4t4_sql_1nj3ct10n_d3t3ct3d}</description>

<!-- Después: -->
<description>OpenSecLab: Posible SQL Injection en DVWA (/vulnerabilities/sqli)</description>
```

- [ ] **Paso 4: Verificar que el XML es válido**

```bash
xmllint --noout services/wazuh/rules/openseclab.xml
echo "Exit code: $?"
```

Si `xmllint` no está disponible en la máquina local: `brew install libxml2` (macOS) o `apt install libxml2-utils` (Linux).
Resultado esperado: exit code 0, sin errores.

- [ ] **Paso 5: Commit**

```bash
git add services/wazuh/rules/openseclab.xml
git commit -m "chore: remove CTF and crAPI rules from Wazuh"
```

---

## Task 6: Limpiar reglas Suricata — eliminar CTF y crAPI

**Files:**
- Modify: `services/suricata/rules/openseclab.rules`

- [ ] **Paso 1: Eliminar las reglas de crAPI (SIDs 9000040 y 9000041)**

Eliminar el bloque completo:

```
# ══ crAPI ═══════════════════════════════════════════════════════════

alert http $EXTERNAL_NET any -> $HTTP_SERVERS $HTTP_PORTS ( \
    msg:"OpenSecLab - Posible BOLA/IDOR en crAPI (vehiculos)"; \
    flow:established,to_server; \
    http.uri; content:"/community/api/v2/vehicle"; \
    classtype:attempted-user; \
    sid:9000040; rev:1;)

alert http $EXTERNAL_NET any -> $HTTP_SERVERS $HTTP_PORTS ( \
    msg:"OpenSecLab - Acceso al dashboard de usuario en crAPI"; \
    flow:established,to_server; \
    http.uri; content:"/identity/api/v2/user/dashboard"; \
    classtype:policy-violation; \
    sid:9000041; rev:1;)
```

- [ ] **Paso 2: Eliminar las reglas CTF (SIDs 9000052 y 9000060)**

Eliminar el bloque completo:

```
# ══ CTF — Flag hunting ══════════════════════════════════════════════

alert dns any any -> $DNS_SERVERS 53 ( \
    msg:"OpenSecLab - Consulta DNS al registro flag del CTF"; \
    dns.query; content:"flag.opensec.lab"; \
    classtype:policy-violation; \
    sid:9000052; rev:1;)

alert http $HOME_NET any -> $HTTP_SERVERS $HTTP_PORTS ( \
    msg:"OpenSecLab - Respuesta HTTP contiene un flag CTF"; \
    flow:established,to_client; \
    http.response_body; content:"OPSN{"; \
    classtype:policy-violation; \
    sid:9000060; rev:1;)
```

- [ ] **Paso 3: Eliminar referencia CTF del mensaje de Juice Shop score-board**

```
# Antes:
msg:"OpenSecLab - Acceso al Score Board de Juice Shop (CTF discovery)";

# Después:
msg:"OpenSecLab - Acceso al Score Board de Juice Shop (descubrimiento de ruta oculta)";
```

- [ ] **Paso 4: Commit**

```bash
git add services/suricata/rules/openseclab.rules
git commit -m "chore: remove CTF and crAPI rules from Suricata"
```

---

## Task 7: Eliminar directorios services/wiki/ y services/portainer/

**Files:**
- Delete: `services/wiki/` (directorio completo)
- Delete: `services/portainer/` (directorio completo)

- [ ] **Paso 1: Eliminar los directorios**

```bash
rm -rf services/wiki services/portainer
```

- [ ] **Paso 2: Verificar que no quedan referencias a esos paths en archivos activos**

```bash
grep -r "services/wiki\|services/portainer" \
  opensec-lab.sh opensec-lab-local.sh Makefile \
  .github/workflows/release.yml \
  .github/workflows/build-mail.yml \
  tests/static.sh 2>/dev/null
```

Resultado esperado: sin coincidencias. Si aparece alguna, eliminar la referencia encontrada.

- [ ] **Paso 3: Commit**

```bash
git add -A services/wiki services/portainer
git commit -m "chore: delete services/wiki and services/portainer directories"
```

---

## Task 8: Actualizar tests/static.sh

**Files:**
- Modify: `tests/static.sh`

- [ ] **Paso 1: Eliminar assertions de directorios eliminados**

Eliminar estas dos líneas:

```bash
assert_dir_exists "services/wiki"      "services/wiki"
assert_dir_exists "services/portainer"  "services/portainer"
```

- [ ] **Paso 2: Eliminar assertions de archivos eliminados**

Eliminar estas líneas:

```bash
assert_file_exists "services/wiki/bookstack-init.sh"           "services/wiki/bookstack-init.sh"
assert_file_exists "services/wiki/configure_wiki.sh"           "services/wiki/configure_wiki.sh"
assert_file_exists "services/portainer/configure_portainer.sh"    "services/portainer/configure_portainer.sh"
```

- [ ] **Paso 3: Eliminar scripts eliminados del bloque de sintaxis**

En el bucle `for script in \`, eliminar estas líneas:

```bash
    services/wiki/bookstack-init.sh \
    services/wiki/configure_wiki.sh \
    services/portainer/configure_portainer.sh \
```

- [ ] **Paso 4: Actualizar la sección "Variables de entorno"**

Reemplazar el bloque `# Tier 1` y `# Tier 2` con:

```bash
# Tier 1
for var in OPSN_WEBGOAT_PORT; do
    assert_env_var "defaults.env (Tier 1)" "$DEFAULTS" "$var"
done

# Tier 2
for var in OPSN_GITEA_PORT OPSN_GITEA_SSH_PORT OPSN_GITEA_PASSWORD \
           OPSN_PORTAL_PORT; do
    assert_env_var "defaults.env (Tier 2)" "$DEFAULTS" "$var"
done
```

- [ ] **Paso 5: Actualizar la sección "Docker Compose — estructura"**

Reemplazar el bucle `for service in` con:

```bash
for service in opsn-dns opsn-dvwa opsn-juice-shop opsn-webgoat \
               opsn-gophish opsn-desktop opsn-mail \
               opsn-gitea opsn-gitea-init \
               opsn-portal opsn-portal-init; do
    assert_file_contains "compose tiene $service" "$COMPOSE" "container_name: $service"
done
```

- [ ] **Paso 6: Actualizar el bucle de volumes**

Reemplazar el bucle `for vol in` con:

```bash
for vol in opsn_dns_data opsn_dvwa_data opsn_gophish_data opsn_mail_data \
           opsn_gitea_data opsn_portal_html; do
    assert_file_contains "compose volumen $vol" "$COMPOSE" "${vol}:"
done
```

- [ ] **Paso 7: Eliminar assertions de CTF flags**

Eliminar estos dos bloques completos:

```bash
# Eliminar:
assert_file_contains \
    "GoPhish landing page" \
    "services/gophish/templates/landing_page.html" \
    "OPSN{ph1sh1ng_aw4r3n3ss_ch4ll3ng3}"

assert_file_contains \
    "Gitea — flag flask-app" \
    "services/gitea/configure_gitea.sh" \
    "OPSN{c0d3_r3v13w_vuln_f0und}"

assert_file_contains \
    "Gitea — flag insecure-api" \
    "services/gitea/configure_gitea.sh" \
    "OPSN{4p1_s3cur1ty_r3v13w}"
```

- [ ] **Paso 8: Actualizar la sección "release.yml — servicios empaquetados"**

Reemplazar el bucle `for svc in`:

```bash
for svc in dns mail desktop gophish gitea portal; do
    assert_file_contains "release.yml incluye $svc" "$RELEASE" "$svc"
done
```

- [ ] **Paso 9: Actualizar la sección "Makefile — targets"**

Reemplazar el bucle `for svc in`:

```bash
for svc in gitea portal; do
    assert_file_contains "Makefile SERVICES incluye $svc" "Makefile" "$svc"
done
```

- [ ] **Paso 10: Eliminar assertions de idempotencia de wiki y portainer**

Eliminar estos dos bloques:

```bash
# Eliminar:
assert_file_contains \
    "configure_wiki.sh — guard idempotencia (book exists)" \
    "services/wiki/configure_wiki.sh" \
    "ya existe"

assert_file_contains \
    "configure_portainer.sh — guard idempotencia (ya existe)" \
    "services/portainer/configure_portainer.sh" \
    "ya existe"
```

- [ ] **Paso 11: Ejecutar los tests y verificar que pasan**

```bash
bash tests/static.sh
```

Resultado esperado: todos los tests pasan, 0 fallos. Si falla alguno, corregir la causa antes de continuar.

- [ ] **Paso 12: Commit final de limpieza**

```bash
git add tests/static.sh
git commit -m "test: update static tests after crAPI/Portainer/BookStack removal"
```

---

## Task 9: Actualizar Makefile

**Files:**
- Modify: `Makefile`

- [ ] **Paso 1: Leer el Makefile para identificar las referencias a eliminar**

```bash
grep -n "wiki\|portainer\|crapi\|ctfd" Makefile
```

- [ ] **Paso 2: Eliminar wiki, portainer de la variable SERVICES**

En la variable `SERVICES` del Makefile, eliminar `wiki portainer` (o los nombres exactos que aparezcan con esos prefijos).

- [ ] **Paso 3: Verificar que make validate sigue funcionando**

```bash
make validate
```

Resultado esperado: sin errores.

- [ ] **Paso 4: Commit**

```bash
git add Makefile
git commit -m "chore: remove wiki and portainer from Makefile SERVICES"
```

---

## Task 10: Actualizar .github/workflows/release.yml

**Files:**
- Modify: `.github/workflows/release.yml`

- [ ] **Paso 1: Eliminar wiki y portainer de la lista de servicios empaquetados**

Localizar la línea:
```
for svc in dns mail desktop gophish wiki gitea portal portainer wazuh suricata; do
```

Reemplazarla con:
```
for svc in dns mail desktop gophish gitea portal wazuh suricata; do
```

- [ ] **Paso 2: Eliminar las filas de la tabla de assets en el release body**

Eliminar las dos líneas:
```
            | `opsn-wiki.tar.gz` | Scripts de configuracion BookStack |
            | `opsn-portainer.tar.gz` | Script de configuracion de Portainer |
```

- [ ] **Paso 3: Verificar sintaxis YAML del workflow**

```bash
grep -c "wiki\|portainer" .github/workflows/release.yml
```

Resultado esperado: `0` — sin referencias restantes.

- [ ] **Paso 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "chore: remove wiki and portainer from release workflow"
```

---

## Verificación final del Plan 1

- [ ] **Ejecutar todos los tests estáticos**

```bash
bash tests/static.sh
```

Resultado esperado: 0 fallos.

- [ ] **Validar compose con defaults**

```bash
cp config/defaults.env .env && docker compose config --quiet && rm .env
echo "Exit code: $?"
```

Resultado esperado: exit code 0.

- [ ] **Verificar que no quedan referencias huérfanas a los servicios eliminados**

```bash
grep -r "crapi\|portainer\|bookstack\|opsn-wiki\b" \
  opensec-lab.sh docker-compose.yml config/defaults.env \
  services/dns/configure_dns.sh 2>/dev/null | grep -v "^Binary"
```

Resultado esperado: sin coincidencias (excepto comentarios de git).

---

**Fin del Plan 1.** Al completarlo, el lab funciona sin crAPI, Portainer y BookStack. Los tests pasan. El repositorio está listo para el Plan 2 (API vulnerable custom + MkDocs Material).
