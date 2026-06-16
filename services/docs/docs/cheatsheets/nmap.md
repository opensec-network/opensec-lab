# Cheat Sheet — nmap

Comandos esenciales para reconocimiento de red y descubrimiento de servicios.

> **Subred del lab:** Docker la asigna dinámicamente (no es fija). Obtén la real con
> `docker network inspect openseclab -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}'` y
> reemplaza `172.18.0.0/24` en los ejemplos por esa subred.

---

## Escaneo basico de puertos

```bash
nmap 172.18.0.0/24
```

## Escaneo rapido (top 100 puertos)

```bash
nmap -F 172.18.0.0/24
```

## Escaneo completo con deteccion de servicios

```bash
nmap -sV -sC -p- 172.18.0.0/24
```

Flags:
- `-sV` — detectar version del servicio
- `-sC` — ejecutar scripts NSE por defecto
- `-p-` — todos los puertos (1-65535)

## Escaneo sigiloso (SYN scan)

```bash
nmap -sS 172.18.0.0/24
```

## Guardar resultados

```bash
nmap -sV 172.18.0.0/24 -oN resultado.txt   # formato normal
nmap -sV 172.18.0.0/24 -oX resultado.xml   # formato XML
nmap -sV 172.18.0.0/24 -oA resultado       # los 3 formatos
```

## Escaneo del lab

La red Docker del lab usa la subred `172.18.0.0/16`. Las IPs de los contenedores son
asignadas dinamicamente — no asumir valores fijos.

```bash
# Descubrir todos los contenedores activos
nmap -sn 172.18.0.0/24

# Obtener la IP de un contenedor especifico
docker inspect opsn-dvwa --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
docker inspect opsn-api  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

# Escanear un contenedor usando su IP
DVWA_IP=$(docker inspect opsn-dvwa --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
nmap -sV "$DVWA_IP"
```

> Nota: Suricata detecta escaneos de puertos SYN con la regla SID 9000050.
