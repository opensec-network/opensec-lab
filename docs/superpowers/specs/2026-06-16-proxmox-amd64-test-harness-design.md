# Diseño: Harness de pruebas AMD64 en Proxmox

**Fecha:** 2026-06-16
**Estado:** Aprobado (diseño) — pendiente de plan de implementación

---

## 1. Objetivo

Crear un entorno **limpio, repetible y automatizado** en AMD64 (Kali Linux) sobre
un host Proxmox existente, para validar que el instalador del lab OSN
(`opensec-lab.sh`) y toda su funcionalidad (servicios, talleres, ruta
ataque→detección) funcionan correctamente fuera del entorno de desarrollo
macOS/ARM.

El harness simula lo que haría un usuario real: parte de un Kali limpio, corre el
instalador, y verifica que el lab levanta. Entre pruebas se revierte a un snapshot
limpio para repetir desde un estado idéntico. Además captura **métricas de consumo
real** (CPU/RAM/disco) de la instalación.

Resuelve el pendiente documentado en `CLAUDE.md`:
> "Verificar la ruta en AMD64/Kali (todo se probó en macOS/ARM)"

---

## 2. Alcance

**Incluye:**
- Script único en bash que orquesta todo el ciclo de vida de la VM de prueba.
- Creación de la VM vía **API de Proxmox** (token con scope, sin SSH al hipervisor).
- Provisión de la VM Kali vía **SSH al guest** (Docker + dependencias).
- Snapshot de estado limpio y revert entre pruebas.
- Ejecución del instalador del lab desde el **repo local copiado** a la VM,
  instalando **el lab completo** (los 12 servicios) de forma no interactiva.
- Captura de métricas de consumo durante la instalación → reporte en Markdown.
- **Validación manual** (la conduce el usuario) y **validación automatizada por
  navegador** (la conduce Claude con Claude-in-Chrome): smoke de todos los
  servicios + recorrido end-to-end de los 4 talleres.
- Generación de **guía de usuario paso a paso (con screenshots)** y **reporte QA
  de hallazgos** a partir del recorrido automatizado.
- Health checks rápidos vía los `tests/<taller>-readiness.sh` existentes.

**No incluye (YAGNI):**
- Instalación/configuración del host Proxmox (ya existe).
- Múltiples VMs en paralelo o plantillas clonables (decidimos snapshot + revert).
- Uso de la URL pública `lab.opensec.network/install` (pendiente de dominio/release;
  se podrá agregar después como modo alterno).
- Terraform/Ansible (se eligió bash por simplicidad y coherencia con el repo).

---

## 3. Arquitectura: dos credenciales, dos destinos

El flujo separa explícitamente dos conexiones:

```
[Mac dev] --token API--> [Host Proxmox]  : crea VM Kali + inyecta llave SSH (cloud-init)
[Mac dev] --SSH--------> [VM Kali guest]  : instala Docker, corre instalador, mide consumo
```

| Credencial | Destino | Para qué |
|---|---|---|
| **Token API (con scope)** | Host Proxmox | Ciclo de vida de la VM: crear, configurar cloud-init, snapshot, rollback, destruir. |
| **Llave SSH** | VM Kali invitada | Provisión y pruebas dentro del guest. Se inyecta vía cloud-init al crear la VM. |

**Nunca** se usa SSH al hipervisor. El token API maneja el host; la llave SSH solo
toca el Kali invitado.

### Punto de fricción conocido
Importar la imagen cloud de Kali como disco de la VM es trivial con `qm` (CLI) pero
requiere algo más de código vía API pura. Se resuelve una sola vez en el script
(descargar la imagen al storage del host vía endpoint de la API o, si el storage lo
permite, referenciarla al crear el disco). Esto es la única complejidad extra de
usar token API en lugar de `qm` sobre SSH, y no implica pérdida de capacidad.

---

## 4. Componente único: `proxmox-test-lab.sh`

Vive en `testing/proxmox/` dentro del repo. Un solo script con subcomandos:

