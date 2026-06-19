# Proxmox Test Harness

## Qué es

Harness de validación end-to-end para el instalador OSN. Prueba el script `opensec-lab.sh` sobre una VM Kali AMD64 limpia alojada en un Proxmox existente, usando la **API REST de Proxmox** para gestionar el ciclo de vida de la VM y **SSH al invitado** para ejecutar el instalador y correr los readiness checks.

El patrón es **template + clone**: se crea una sola vez un template dorado (VMID 9000) con la imagen cloud oficial de Kali, y cada ejecución de prueba clona ese template (VMID 9001), lo aprovisiona y lo destruye al final. El template nunca se toca después de creado.

La única operación que requiere SSH al host Proxmox es `build-template`. Todo el resto del ciclo — crear, arrancar, snapshot, rollback, destruir — va 100% por la API REST.

---

## Prerrequisitos (configuración única)

### 1. Token API Proxmox

Crear un token con **Privilege Separation desactivado** (o bien asignarle el rol `Administrator` explícitamente). Sin esto la API devuelve `Permission check failed` en operaciones como importar disco o gestionar snapshots.

Desde la UI de Proxmox: Datacenter → Permissions → API Tokens → Add.

Recomendado: token `root@pam!cicd` con Privilege Separation desactivado para el harness.

> Nota de seguridad: si el secreto del token se expone en algún momento, rótalo desde Datacenter → Permissions → API Tokens → seleccionar el token → Regenerate Secret. El valor en `config.env` nunca se commitea.

### 2. Llave SSH dedicada para el invitado

Generar una llave ED25519 sin passphrase específica para el harness:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/opsn-harness -N "" -C opsn-harness
```

Esta llave se inyecta vía cloud-init al crear la VM. La clave pública (`~/.ssh/opsn-harness.pub`) se lee directamente por el script.

### 3. Configuración local

```bash
cp config.env.example config.env
```

Abrir `config.env` y rellenar `PVE_TOKEN_SECRET` con el valor del token creado en el paso 1. Este archivo está en `.gitignore` y **nunca debe commitearse**.

Revisar también `VM_IP`, `VM_GW`, `VM_CIDR` y `VM_NAMESERVER` para que coincidan con tu red local.

---

## Preparación única del template

El comando `build-template` es el **único que usa SSH al host Proxmox** (como root). Descarga la imagen cloud de Kali, la extrae, importa el disco raw al storage y configura el template con cloud-init.

```bash
./proxmox-test-lab.sh build-template
```

Este paso se hace una sola vez. Después de creado el template (VMID `$TEMPLATE_ID`, por defecto 9000), no se vuelve a tocar.

---

## Flujo típico por prueba

```bash
# 1. Clonar el template y arrancar la VM (IP estática via cloud-init)
./proxmox-test-lab.sh create

# 2. Instalar Docker + dependencias base en la VM Kali
./proxmox-test-lab.sh provision

# 3. Snapshot del estado limpio (lab sin instalar, Docker listo)
./proxmox-test-lab.sh snapshot

# 4. Rollback + instalación headless del lab completo + reporte de métricas
./proxmox-test-lab.sh test

# 5. Correr los readiness checks de cada taller
./proxmox-test-lab.sh health

# 6. Imprimir URLs de acceso por IP
./proxmox-test-lab.sh urls

# 7. Rollback a clean-base para la próxima ronda de pruebas
./proxmox-test-lab.sh reset

# 8. Destruir la VM cuando ya no se necesita
./proxmox-test-lab.sh destroy
```

Los subcomandos `create`, `provision`, `snapshot`, `test`, `health`, `urls`, `reset` y `destroy` usan exclusivamente la API REST de Proxmox y SSH al invitado (VM 9001). No tocan el host Proxmox por SSH.

---

## Fallback de Docker en Kali

El script `get.docker.com` puede fallar en Kali porque usa el codename `rolling`, que no es un codename Debian estándar reconocido por el repositorio oficial de Docker.

Si `provision` falla al instalar Docker, el harness intenta el fallback automático desde los repositorios de Kali:

```bash
sudo apt-get install -y docker.io docker-compose-plugin
```

Este paquete está disponible en los repos de Kali y cubre los mismos casos de uso para el lab.

---

## Estructura de archivos

```
testing/proxmox/
├── config.env.example      # Template de configuración (versionado)
├── config.env              # Valores reales — NUNCA commitear (en .gitignore)
├── .gitignore
├── README.md
├── proxmox-test-lab.sh     # Script principal (orquestador de subcomandos)
├── lib/
│   └── pve-api.sh          # Helpers de la API REST de Proxmox + SSH al invitado
├── reports/                # Reportes de métricas versionados (*.md)
│   └── .gitkeep
└── output/                 # Artefactos en ejecución, p.ej. guía de usuario (gitignoreado)
```

---

## Variables de configuración clave

| Variable | Defecto | Descripción |
|---|---|---|
| `PVE_HOST` | `10.0.0.220` | IP del nodo Proxmox |
| `PVE_NODE` | `lab` | Nombre del nodo (minúscula, sensible a mayúsculas en la API) |
| `PVE_TOKEN_ID` | `root@pam!cicd` | ID del token API |
| `PVE_TOKEN_SECRET` | *(vacío)* | Secreto del token — rellenar en config.env |
| `PVE_STORAGE` | `local-lvm` | Storage lvmthin para el disco de la VM |
| `TEMPLATE_ID` | `9000` | VMID del template dorado de Kali |
| `VM_ID` | `9001` | VMID de la VM de prueba |
| `VM_IP` | `10.0.0.50` | IP estática del invitado (ajustar a tu red) |
| `CLEAN_SNAPSHOT` | `clean-base` | Nombre del snapshot limpio para rollback |

---

## Generacion de reportes

El subcomando `test` guarda un reporte Markdown con métricas de instalación en `reports/`. Los reportes **son versionados** — `reports/*.md` no está en `.gitignore` — para tener un historial de métricas entre releases.

`output/` contiene artefactos temporales de la ejecución (logs crudos, timing files) y está gitignoreado.
