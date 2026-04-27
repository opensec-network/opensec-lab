# Cheat Sheet — nmap

Comandos esenciales para reconocimiento de red y descubrimiento de servicios.

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

```bash
# Descubrir todos los contenedores activos
nmap -sn 172.18.0.0/24

# Ver puertos de un contenedor especifico
nmap -sV 172.18.0.3   # DVWA
nmap -sV 172.18.0.8   # API vulnerable
```

> Nota: Suricata detecta escaneos de puertos SYN con la regla SID 9000050.