| Subcomando | Conexión | Qué hace |
|---|---|---|
| `create`    | API | Descarga la imagen cloud de Kali al host (si no está cacheada), crea la VM (16 GB / 6 vCPU / 80 GB), configura cloud-init (usuario `kali`, llave SSH pública, **IP estática** de la LAN), arranca. |
| `provision` | SSH guest | Espera a que el SSH del Kali responda, instala: Docker CE + compose plugin, curl, git, yq, qemu-guest-agent. |
| `snapshot`  | API | `qm snapshot` → estado limpio **`clean-base`** (Kali + Docker, lab AÚN no instalado). |
| `test`      | API + SSH | Revierte a `clean-base`, copia el repo local a la VM (rsync/scp), corre `opensec-lab.sh` instalando **el lab completo** (todos los servicios) **de forma no interactiva**, y **muestrea consumo** durante toda la instalación. Genera reporte de métricas. |
| `reset`     | API | `qm rollback` a `clean-base` para la siguiente prueba. |
| `health`    | SSH guest | Corre los `tests/<taller>-readiness.sh` del repo dentro de la VM (chequeos rápidos, no navegador). |
| `urls`      | local | Imprime todas las URLs de acceso (`IP_VM:puerto` y nombres `*.opensec.lab`) para la prueba manual y la automatizada. |
| `hosts`     | local | Agrega/actualiza entradas `*.opensec.lab → IP_VM` en el `/etc/hosts` de la Mac (requiere sudo); idempotente y reversible. |
| `ssh`       | SSH guest | Atajo para entrar a la VM Kali. |
| `destroy`   | API | Detiene y borra la VM por completo. |

> **Nota sobre instalación no interactiva:** `opensec-lab.sh` usa un menú
> interactivo. El paso `test` debe seleccionar el lab completo sin intervención
> (p. ej. pre-sembrando `~/OpenSec_Lab/.active_profiles` con todos los servicios
> antes de invocarlo, o alimentando la entrada del menú). El mecanismo exacto se
> define en el plan de implementación.

**Flujo típico:**
```bash
# Una sola vez:
./proxmox-test-lab.sh create
./proxmox-test-lab.sh provision
./proxmox-test-lab.sh snapshot

# Cada vez que quieras probar:
./proxmox-test-lab.sh test       # revierte, instala, mide
./proxmox-test-lab.sh validate   # (opcional) corre readiness scripts
./proxmox-test-lab.sh reset      # vuelve a limpio para la próxima
```

---

## 5. Configuración: `testing/proxmox/config.env`

Sigue la convención de `config/defaults.env`. Plantilla versionada
(`config.env.example`); valores reales en `config.env` ignorado por git.

Variables clave:
- `PVE_HOST` — IP/hostname del host Proxmox.
- `PVE_NODE` — nombre del nodo Proxmox.
- `PVE_TOKEN_ID` / `PVE_TOKEN_SECRET` — credenciales del token API.
- `PVE_STORAGE` — storage destino para el disco de la VM.
- `VM_ID` — VMID de la VM de prueba.
- `VM_CORES=6`, `VM_MEM=16384`, `VM_DISK=80G`.
- `VM_IP` / `VM_GW` — IP estática y gateway en la LAN.
- `SSH_KEY_PUB` / `SSH_KEY_PRIV` — rutas a la llave SSH para el guest.
- `KALI_IMAGE_URL` — URL de la imagen `kali-linux-*-cloud-genericcloud-amd64`.

Se usa **IP estática** (vía cloud-init) para que el script sepa siempre la dirección
del guest sin depender del descubrimiento por DHCP/guest-agent.

---

## 6. Monitoreo de consumo (paso `test`)

Durante la instalación del lab, un muestreador ligero corriendo en el guest registra
cada N segundos (configurable, p. ej. 5 s): CPU, RAM usada, y disco usado.

Al terminar, el script genera un reporte en `testing/proxmox/reports/<fecha>.md` con:
- Duración total de la instalación.
- RAM pico y promedio.
- Delta de disco (antes vs. después).
- Tamaño total de imágenes Docker descargadas.
- `docker stats` por contenedor (snapshot al final).

Los reportes se versionan para tener histórico de consumo entre cambios del lab.

---

## 7. Validación de funcionalidad

Tres capas complementarias, de la más barata a la más rica:

### 7.1 Health checks (script, sin navegador)
El subcomando `health` corre los `tests/<taller>-readiness.sh` del repo dentro de
la VM vía SSH. Confirma rápido que los contenedores responden antes de gastar
tiempo en navegador.

### 7.2 Prueba manual (la conduce el usuario)
El usuario abre su navegador hacia las URLs que imprime `urls` (`IP_VM:puerto` o
los nombres `*.opensec.lab` si corrió `hosts`) y recorre el lab a mano. El harness
solo garantiza acceso; la exploración es del usuario.

### 7.3 Prueba automatizada por navegador (la conduce Claude)
Esta fase **no la hace el script** — la conduce Claude en sesión usando
**Claude-in-Chrome**, porque requiere criterio ("¿funciona?", "¿tiene sentido?")
y captura de pantallas para la guía.

**Acceso híbrido desde la Mac (todo factible sin orquestar dentro de la VM):**
- **Mac → VM por LAN:** la mayoría de servicios se acceden por `http(s)://IP_VM:puerto`
  (portal `8443`, DVWA `8080`, Juice Shop `3000`, WebGoat `8081`, API `8025`,
  GoPhish `3333`, Wazuh `5601`, Gitea `3002`, docs `4000`, Roundcube `8888`).
