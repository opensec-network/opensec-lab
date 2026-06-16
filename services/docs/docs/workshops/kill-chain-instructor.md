# Guia de instructor: Kill Chain y Correlacion de Señales

Esta guia ayuda a facilitar el taller **Kill Chain y Correlacion de Señales** para una clase, meetup, equipo interno o practica individual supervisada. Es el taller mas avanzado de la ruta; conviene haber hecho antes el de Hacking Web.

## Resumen

- Duracion estimada: 40 a 60 minutos.
- Nivel: avanzado.
- Modo: cadena de ataque (recon + explotacion) desde la maquina atacante e investigacion correlacionada en Wazuh.
- Resultado: el estudiante ejecuta un kill chain de dos fases y reconstruye la cadena en Wazuh correlacionando señales por origen y tiempo, como un analista de SOC.

## Servicios requeridos

Minimo:

- `opsn-dvwa` (objetivo)
- `opsn-desktop` (maquina atacante con `nc`)
- `opsn-docs`

Recomendado para la parte defensiva:

- `opsn-wazuh`
- `opsn-suricata`
- `opsn-portal`

## Preparacion

1. Inicia los servicios requeridos.
2. Verifica que Suricata cargo sus reglas (ver Troubleshooting). Debe cargar `14 rules, 0 failed`.
3. Si usaras Wazuh, espera a que el dashboard responda en `https://localhost:5601` y el manager este indexando.
4. Ten a mano la IP interna de DVWA: `docker inspect opsn-dvwa -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'`.

### Punto critico: por que no se escanea `localhost`

Suricata inspecciona el bridge de la red Docker. Un escaneo a `localhost`/`127.0.0.1` viaja por el loopback del host y **no pasa por el bridge**, asi que Suricata no lo ve. El escaneo debe dirigirse a la **IP interna** del contenedor. La maquina atacante natural es `opsn-desktop` (siempre dentro de la red). En Kali Linux el host tambien alcanza las IPs Docker; en macOS/Windows, usa la terminal del Desktop. Explica esto a la clase: es una leccion real sobre donde "ve" un IDS.

## Credenciales

| Servicio | Usuario | Password | URL |
| --- | --- | --- | --- |
| Wazuh Dashboard | `admin` | `admin` | https://localhost:5601 |

## Evidencia esperada

| Fase | Comando | Firma Suricata | sid |
| --- | --- | --- | --- |
| Reconocimiento | `nc -z` a muchos puertos | `OpenSecLab - Escaneo de puertos SYN detectado` | `9000050` |
| Explotacion | `GET /vulnerabilities/sqli/?id=1' OR '1'='1` | `OpenSecLab - SQL Injection en DVWA` | `9000001` |

Ambas llegan a Wazuh con grupos `[ids, suricata]` y comparten `data.src_ip` (la maquina atacante). La correlacion clave: **mismo origen, secuencia recon → explotacion, mismo objetivo**.

El escaneo dispara por **umbral**: la firma `9000050` requiere 30 paquetes SYN del mismo origen en 5 segundos. Un `nc -z` a ~60 puertos lo supera con holgura.

## Temas de explicacion

### De una señal a una historia

Los talleres anteriores entrenan a detectar un evento. Este entrena a **conectar** eventos. Insiste en que el valor del SOC no esta en la alerta individual sino en la narrativa: un escaneo es ruido de fondo; un escaneo seguido de explotacion del servicio escaneado, del mismo origen, es un incidente.

### Deteccion por umbral

La firma de escaneo no busca un payload; cuenta comportamiento (muchos SYN). Explica el `threshold` de Suricata (`track by_src, count 30, seconds 5`) y su contraparte evasiva: el escaneo "low and slow" que se mantiene bajo el umbral. Esto motiva la deteccion por comportamiento agregado a largo plazo, no solo por umbrales cortos.

### Cortar la cadena temprano

El kill chain enseña que cada fase es una oportunidad de defensa, y que las fases tempranas (recon) son las mas baratas de detener. Una alerta de escaneo accionada a tiempo evita la explotacion.

## Troubleshooting

### El escaneo no dispara la firma 9000050

1. Confirma que escaneas la **IP interna** del contenedor, no `localhost` (ver "Punto critico" arriba).
2. Confirma el origen: el escaneo debe venir de un host en la red Docker (Desktop o Kali con ruta a las IPs Docker).
3. Verifica que se generan suficientes SYN: escanea al menos 30-60 puertos seguidos para superar el umbral.
4. Verifica que Suricata cargo la regla:

```bash
docker logs opsn-suricata 2>&1 | grep "rules successfully loaded"
docker exec opsn-suricata grep -c '"signature_id":9000050' /var/log/suricata/eve.json
```

> **Disco lleno = sintoma engañoso.** Si Suricata captura pero `eve.json` no crece, revisa el espacio del host: con el disco al ~100% Suricata no puede escribir el log y la deteccion parece "rota" sin estarlo. Libera con `docker builder prune -af`.

### El ataque SQLi no aparece

Confirma que apuntas al puerto 80 de la IP interna de DVWA. El patron de inyeccion debe viajar en la URL (`?id=1' OR '1'='1`). No requiere sesion para la deteccion.

### No correlacionan en Wazuh

Filtra por `data.src_ip: <IP_atacante>` y `rule.groups: suricata`, y amplia el rango de tiempo. Ordena ascendente por `@timestamp` para ver la secuencia. En entornos ARM/macOS la indexacion puede degradarse; la verificacion end-to-end se valida en AMD64.

## Reset antes de repetir

Usa la opcion **15) Reset del taller** del menu (`~/OpenSec_Lab/opensec-lab.sh`):
reinicia el lado azul y limpia las alertas del taller en Wazuh.

> Wazuh indexa con 1-3 min de retraso. Resetea entre grupos con margen, o corre el
> reset dos veces si lo haces inmediatamente tras la ultima corrida.
