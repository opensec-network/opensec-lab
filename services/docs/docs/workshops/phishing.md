# Taller: Phishing y Deteccion de Robo de Credenciales

Este taller guia una campaña de phishing completa con GoPhish: enviar el correo cebo, conseguir que la victima haga clic en una landing falsa y entregue sus credenciales, y luego encontrar la evidencia que el IDS deja en la red y que llega a Wazuh.

La diferencia clave respecto a los otros talleres:

- El [taller de APIs](api-breach.md) detecta por **eventos estructurados** que escribe la aplicacion.
- El [taller de Hacking Web](web-hacking.md) detecta por **firma de payload**: un patron malicioso (inyeccion SQL, `<script>`, `../`) dentro del trafico.
- Aqui detectas por **comportamiento**: el envio de credenciales (usuario + contrasena) por HTTP sin cifrar. No hay un "payload de ataque" en el trafico; lo sospechoso es la *accion*. Una sola firma de alta sensibilidad marca el momento del robo, y el analista **correlaciona por origen** el trafico de contexto para reconstruir la cadena.

Para explorar GoPhish sin seguir el taller, lee la guia de servicio en [GoPhish](../services/gophish.md).

## Requisitos

- Servicio `opsn-gophish` iniciado (arrastra `opsn-dns` y `opsn-mail` como dependencias).
- Servicio `opsn-docs` iniciado para leer esta guia dentro del lab.
- Recomendado para deteccion: `opsn-wazuh` y `opsn-suricata`.
- Opcional, para vivir el rol de la victima: `opsn-desktop` (Thunderbird preconfigurado) o el webmail Roundcube.
- Terminal con `curl`.
- Puertos por defecto: GoPhish admin `3333`, landing de phishing `80`, webmail `8888`.

## Objetivos

Al terminar, debes poder explicar:

- Las fases de una campaña de phishing: envio, apertura, clic y envio de datos.
- Por que una landing falsa que captura credenciales por HTTP sin cifrar es un indicador de robo.
- Como un IDS de red detecta el robo de credenciales **sin** leer los logs de GoPhish ni del correo.
- Como un analista correlaciona por direccion de origen el trafico previo (acceso a la landing) con la alerta de envio de credenciales.
- Que mitigaciones (MFA, HTTPS, autenticacion de correo, concienciacion) reducen el riesgo.

## 1. Conocer la campaña preconfigurada

Al iniciar `opsn-gophish`, el lab crea y **lanza** automaticamente una campaña lista para usar:

| Recurso | Valor |
| --- | --- |
| Empresa simulada | Acme Corp |
| Campaña | `Acme Corp — Phishing Lab` |
| Asunto del correo | `Accion requerida: Restablece tu contrasena corporativa` |
| Objetivos | `admin@opensec.lab`, `user@opensec.lab` |
| Landing | pagina de "restablecer contrasena" que captura usuario y password |

Abre el panel de GoPhish en `https://localhost:3333` (usuario `admin`, password `Password`; acepta el certificado autofirmado). Entra en **Campaigns → Acme Corp — Phishing Lab**. Veras la linea de tiempo con los correos ya enviados (`Email Sent`).

## 2. El ataque desde la perspectiva de la victima

La parte ofensiva es lograr que la victima abra el correo, confie en el, haga clic y entregue sus credenciales.

### 2.1 Leer el correo cebo

Abre el webmail en `http://localhost:8888` e inicia sesion como la victima: `admin@opensec.lab` / `Password`. (Alternativa: en `opsn-desktop`, Thunderbird ya viene configurado con esta cuenta.)

Abre el correo de **Soporte IT** con el asunto de restablecimiento de contrasena. Observa las señales tipicas de phishing: urgencia, un remitente que aparenta ser interno y un boton que lleva a un dominio de aspecto corporativo.

### 2.2 Hacer clic en la landing

El boton del correo apunta a `http://gophish.opensec.lab/?rid=...`. El parametro `rid` identifica de forma unica a la victima: asi GoPhish sabe quien hizo clic. Copia ese enlace del correo (o abrelo en el navegador del `opsn-desktop`).

Para reproducirlo desde la terminal, sustituye `<RID>` por el valor de tu enlace:

```bash
RID="<RID>"   # pegalo del enlace del correo, p. ej. RID="gpqn1BB"
curl -s -o /dev/null "http://localhost/?rid=${RID}"
```

Esto registra el evento `Clicked Link` en GoPhish y carga la pagina falsa de login.

### 2.3 Entregar las credenciales

La landing pide usuario, contrasena actual y contrasena nueva. Al enviarlas, GoPhish las captura y registra `Submitted Data`. En el navegador puedes llenar el formulario; desde la terminal:

```bash
curl -s -o /dev/null "http://localhost/?rid=${RID}" \
  --data-urlencode "username=admin@opensec.lab" \
  --data-urlencode "password=Contrasena-Actual-123" \
  --data-urlencode "new_password=Contrasena-Nueva-456"
```

> Si solo quieres reproducir la **deteccion** sin una campaña valida, cualquier POST con `username` y `password` a la landing dispara la firma del IDS: el indicador es el *comportamiento* (envio de credenciales en claro), no el `rid`.