- **Nombres `*.opensec.lab`:** se resuelven desde la Mac vía `/etc/hosts` (subcomando
  `hosts`).
- **Flujos "dentro del lab" (DNS nativo, apps de escritorio como Thunderbird para
  phishing):** se operan dentro del **Webtop XFCE**, que es un servicio web en
  `IP_VM:3100` y por tanto también se maneja desde el navegador de la Mac.

**Cobertura:** smoke de **todos** los servicios (¿carga? ¿login? ¿1 acción clave?)
**más** recorrido **end-to-end de los 4 talleres**:
1. Web Hacking → firma de payload (Suricata)
2. API Breach to Detection → eventos estructurados (flagship)
3. Phishing → comportamiento (credential harvesting)
4. Kill Chain → correlación multi-señal

Cada taller incluye el lado ataque y la confirmación de **detección en Wazuh**.

> **Modularidad:** el recorrido se ejecuta **por taller** (uno por sesión si hace
> falta), no todo de una. Recorrer los 4 talleres completos es largo y costoso en
> tokens; segmentar mantiene cada sesión manejable. Claude registra qué talleres
> ya recorrió.

> **Precondiciones técnicas a verificar en implementación:** que Docker publique los
> puertos en `0.0.0.0` (no solo `127.0.0.1`) para que sean alcanzables por LAN, y
> manejo de certificados autofirmados en los servicios HTTPS (GoPhish, Wazuh,
> portal).

## 7.4 Artefactos generados

Del recorrido automatizado salen **dos documentos**:

1. **Guía de usuario paso a paso** (`testing/proxmox/output/user-guide.md` +
   screenshots) — redactada para el usuario final: cómo acceder y usar cada
   servicio y cómo completar cada taller, ilustrada con las capturas reales.
2. **Reporte QA de hallazgos** (`testing/proxmox/reports/qa-<fecha>.md`) — qué
   funciona, qué falla, qué confunde o "no tiene sentido", con severidad y
   ubicación, para que el usuario lo arregle.

---

## 8. Prerrequisitos manuales (una sola vez)

1. En el host Proxmox: crear un **token API con scope** para gestión de VMs y anotar
   `PVE_TOKEN_ID` + secreto.
2. En la Mac: generar/elegir una llave SSH y poner las rutas en `config.env`.
3. Rellenar `config.env` a partir de `config.env.example`.

No se requiere `ssh-copy-id` al host ni acceso root SSH al hipervisor.

---

## 9. Criterios de éxito ("done")

- `create` + `provision` + `snapshot` dejan una VM Kali AMD64 con Docker lista y un
  snapshot `clean-base`.
- `test` revierte a limpio, instala **el lab completo** desde el repo local de forma
  no interactiva, y produce un reporte de métricas sin intervención manual.
- `reset` devuelve la VM al estado limpio de forma fiable.
- El script no usa SSH al host Proxmox en ningún momento (solo API).
- Todos los servicios son alcanzables desde el navegador de la Mac (por IP y, con
  `hosts`, por nombre `*.opensec.lab`), incluido el Webtop en `:3100`.
- El recorrido automatizado por navegador cubre smoke de todos los servicios + los
  4 talleres y produce **guía de usuario** + **reporte QA**.
- Los pasos de infraestructura corren con **un comando por paso** desde la Mac.

---

## 10. Decisiones tomadas

| Decisión | Elección | Razón |
|---|---|---|
| Herramienta de automatización | Bash + API Proxmox + cloud-init | Simplicidad; coherente con el repo (todo bash). |
| SO de la VM | Kali Linux AMD64 (imagen cloud) | Máxima fidelidad a la audiencia objetivo. |
| Reutilización | Snapshot `clean-base` + revert | Probar el instalador repetidamente desde estado idéntico. |
| Recursos | 16 GB / 6 vCPU / 80 GB | Correr el lab completo (incl. Wazuh) cómodo. |
| Conexión al host | Token API con scope | Seguridad (sin root SSH al hipervisor), sin pérdida de capacidad. |
| Conexión al guest | Llave SSH vía cloud-init | Mejor herramienta para provisión y métricas. |
| Instalador en `test` | Repo local copiado a la VM, lab completo no interactivo | Probar el código actual sin depender de dominio/release. |
| Monitoreo de consumo | Muestreador + reporte versionado | Estadísticas precisas e histórico. |
| Validación por navegador | Claude-in-Chrome desde la Mac (híbrido LAN + Webtop) | Requiere criterio y screenshots; todo factible desde la Mac. |
| Cobertura del recorrido | Smoke de todos + 4 talleres end-to-end, por taller | Cobertura máxima; segmentar controla costo/tokens. |
| Salidas del recorrido | Guía de usuario + reporte QA | Documentar para el usuario y arreglar lo que falle. |
