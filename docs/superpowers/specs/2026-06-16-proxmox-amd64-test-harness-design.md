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
- Ejecución del instalador del lab desde el **repo local copiado** a la VM.
- Captura de métricas de consumo durante la instalación → reporte en Markdown.
- Validación opcional vía los `tests/<taller>-readiness.sh` existentes.

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
| `test`      | API + SSH | Revierte a `clean-base`, copia el repo local a la VM (rsync/scp), corre `opensec-lab.sh`, y **muestrea consumo** durante toda la instalación. Genera reporte. |
| `reset`     | API | `qm rollback` a `clean-base` para la siguiente prueba. |
| `validate`  | SSH guest | Corre los `tests/<taller>-readiness.sh` del repo dentro de la VM (opcional). |
| `ssh`       | SSH guest | Atajo para entrar a la VM Kali. |
| `destroy`   | API | Detiene y borra la VM por completo. |

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

Dos vías complementarias tras `test`:
- **Automática:** subcomando `validate` corre los `tests/<taller>-readiness.sh`
  existentes dentro de la VM vía SSH.
- **Manual:** el usuario abre su navegador hacia `VM_IP:<puertos>` / el portal
  (`8443`) para inspección visual de los servicios.

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
- `test` revierte a limpio, instala el lab desde el repo local, y produce un reporte
  de métricas sin intervención manual.
- `reset` devuelve la VM al estado limpio de forma fiable.
- El script no usa SSH al host Proxmox en ningún momento (solo API).
- Todo corre con **un comando por paso** desde la Mac.

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
| Instalador en `test` | Repo local copiado a la VM | Probar el código actual sin depender de dominio/release. |
| Monitoreo de consumo | Muestreador + reporte versionado | Estadísticas precisas e histórico. |