## 3. Ver el comportamiento en GoPhish

Vuelve a **Campaigns → Acme Corp — Phishing Lab**. La linea de tiempo de `admin@opensec.lab` ahora muestra la cadena completa:

```text
Email Sent → Email Opened → Clicked Link → Submitted Data
```

En **Submitted Data** veras las credenciales capturadas en claro. Esa es la perspectiva del atacante. Ahora cambia al lado defensivo: ¿como se ve esto en la red?

## 4. Investigar la deteccion en Wazuh

El envio de credenciales viajo por HTTP sin cifrar. Suricata, que inspecciona el trafico de la red Docker, lo identifica como **robo de credenciales** y entrega la alerta a Wazuh.

Abre **Wazuh Dashboard** (`https://localhost:5601`, `admin`/`admin`) → **Discover**, index pattern `wazuh-alerts-*`.

### 4.1 Encontrar la alerta de robo de credenciales

Filtra por la firma del taller:

```text
data.alert.signature_id: 9000070
```

Deberias ver la alerta:

| Firma Suricata | Que detecta |
| --- | --- |
| `OpenSecLab - Envio de credenciales en claro (posible credential harvesting)` | Un POST con `password=` y un identificador de usuario viajando por HTTP sin cifrar. |

> Todas las alertas de Suricata llegan a Wazuh con el grupo `[ids, suricata]`. Si el filtro por `signature_id` no devuelve nada, prueba `rule.groups: suricata` y busca la firma de credential harvesting en `data.alert.signature`.

### 4.2 Leer la alerta como analista

Abre la alerta y observa:

- `data.alert.signature` — la firma que disparo Suricata.
- `data.src_ip` — el origen del trafico: **la maquina de la victima** que entrego las credenciales.
- `data.dest_ip` y `data.dest_port` — la landing falsa (el servidor de phishing en el puerto 80).
- `data.alert.category` — `Successful Credential Theft Detected`.

### 4.3 Correlacionar la cadena (la habilidad clave)

Una sola alerta dice "alguien entrego credenciales en claro". Eso amerita investigar, no es una certeza. El analista reconstruye la historia tomando el `data.src_ip` de la alerta y buscando **todo el trafico de ese mismo origen** justo antes:

```text
data.src_ip: <IP_de_la_victima>
```

Ordena por tiempo y veras la secuencia: primero el acceso a la landing (`GET /?rid=...`), despues el envio de credenciales (`POST`). Esa correlacion origen + secuencia es lo que convierte una alerta aislada en un incidente de phishing confirmado.

### 4.4 Preguntas de analista

- ¿Por que el IDS detecta el robo sin acceso a los logs de GoPhish ni del servidor de correo? ¿Que ventaja da eso?
- La firma marca cualquier envio de credenciales por HTTP sin cifrar. ¿Por que es una señal de **alta sensibilidad** y no una certeza? ¿Que falsos positivos esperarias en una red real?
- Si la landing usara HTTPS, ¿seguiria viendo Suricata las credenciales? ¿Que tecnica defensiva haria falta entonces (pista: inspeccion TLS, deteccion en el endpoint)?

> Si las alertas no aparecen: Suricata puede tardar 1–2 minutos en cargar sus reglas al iniciar. Wazuh puede tardar 1–3 minutos en indexar. Repite la busqueda despues de esperar.

## Mitigaciones

### Contra el robo de credenciales por phishing

- **MFA (autenticacion multifactor):** aunque la victima entregue su contrasena, el atacante no completa el acceso sin el segundo factor.
- **HTTPS en todos los logins corporativos:** una pagina de login legitima nunca pide credenciales por HTTP sin cifrar; enseña a la gente a desconfiar del candado ausente.
- **Autenticacion de correo (SPF, DKIM, DMARC):** dificulta que un atacante suplante un remitente interno.
- **Filtrado de correo y reescritura de enlaces:** detona y analiza los enlaces antes de que lleguen al usuario.
- **Concienciacion:** simulacros de phishing como este entrenan a la gente a reconocer urgencia falsa y remitentes sospechosos.

### Del lado defensivo (deteccion)

- Alertar sobre envio de credenciales a dominios fuera de la lista corporativa.
- Correlacionar en el SIEM la secuencia acceso-a-landing → envio-de-datos por origen.
- Monitorear creacion de dominios parecidos a los corporativos (typosquatting).

## Reset rapido

La forma mas simple: en el menu del lab (`~/OpenSec_Lab/opensec-lab.sh`), elige la
opcion **15) Reset del taller**. Reinicia los componentes del lado azul y limpia
las alertas del taller en Wazuh.

Para relanzar la campaña desde cero, en el panel de GoPhish elimina la campaña
`Acme Corp — Phishing Lab` y reinicia `opsn-gophish`: el lab la recrea y la lanza
de nuevo al arrancar.

> Wazuh indexa con 1-3 min de retraso. Si reseteas justo despues de atacar, alguna
> alerta "en vuelo" puede sobrevivir; vuelve a correr el reset (opcion 15) para barrerla.
