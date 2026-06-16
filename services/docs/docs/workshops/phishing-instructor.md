# Guia de instructor: Phishing y Deteccion de Robo de Credenciales

Esta guia ayuda a facilitar el taller **Phishing y Deteccion de Robo de Credenciales** para una clase, meetup, equipo interno o practica individual supervisada.

## Resumen

- Duracion estimada: 30 a 45 minutos.
- Nivel: intermedio.
- Modo: campaña de phishing guiada (panel GoPhish + navegador/webmail) e investigacion en Wazuh.
- Resultado: el estudiante ejecuta una campaña de phishing completa, captura credenciales con una landing falsa y relaciona el robo con una firma de comportamiento de Suricata visible en Wazuh, correlacionando la cadena por origen.

## Servicios requeridos

Minimo:

- `opsn-gophish` (arrastra `opsn-dns` y `opsn-mail`)
- `opsn-docs`

Recomendado para la parte defensiva:

- `opsn-wazuh`
- `opsn-suricata`
- `opsn-portal`

Opcional, para encarnar a la victima:

- `opsn-desktop` (Thunderbird preconfigurado con `admin@opensec.lab`)

## Preparacion

1. Inicia los servicios requeridos. GoPhish crea y **lanza** la campaña `Acme Corp — Phishing Lab` automaticamente al arrancar (sidecar `opsn-gophish-init`).
2. Verifica que la campaña existe y envio correos: panel en `https://localhost:3333` (`admin`/`Password`) → **Campaigns**. La linea de tiempo debe mostrar `Email Sent` para ambos objetivos.
3. Verifica que Suricata cargo sus reglas (ver Troubleshooting).
4. Si usaras Wazuh, espera a que el dashboard responda en `https://localhost:5601` y el manager este indexando.

### Tiempo de calentamiento

GoPhish tarda unos segundos en configurarse tras arrancar; revisa `docker logs opsn-gophish-init` y espera la linea `Campaign creada y lanzada`. Suricata tarda hasta 2 minutos en cargar reglas; Wazuh, 2-5 minutos adicionales en indexar. Arranca con margen antes de la sesion.

## Credenciales

| Servicio | Usuario | Password | URL |
| --- | --- | --- | --- |
| GoPhish (panel) | `admin` | `Password` | https://localhost:3333 |
| Webmail (victima) | `admin@opensec.lab` | `Password` | http://localhost:8888 |
| Wazuh Dashboard | `admin` | `admin` | https://localhost:5601 |

## Evidencia esperada

| Fase | Donde se ve | Señal |
| --- | --- | --- |
| Envio del correo | GoPhish timeline | `Email Sent` |
| Apertura | GoPhish timeline | `Email Opened` |
| Clic en la landing | GoPhish timeline + Suricata | `Clicked Link` / `GET /?rid=...` |
| Envio de credenciales | GoPhish timeline + **Wazuh** | `Submitted Data` / alerta `9000070` |

La alerta defensiva clave:

| Firma Suricata | sid | Categoria | rule.id Wazuh |
| --- | --- | --- | --- |
| `OpenSecLab - Envio de credenciales en claro (posible credential harvesting)` | `9000070` | `Successful Credential Theft Detected` | `86601` / `100020` |

La alerta llega con grupos `[ids, suricata]`. La regla `100020` de OpenSec Lab eleva esa alerta a contexto de phishing (nivel 10, MITRE T1566 + T1056) cuando el ruleset base de Suricata esta completo.

## Temas de explicacion

### Deteccion por comportamiento vs. por firma de payload

En el taller de Hacking Web, la firma busca un *payload malicioso* (inyeccion SQL, `<script>`). Aqui no hay payload: un POST con `username` y `password` es trafico perfectamente normal. Lo que lo hace sospechoso es el **comportamiento y el contexto**: credenciales viajando por HTTP sin cifrar hacia una landing.

Punto clave para la clase: las firmas de comportamiento son de **alta sensibilidad** — generan señales para investigar, no veredictos. El valor esta en la correlacion, no en la alerta aislada.

### La correlacion como habilidad de analista

Una alerta de credential harvesting por si sola dice poco. El analista toma el `src_ip` y reconstruye la secuencia (acceso a la landing → envio de datos) del mismo origen. Es el mismo razonamiento que usaria un SOC real para confirmar un incidente de phishing. Dedica tiempo a este paso: es la diferencia entre "una alerta" y "una historia".

### Por que el IDS detecta sin los logs de GoPhish

GoPhish registra el comportamiento en su propia base de datos, no en Wazuh (el modulo docker-listener de Wazuh no es fiable para esto). La deteccion defensiva no depende de la cooperacion del atacante ni de su herramienta: Suricata ve el trafico en la red. En un incidente real no tendrias el panel del atacante; tendrias el trafico.

## Troubleshooting

### La campaña no existe o no envio correos

Revisa el sidecar de configuracion:

```bash
docker logs opsn-gophish-init 2>&1 | tail -20
```

Debe terminar en `Campaign creada y lanzada`. Si muestra `ERROR al crear la Campaign`, revisa que `opsn-mail` este `healthy` y reinicia `opsn-gophish`.

### El correo no llega al webmail

Verifica que `opsn-mail` esta corriendo y sano:

```bash
docker ps --format '{{.Names}} {{.Status}}' | grep opsn-mail
```

La campaña envia a `admin@opensec.lab` y `user@opensec.lab`. Inicia sesion en `http://localhost:8888` como `admin@opensec.lab`.

### Las firmas de Suricata no se disparan

Verifica cuantas reglas cargo Suricata:

```bash
docker logs opsn-suricata 2>&1 | grep "rules successfully loaded"
```

La salida esperada incluye `14 rules successfully loaded, 0 rules failed`. Si las reglas estan cargadas pero la firma no aparece, confirma que `SURICATA_INTERFACE` apunta al bridge real de la red Docker:

```bash
docker network inspect openseclab -f 'br-{{slice .Id 0 12}}'
```

> **Disco lleno = sintoma engañoso.** Si Suricata captura pero `eve.json` no crece, revisa el espacio del host: con el disco al ~100% Suricata no puede escribir el log y la deteccion parece "rota" sin estarlo. Libera con `docker builder prune -af`.

### No aparecen alertas en Wazuh

Confirma primero que Suricata firmo el evento en su log local:

```bash
docker exec opsn-suricata grep -c '"signature_id":9000070' /var/log/suricata/eve.json
```

Si hay firmas en Suricata pero no en Wazuh, el problema esta en la ingesta/indexacion. Filtra en Discover con `rule.groups: suricata` y amplia el rango de tiempo. En entornos ARM/macOS la indexacion puede degradarse; la verificacion end-to-end de indexacion se valida en AMD64.

## Reset antes de repetir

Usa la opcion **15) Reset del taller** del menu (`~/OpenSec_Lab/opensec-lab.sh`):
reinicia el lado azul y limpia las alertas del taller en Wazuh.

Para relanzar la campaña: elimina `Acme Corp — Phishing Lab` en el panel de GoPhish
y reinicia `opsn-gophish`; el sidecar la recrea y la lanza al arrancar.

> Wazuh indexa con 1-3 min de retraso. Resetea entre grupos con margen, o corre el
> reset dos veces si lo haces inmediatamente tras la ultima corrida.
