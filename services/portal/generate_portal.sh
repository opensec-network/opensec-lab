#!/bin/sh
# services/portal/generate_portal.sh
# Sidecar: genera index.html del portal usando variables de entorno (puertos).
# Escribe el HTML en el volumen compartido con nginx.

OUT_DIR="/html"
mkdir -p "$OUT_DIR"

# Puertos con fallbacks
PORT_DNS="${OPSN_DNS_CONSOLE_PORT:-5380}"
PORT_DVWA="${OPSN_DVWA_PORT:-8080}"
PORT_JUICE="${OPSN_JUICE_PORT:-3000}"
PORT_GOPHISH="${OPSN_GOPHISH_ADMIN_PORT:-3333}"
PORT_DESKTOP="${OPSN_DESKTOP_PORT:-3100}"
PORT_MAIL="${OPSN_MAIL_WEBMAIL_PORT:-8888}"
PORT_API="${OPSN_API_PORT:-8025}"
PORT_DOCS="${OPSN_DOCS_PORT:-4000}"
PORT_WAZUH="${OPSN_WAZUH_DASH_PORT:-5601}"
DOMAIN="${OPSN_DOMAIN:-opensec.lab}"

cat > "$OUT_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenSec Lab — Portal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --bg:#f5f7f9; --surface:#ffffff; --surface-2:#fbfcfd; --line:#e5e8ec;
      --ink:#0e1726; --ink2:#566173; --ink3:#9aa4b2;
      --accent:#1d4ed8; --accent-ink:#1e40af; --accent-soft:#e8eefc;
      --danger:#d92d20; --danger-soft:#fdeceb; --danger-ink:#b42318;
      --ok:#16a34a;
      --font:'Hanken Grotesk', system-ui, sans-serif;
      --mono:'JetBrains Mono', monospace;
      --r:12px;
    }

    html { scroll-behavior: smooth; }
    body { font-family: var(--font); background: var(--bg); color: var(--ink); line-height: 1.5; -webkit-font-smoothing: antialiased; padding-bottom: 2.5rem; }
    .wrap { max-width: 1080px; margin: 0 auto; padding: 0 24px; }
    svg { display: block; }
    .ic { width: 20px; height: 20px; stroke: currentColor; stroke-width: 1.75; fill: none; stroke-linecap: round; stroke-linejoin: round; }
    a { color: inherit; }

    /* top bar */
    header.bar { display: flex; align-items: center; justify-content: space-between; padding: 18px 0; border-bottom: 1px solid var(--line); }
    .brand { display: flex; align-items: center; gap: 10px; font-weight: 800; font-size: 18px; letter-spacing: -.01em; text-decoration: none; }
    .brand .mark { width: 28px; height: 28px; border-radius: 7px; background: var(--accent); display: flex; align-items: center; justify-content: center; color: #fff; }
    .brand .mark .ic { width: 17px; height: 17px; stroke-width: 2.2; }
    .brand .dom { font-family: var(--mono); font-weight: 500; font-size: 12px; color: var(--ink3); margin-left: 4px; }
    .navlinks { display: flex; gap: 8px; }
    .btn { font-family: var(--font); font-weight: 600; font-size: 14px; border-radius: 8px; padding: 9px 15px; border: 1px solid var(--line); background: var(--surface); color: var(--ink); cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 7px; transition: .15s; }
    .btn:hover { border-color: #cfd5dd; }
    .btn.primary { background: var(--accent); border-color: var(--accent); color: #fff; }
    .btn.primary:hover { background: var(--accent-ink); }

    /* hero */
    .hero { padding: 52px 0 36px; }
    .eyebrow { font-size: 13px; font-weight: 600; color: var(--accent-ink); letter-spacing: .02em; margin-bottom: 12px; }
    .hero h1 { font-size: 40px; line-height: 1.08; letter-spacing: -.025em; font-weight: 800; max-width: 18ch; margin-bottom: 14px; }
    .hero p { font-size: 17px; color: var(--ink2); max-width: 56ch; margin-bottom: 24px; }
    .hero .cta { display: flex; gap: 12px; flex-wrap: wrap; }

    /* modes */
    .modes { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    .mode { background: var(--surface); border: 1px solid var(--line); border-radius: var(--r); padding: 20px 22px; }
    .mode .label { display: flex; align-items: center; gap: 8px; font-size: 12.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--ink3); margin-bottom: 10px; }
    .mode h3 { font-size: 18px; font-weight: 700; letter-spacing: -.01em; margin-bottom: 6px; }
    .mode p { font-size: 14px; color: var(--ink2); margin-bottom: 16px; }

    /* section heading */
    .sec { margin-top: 46px; }
    .sec-h { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 16px; gap: 12px; }
    .sec-h h2 { font-size: 22px; font-weight: 700; letter-spacing: -.02em; }
    .sec-h .meta { font-size: 13px; color: var(--ink3); white-space: nowrap; }

    /* service cards */
    .svc { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
    .card { background: var(--surface); border: 1px solid var(--line); border-radius: var(--r); padding: 18px; text-decoration: none; color: inherit; transition: .15s; display: block; }
    .card:hover { border-color: #cfd5dd; box-shadow: 0 1px 2px rgba(16,23,38,.04), 0 8px 24px rgba(16,23,38,.05); }
    .card .top { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }
    .ico { width: 38px; height: 38px; border-radius: 9px; background: var(--accent-soft); color: var(--accent-ink); display: flex; align-items: center; justify-content: center; }
    .ico.atk { background: var(--danger-soft); color: var(--danger-ink); }
    .card h4 { font-size: 15.5px; font-weight: 700; margin-bottom: 4px; }
    .card p { font-size: 13.5px; color: var(--ink2); }
    .card p code { font-family: var(--mono); font-size: 12px; color: var(--accent-ink); }
    .foot { display: flex; align-items: center; gap: 8px; margin-top: 12px; }
    .tag { display: inline-block; font-size: 11.5px; font-weight: 600; padding: 3px 9px; border-radius: 20px; background: #eef1f4; color: var(--ink2); }
    .tag.atk { background: var(--danger-soft); color: var(--danger-ink); }
    .port { font-family: var(--mono); font-size: 12px; color: var(--ink3); margin-left: auto; }
    .status-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--ink3); flex-shrink: 0; transition: background .3s; }
    .status-dot.up { background: var(--ok); }
    .status-dot.down { background: var(--danger); }

    /* workshop: attack -> detection */
    .lab { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 6px; overflow: hidden; }
    .lab-head { display: grid; grid-template-columns: 1fr 64px 1fr; padding: 14px 20px 4px; }
    .lab-head .red { color: var(--danger-ink); font-weight: 700; font-size: 12px; text-transform: uppercase; letter-spacing: .06em; display: flex; align-items: center; gap: 7px; }
    .lab-head .blue { color: var(--accent-ink); font-weight: 700; font-size: 12px; text-transform: uppercase; letter-spacing: .06em; display: flex; align-items: center; justify-content: flex-end; gap: 7px; }
    .pdot { width: 7px; height: 7px; border-radius: 50%; display: inline-block; }
    .pdot.r { background: var(--danger); } .pdot.g { background: var(--accent); }
    .lab-row { display: grid; grid-template-columns: 1fr 64px 1fr; align-items: stretch; }
    .lab-row + .lab-row { border-top: 1px solid var(--line); }
    .lab-side { padding: 18px 20px; }
    .lab-side .h { font-size: 11.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; margin-bottom: 9px; }
    .atkh { color: var(--danger-ink); }
    .lab-side code { font-family: var(--mono); font-size: 13.5px; color: var(--ink); display: block; margin-bottom: 5px; }
    .lab-side .note { font-size: 13px; color: var(--ink2); }
    .lab-def { text-align: right; }
    .lab-def .h { color: var(--accent-ink); }
    .lab-mid { display: flex; align-items: center; justify-content: center; }
    .lab-mid .conn { width: 34px; height: 34px; border-radius: 50%; border: 1px solid var(--line); background: var(--surface-2); display: flex; align-items: center; justify-content: center; color: var(--accent); }
    .ruletag { font-family: var(--mono); font-size: 11.5px; color: var(--accent-ink); background: var(--accent-soft); padding: 2px 8px; border-radius: 5px; display: inline-block; margin-bottom: 8px; }

    /* credentials */
    .creds { margin-top: 12px; background: var(--surface); border: 1px solid var(--line); border-radius: var(--r); overflow: hidden; }
    table { width: 100%; border-collapse: collapse; }
    thead tr { border-bottom: 1px solid var(--line); }
    th { text-align: left; padding: 11px 18px; font-size: 11.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--ink3); }
    tbody tr { border-bottom: 1px solid var(--line); }
    tbody tr:last-child { border-bottom: none; }
    tbody tr:hover { background: var(--surface-2); }
    td { padding: 11px 18px; font-size: 14px; color: var(--ink); }
    td:first-child { font-weight: 600; }
    td code { font-family: var(--mono); font-size: 12.5px; color: var(--accent-ink); background: var(--accent-soft); padding: 2px 7px; border-radius: 5px; }

    footer { margin-top: 48px; text-align: center; color: var(--ink3); font-size: 13px; font-family: var(--mono); }
    footer a { color: var(--ink2); text-decoration: none; }
    footer a:hover { color: var(--accent-ink); }

    @media (max-width: 760px) {
      .modes, .svc { grid-template-columns: 1fr; }
      .lab-row, .lab-head { grid-template-columns: 1fr; }
      .lab-def { text-align: left; }
      .lab-def .h { justify-content: flex-start; }
      .lab-mid { display: none; }
      .hero h1 { font-size: 30px; }
    }
  </style>
</head>
<body>
<div class="wrap">

  <header class="bar">
    <a class="brand" href="/">
      <span class="mark"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3l7 4v5c0 4-3 7-7 9-4-2-7-5-7-9V7z"/></svg></span>
      OpenSec Lab <span class="dom">${DOMAIN}</span>
    </a>
    <div class="navlinks">
      <a class="btn" href="http://localhost:${PORT_DOCS}" target="_blank">Documentación</a>
      <a class="btn" href="http://localhost:${PORT_DOCS}/workshops/api-breach/" target="_blank">Taller API</a>
      <a class="btn primary" href="http://localhost:${PORT_DOCS}/workshops/web-hacking/" target="_blank">Taller Web <svg class="ic" viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a>
    </div>
  </header>

  <section class="hero">
    <div class="eyebrow">Laboratorio de ciberseguridad · local · Kali Linux</div>
    <h1>Practica el ataque. Encuentra la evidencia.</h1>
    <p>Levanta targets vulnerables, lánzales ataques reales y observa cómo el SIEM los detecta. Explora a tu ritmo o sigue un taller guiado de principio a fin.</p>
    <div class="cta">
      <a class="btn primary" href="http://localhost:${PORT_DOCS}/workshops/web-hacking/" target="_blank">Empezar el taller Web</a>
      <a class="btn" href="http://localhost:${PORT_DOCS}/workshops/api-breach/" target="_blank">Taller de API</a>
      <a class="btn" href="#servicios">Ver todos los servicios</a>
    </div>
  </section>

  <section class="modes">
    <div class="mode">
      <div class="label"><svg class="ic" viewBox="0 0 24 24" style="width:15px;height:15px"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>Explorar libremente</div>
      <h3>Acceso directo a servicios</h3>
      <p>Abre cualquier target o herramienta sin seguir una secuencia. Tú decides qué romper.</p>
      <a class="btn" href="#servicios">Ver servicios</a>
    </div>
    <div class="mode">
      <div class="label"><svg class="ic" viewBox="0 0 24 24" style="width:15px;height:15px"><path d="M4 6h16M4 12h16M4 18h10"/></svg>Talleres guiados</div>
      <h3>Ataque → Detección en Wazuh</h3>
      <p>Recorridos reproducibles: explota, genera logs, investiga la alerta, entiende la regla.</p>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <a class="btn primary" href="http://localhost:${PORT_DOCS}/workshops/web-hacking/" target="_blank">Web Hacking</a>
        <a class="btn" href="http://localhost:${PORT_DOCS}/workshops/api-breach/" target="_blank">API Breach</a>
        <a class="btn" href="http://localhost:${PORT_DOCS}/workshops/phishing/" target="_blank">Phishing</a>
      </div>
    </div>
  </section>

  <section class="sec" id="servicios">
    <div class="sec-h"><h2>Ataque — targets vulnerables</h2><span class="meta">red team</span></div>
    <div class="svc">
      <a class="card" href="http://localhost:${PORT_DVWA}" target="_blank">
        <div class="top"><span class="ico atk"><svg class="ic" viewBox="0 0 24 24"><path d="M8 6V4a4 4 0 018 0v2M5 10h14M6 10v6a6 6 0 0012 0v-6M3 13h3M18 13h3M4 18l3-1M20 18l-3-1"/></svg></span><span class="status-dot" data-href="http://localhost:${PORT_DVWA}"></span></div>
        <h4>DVWA</h4><p>SQLi, XSS, CSRF y command injection en niveles graduados.</p>
        <div class="foot"><span class="tag atk">Web hacking</span><span class="port">:${PORT_DVWA}</span></div>
      </a>
      <a class="card" href="http://localhost:${PORT_JUICE}" target="_blank">
        <div class="top"><span class="ico atk"><svg class="ic" viewBox="0 0 24 24"><path d="M6 2l1 4h10l1-4M5 6h14l-1.5 14a2 2 0 01-2 2H8.5a2 2 0 01-2-2z"/></svg></span><span class="status-dot" data-href="http://localhost:${PORT_JUICE}"></span></div>
        <h4>OWASP Juice Shop</h4><p>E-commerce con 100+ retos que cubren el OWASP Top 10.</p>
        <div class="foot"><span class="tag atk">Web hacking</span><span class="port">:${PORT_JUICE}</span></div>
      </a>
      <a class="card" href="http://localhost:${PORT_API}" target="_blank">
        <div class="top"><span class="ico atk"><svg class="ic" viewBox="0 0 24 24"><path d="M8 7l-5 5 5 5M16 7l5 5-5 5M14 4l-4 16"/></svg></span><span class="status-dot" data-href="http://localhost:${PORT_API}/api/health"></span></div>
        <h4>API Vulnerable</h4><p>OWASP API Top 10: BOLA, tokens eternos, mass assignment, broken function auth.</p>
        <div class="foot"><span class="tag atk">API security</span><span class="port">:${PORT_API}</span></div>
      </a>
      <a class="card" href="https://localhost:${PORT_GOPHISH}" target="_blank">
        <div class="top"><span class="ico atk"><svg class="ic" viewBox="0 0 24 24"><path d="M3 5h18v14H3zM3 7l9 6 9-6"/></svg></span><span class="status-dot" data-href="https://localhost:${PORT_GOPHISH}"></span></div>
        <h4>GoPhish</h4><p>Campaña, email template y landing page pre-configurados. Listo para lanzar.</p>
        <div class="foot"><span class="tag atk">Phishing</span><span class="port">:${PORT_GOPHISH}</span></div>
      </a>
    </div>
  </section>

  <section class="sec">
    <div class="sec-h"><h2>Blue team — defensa y aprendizaje</h2><span class="meta">detección · docs</span></div>
    <div class="svc">
      <a class="card" href="https://localhost:${PORT_WAZUH}" target="_blank">
        <div class="top"><span class="ico"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3l7 4v5c0 4-3 7-7 9-4-2-7-5-7-9V7z"/><path d="M9 12l2 2 4-4"/></svg></span><span class="status-dot" data-href="https://localhost:${PORT_WAZUH}"></span></div>
        <h4>Wazuh — SIEM</h4><p>Cada ataque genera una alerta. Filtra por <code>rule.groups: openseclab</code>.</p>
        <div class="foot"><span class="tag">Blue team</span><span class="port">:${PORT_WAZUH}</span></div>
      </a>
      <a class="card" href="http://localhost:${PORT_DOCS}" target="_blank">
        <div class="top"><span class="ico"><svg class="ic" viewBox="0 0 24 24"><path d="M4 19.5A2.5 2.5 0 016.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z"/></svg></span><span class="status-dot" data-href="http://localhost:${PORT_DOCS}"></span></div>
        <h4>Documentación</h4><p>Guías de talleres, cheat sheets y escenarios por servicio.</p>
        <div class="foot"><span class="tag">Aprendizaje</span><span class="port">:${PORT_DOCS}</span></div>
      </a>
    </div>
  </section>

  <section class="sec">
    <div class="sec-h"><h2>Infraestructura del lab</h2><span class="meta">soporte</span></div>
    <div class="svc">
      <a class="card" href="http://localhost:${PORT_MAIL}" target="_blank">
        <div class="top"><span class="ico"><svg class="ic" viewBox="0 0 24 24"><path d="M3 6h18v12H3zM3 7l9 6 9-6"/></svg></span><span class="status-dot" data-href="http://localhost:${PORT_MAIL}"></span></div>
        <h4>Mail — Roundcube</h4><p>Correo interno del lab. Recibe los phishing de GoPhish. IMAP + SMTP listos.</p>
        <div class="foot"><span class="tag">Infraestructura</span><span class="port">:${PORT_MAIL}</span></div>
      </a>
      <a class="card" href="http://localhost:${PORT_DESKTOP}" target="_blank">
        <div class="top"><span class="ico"><svg class="ic" viewBox="0 0 24 24"><path d="M3 4h18v12H3zM8 20h8M12 16v4"/></svg></span><span class="status-dot" data-href="http://localhost:${PORT_DESKTOP}"></span></div>
        <h4>Desktop — XFCE</h4><p>Escritorio Linux en el navegador con Thunderbird pre-configurado.</p>
        <div class="foot"><span class="tag">Infraestructura</span><span class="port">:${PORT_DESKTOP}</span></div>
      </a>
      <a class="card" href="http://localhost:${PORT_DNS}" target="_blank">
        <div class="top"><span class="ico"><svg class="ic" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 010 18M12 3a15 15 0 000 18"/></svg></span><span class="status-dot" data-href="http://localhost:${PORT_DNS}"></span></div>
        <h4>DNS — Technitium</h4><p>Servidor DNS del lab. Gestiona la zona ${DOMAIN} para todos los servicios.</p>
        <div class="foot"><span class="tag">Infraestructura</span><span class="port">:${PORT_DNS}</span></div>
      </a>
    </div>
  </section>

  <section class="sec">
    <div class="sec-h"><h2>Taller: ataque y su detección</h2><span class="meta">cada acción ofensiva ↔ su regla en Wazuh</span></div>
    <div class="lab">
      <div class="lab-head"><div class="red"><span class="pdot r"></span>Red team — la acción</div><div></div><div class="blue">Blue team — lo que ve Wazuh<span class="pdot g"></span></div></div>
      <div class="lab-row">
        <div class="lab-side"><div class="h atkh">API1 · BOLA</div><code>GET /api/users/2/profile</code><div class="note">Alice lee el perfil de Bob (objeto ajeno).</div></div>
        <div class="lab-mid"><span class="conn"><svg class="ic" viewBox="0 0 24 24" style="width:16px;height:16px"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span></div>
        <div class="lab-side lab-def"><span class="ruletag">regla 100061 · nivel 10</span><code>{"event":"bola_attempt"}</code><div class="note">IDOR: acceso a objeto no autorizado.</div></div>
      </div>
      <div class="lab-row">
        <div class="lab-side"><div class="h atkh">API5 · Función sin control</div><code>GET /api/admin/users</code><div class="note">Sin rol admin, lista todos los usuarios.</div></div>
        <div class="lab-mid"><span class="conn"><svg class="ic" viewBox="0 0 24 24" style="width:16px;height:16px"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span></div>
        <div class="lab-side lab-def"><span class="ruletag">regla 100064 · nivel 10</span><code>{"event":"broken_function_auth"}</code><div class="note">Broken function level authorization.</div></div>
      </div>
      <div class="lab-row">
        <div class="lab-side"><div class="h atkh">API3 · Mass assignment</div><code>PUT /profile · role=admin</code><div class="note">Escala su propio rol a administrador.</div></div>
        <div class="lab-mid"><span class="conn"><svg class="ic" viewBox="0 0 24 24" style="width:16px;height:16px"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span></div>
        <div class="lab-side lab-def"><span class="ruletag">regla 100063 · nivel 12</span><code>{"event":"mass_assignment_attempt"}</code><div class="note">Modifica campo protegido sin lista blanca.</div></div>
      </div>
    </div>
  </section>

  <section class="sec">
    <div class="sec-h"><h2>Credenciales por defecto</h2><span class="meta">solo para el lab local</span></div>
    <div class="creds">
      <table>
        <thead><tr><th>Servicio</th><th>Usuario</th><th>Contraseña</th><th>URL</th></tr></thead>
        <tbody>
          <tr><td>DVWA</td><td><code>admin</code></td><td><code>admin</code></td><td>localhost:${PORT_DVWA}</td></tr>
          <tr><td>Juice Shop</td><td>—</td><td>(es un reto)</td><td>localhost:${PORT_JUICE}</td></tr>
          <tr><td>API — alice</td><td><code>alice</code></td><td><code>alice123</code></td><td>localhost:${PORT_API}</td></tr>
          <tr><td>API — admin</td><td><code>admin</code></td><td><code>admin_secret</code></td><td>localhost:${PORT_API}</td></tr>
          <tr><td>GoPhish</td><td><code>admin</code></td><td>(auto-generada)</td><td>localhost:${PORT_GOPHISH}</td></tr>
          <tr><td>Mail / Roundcube</td><td><code>admin@${DOMAIN}</code></td><td><code>Password</code></td><td>localhost:${PORT_MAIL}</td></tr>
          <tr><td>DNS</td><td><code>admin</code></td><td><code>Password</code></td><td>localhost:${PORT_DNS}</td></tr>
          <tr><td>Wazuh</td><td><code>admin</code></td><td><code>admin</code></td><td>localhost:${PORT_WAZUH}</td></tr>
        </tbody>
      </table>
    </div>
  </section>

  <footer><a href="https://github.com/opensec-network/opensec-lab" target="_blank">github.com/opensec-network/opensec-lab</a></footer>

</div>

<script>
var dots = document.querySelectorAll('.status-dot[data-href]');
for (var i = 0; i < dots.length; i++) {
  (function(dot) {
    var url = dot.getAttribute('data-href');
    fetch(url, { mode: 'no-cors', cache: 'no-store', signal: AbortSignal.timeout(3000) })
      .then(function() { dot.classList.add('up'); })
      .catch(function() { dot.classList.add('down'); });
  })(dots[i]);
}
</script>

</body>
</html>
HTMLEOF

echo "[OK] Portal generado en $OUT_DIR/index.html"
