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
  <link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --bg-deep:      #05080d;
      --bg-surface:   #0a0f1a;
      --bg-card:      #0d1320;
      --bg-card-hov:  #111928;
      --border:       rgba(255,255,255,0.07);
      --text-primary: #dde7f5;
      --text-secondary:#7a8eab;
      --text-muted:   #3d4f68;
      --cyan:         #00e5b3;
      --cyan-dim:     rgba(0,229,179,0.10);
      --cyan-glow:    rgba(0,229,179,0.25);
      --red:          #ff4655;
      --red-dim:      rgba(255,70,85,0.10);
      --blue:         #4fa3ff;
      --blue-dim:     rgba(79,163,255,0.10);
      --gold:         #f0b429;
      --gold-dim:     rgba(240,180,41,0.10);
      --font-ui:      'Chakra Petch', sans-serif;
      --font-mono:    'JetBrains Mono', monospace;
    }

    html { scroll-behavior: smooth; }

    body {
      font-family: var(--font-ui);
      background-color: var(--bg-deep);
      color: var(--text-primary);
      min-height: 100vh;
      padding: 0 0 4rem;
      position: relative;
      overflow-x: hidden;
    }

    body::before {
      content: '';
      position: fixed;
      inset: 0;
      background-image: radial-gradient(circle, rgba(255,255,255,0.035) 1px, transparent 1px);
      background-size: 32px 32px;
      pointer-events: none;
      z-index: 0;
    }

    .page-wrap {
      position: relative;
      z-index: 1;
      max-width: 1280px;
      margin: 0 auto;
      padding: 0 2rem;
    }

    /* ── HEADER ── */
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 1rem;
      padding: 1rem 0 1rem;
      border-bottom: 1px solid var(--border);
      margin-bottom: 2rem;
      animation: fadeDown 0.5s ease both;
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 0.9rem;
    }

    .logo-mark {
      display: flex;
      align-items: center;
      gap: 0.6rem;
      text-decoration: none;
    }

    .logo-mark img {
      height: 26px;
      width: auto;
      display: block;
    }

    .logo-wordmark {
      font-family: var(--font-ui);
      font-size: 0.9rem;
      font-weight: 700;
      color: var(--text-primary);
      letter-spacing: 0.04em;
      white-space: nowrap;
    }

    .logo-wordmark span {
      color: var(--cyan);
    }

    .domain-pill {
      display: inline-flex;
      align-items: center;
      gap: 0.45rem;
      background: rgba(0,229,179,0.05);
      border: 1px solid rgba(0,229,179,0.18);
      border-radius: 999px;
      padding: 0.22rem 0.75rem;
      font-family: var(--font-mono);
      font-size: 0.68rem;
      color: var(--cyan);
    }

    .domain-pill .pulse {
      width: 5px; height: 5px;
      border-radius: 50%;
      background: var(--cyan);
      animation: pulse-green 2s ease-in-out infinite;
      flex-shrink: 0;
    }

    .header-ctas {
      display: flex;
      gap: 0.6rem;
      flex-wrap: wrap;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      padding: 0.45rem 1rem;
      border-radius: 6px;
      font-family: var(--font-ui);
      font-size: 0.74rem;
      font-weight: 600;
      text-decoration: none;
      transition: all 0.15s ease;
      border: 1px solid;
    }

    .btn-primary {
      background: rgba(0,229,179,0.10);
      border-color: rgba(0,229,179,0.32);
      color: var(--cyan);
    }
    .btn-primary:hover {
      background: rgba(0,229,179,0.18);
      border-color: rgba(0,229,179,0.55);
    }

    .btn-secondary {
      background: rgba(255,255,255,0.03);
      border-color: rgba(255,255,255,0.10);
      color: var(--text-secondary);
    }
    .btn-secondary:hover {
      background: rgba(255,255,255,0.07);
      color: var(--text-primary);
    }

    .mode-panel {
      display: grid;
      grid-template-columns: minmax(0, 1.2fr) minmax(260px, 0.8fr);
      gap: 1px;
      background: var(--border);
      border: 1px solid var(--border);
      border-radius: 10px;
      overflow: hidden;
      margin-bottom: 1.6rem;
    }

    .mode-block {
      background: var(--bg-card);
      padding: 1rem 1.2rem;
    }

    .mode-kicker {
      font-family: var(--font-mono);
      font-size: 0.62rem;
      color: var(--cyan);
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin-bottom: 0.45rem;
    }

    .mode-block h1,
    .mode-block h2 {
      font-size: 1.05rem;
      line-height: 1.25;
      margin-bottom: 0.45rem;
    }

    .mode-block p {
      color: var(--text-secondary);
      font-family: 'Segoe UI', system-ui, sans-serif;
      font-size: 0.78rem;
      line-height: 1.55;
      margin-bottom: 0.75rem;
    }

    .mode-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 0.55rem;
    }

    /* ── SECTION LABELS ── */
    .section-header {
      display: flex;
      align-items: center;
      gap: 0.8rem;
      margin: 1.8rem 0 0.9rem;
    }

    .section-header .sh-line { flex: 1; height: 1px; background: var(--border); }

    .section-header .sh-label {
      font-size: 0.65rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.16em;
      white-space: nowrap;
      padding: 0.22rem 0.8rem;
      border-radius: 3px;
      border: 1px solid;
    }

    .section-header.cat-attack  .sh-label { color: var(--red);   border-color: rgba(255,70,85,0.25);  background: var(--red-dim);  }
    .section-header.cat-blue    .sh-label { color: var(--cyan);  border-color: rgba(0,229,179,0.25);  background: var(--cyan-dim); }
    .section-header.cat-infra   .sh-label { color: var(--blue);  border-color: rgba(79,163,255,0.25); background: var(--blue-dim); }

    /* ── GRID ── */
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(270px, 1fr));
      gap: 1px;
      background: var(--border);
      border: 1px solid var(--border);
      border-radius: 10px;
      overflow: hidden;
    }

    /* ── CARDS ── */
    .card {
      background: var(--bg-card);
      padding: 1.1rem 1.3rem 1rem;
      text-decoration: none;
      color: inherit;
      display: flex;
      align-items: flex-start;
      gap: 0.9rem;
      position: relative;
      transition: background 0.15s ease;
      overflow: hidden;
    }

    .card::before {
      content: '';
      position: absolute;
      top: 0; left: 0; bottom: 0;
      width: 2px;
      background: transparent;
      transition: background 0.18s ease;
    }

    .card:hover { background: var(--bg-card-hov); }

    .card.cat-attack:hover::before { background: var(--red);  }
    .card.cat-blue:hover::before   { background: var(--cyan); }
    .card.cat-infra:hover::before  { background: var(--blue); }

    .card-icon {
      font-size: 1.35rem;
      line-height: 1;
      flex-shrink: 0;
      margin-top: 0.05rem;
      opacity: 0.9;
    }

    .card-body { flex: 1; min-width: 0; }

    .card-title-row {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      margin-bottom: 0.2rem;
    }

    .card-body h3 {
      font-size: 0.84rem;
      font-weight: 600;
      color: var(--text-primary);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .card-body p {
      font-size: 0.74rem;
      color: var(--text-secondary);
      line-height: 1.55;
      font-family: 'Segoe UI', system-ui, sans-serif;
    }

    .card-meta {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      margin-top: 0.55rem;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      font-family: var(--font-mono);
      font-size: 0.58rem;
      font-weight: 500;
      padding: 0.12rem 0.5rem;
      border-radius: 3px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }

    .badge-red  { background: var(--red-dim);  color: var(--red);  }
    .badge-cyan { background: var(--cyan-dim); color: var(--cyan); }
    .badge-blue { background: var(--blue-dim); color: var(--blue); }
    .badge-gold { background: var(--gold-dim); color: var(--gold); }

    .port-tag {
      font-family: var(--font-mono);
      font-size: 0.62rem;
      color: var(--text-muted);
      margin-left: auto;
    }

    .status-dot {
      width: 6px; height: 6px;
      border-radius: 50%;
      background: var(--text-muted);
      flex-shrink: 0;
      transition: background 0.3s;
    }
    .status-dot.up {
      background: var(--cyan);
      box-shadow: 0 0 5px var(--cyan-glow);
      animation: pulse-green 2.5s ease-in-out infinite;
    }
    .status-dot.down { background: var(--red); }

    /* ── CREDENTIALS TABLE ── */
    .creds-wrap { margin-top: 2.2rem; }

    .creds-inner {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 10px;
      overflow: hidden;
    }

    .creds-head {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.7rem 1.2rem;
      border-bottom: 1px solid var(--border);
      font-size: 0.62rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.13em;
      color: var(--text-secondary);
    }

    table { width: 100%; border-collapse: collapse; }
    thead tr { border-bottom: 1px solid var(--border); }
    th {
      text-align: left;
      padding: 0.5rem 1.1rem;
      font-size: 0.61rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: var(--text-muted);
    }
    tbody tr { border-bottom: 1px solid rgba(255,255,255,0.03); transition: background 0.12s; }
    tbody tr:last-child { border-bottom: none; }
    tbody tr:hover { background: rgba(255,255,255,0.025); }
    td {
      padding: 0.5rem 1.1rem;
      color: var(--text-primary);
      font-family: 'Segoe UI', system-ui, sans-serif;
      font-size: 0.78rem;
    }
    td:first-child { font-family: var(--font-ui); font-weight: 500; color: var(--text-secondary); font-size: 0.75rem; }
    code {
      font-family: var(--font-mono);
      font-size: 0.74rem;
      color: var(--cyan);
      background: var(--cyan-dim);
      padding: 0.12rem 0.4rem;
      border-radius: 3px;
    }

    /* ── FOOTER ── */
    .footer {
      text-align: center;
      margin-top: 3rem;
      color: var(--text-muted);
      font-size: 0.68rem;
      font-family: var(--font-mono);
    }
    .footer a { color: var(--text-secondary); text-decoration: none; }
    .footer a:hover { color: var(--cyan); }

    /* ── ANIMATIONS ── */
    @keyframes fadeDown { from { opacity: 0; transform: translateY(-10px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes fadeIn   { from { opacity: 0; transform: translateY(6px);  } to { opacity: 1; transform: translateY(0); } }
    @keyframes pulse-green {
      0%, 100% { opacity: 1; }
      50%       { opacity: 0.55; }
    }

    .card { animation: fadeIn 0.35s ease both; }
    .card:nth-child(1) { animation-delay: 0.04s; }
    .card:nth-child(2) { animation-delay: 0.08s; }
    .card:nth-child(3) { animation-delay: 0.12s; }
    .card:nth-child(4) { animation-delay: 0.16s; }

    @media (max-width: 640px) {
      .page-wrap { padding: 0 1rem; }
      .logo-wordmark { display: none; }
      .mode-panel { grid-template-columns: 1fr; }
      .grid { grid-template-columns: 1fr; }
      .header { padding: 0.8rem 0; }
      th, td { padding: 0.45rem 0.8rem; }
    }
  </style>
</head>
<body>
<div class="page-wrap">

  <header class="header">
    <div class="header-left">
      <a class="logo-mark" href="/">
        <img src="/assets/logo_text_white.svg" alt="OpenSec">
      </a>
      <div class="domain-pill">
        <span class="pulse"></span>
        <span>${DOMAIN}</span>
      </div>
    </div>
    <div class="header-ctas">
      <a class="btn btn-primary" href="http://localhost:${PORT_DOCS}" target="_blank">
        Guías →
      </a>
      <a class="btn btn-secondary" href="#servicios">
        Servicios
      </a>
    </div>
  </header>

  <section class="mode-panel" aria-label="Modos de uso de OpenSec Lab">
    <div class="mode-block">
      <div class="mode-kicker">Explorar libremente</div>
      <h1>Acceso directo a servicios</h1>
      <p>Abre targets, herramientas, documentacion y paneles del lab sin seguir una secuencia obligatoria.</p>
      <div class="mode-actions">
        <a class="btn btn-primary" href="#servicios">Ver servicios</a>
        <a class="btn btn-secondary" href="http://localhost:${PORT_DOCS}" target="_blank">Abrir documentacion</a>
      </div>
    </div>
    <div class="mode-block">
      <div class="mode-kicker">Talleres guiados</div>
      <h2>Taller: Ataque y deteccion en APIs</h2>
      <p>Practica BOLA, mass assignment y autorizacion rota; luego revisa eventos y reglas defensivas.</p>
      <div class="mode-actions">
        <a class="btn btn-primary" href="http://localhost:${PORT_DOCS}/workshops/api-breach/" target="_blank">Abrir taller</a>
      </div>
    </div>
  </section>

  <div id="servicios"></div>

  <!-- ATAQUE -->
  <div class="section-header cat-attack">
    <div class="sh-line"></div>
    <div class="sh-label">Ataque — Targets Vulnerables</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-attack" href="http://localhost:${PORT_DVWA}" target="_blank">
      <div class="card-icon">💀</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>DVWA</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_DVWA}"></span>
        </div>
        <p>SQLi, XSS, CSRF, Command Injection. Niveles Low / Medium / High.</p>
        <div class="card-meta">
          <span class="badge badge-red">Web Hacking</span>
          <span class="port-tag">:${PORT_DVWA}</span>
        </div>
      </div>
    </a>

    <a class="card cat-attack" href="http://localhost:${PORT_JUICE}" target="_blank">
      <div class="card-icon">🧃</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>OWASP Juice Shop</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_JUICE}"></span>
        </div>
        <p>E-commerce vulnerable con 100+ retos. Cubre todo el OWASP Top 10.</p>
        <div class="card-meta">
          <span class="badge badge-red">Web Hacking</span>
          <span class="port-tag">:${PORT_JUICE}</span>
        </div>
      </div>
    </a>

    <a class="card cat-attack" href="http://localhost:${PORT_API}" target="_blank">
      <div class="card-icon">🔌</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>API Vulnerable</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_API}/api/health"></span>
        </div>
        <p>OWASP API Top 10: BOLA, tokens que no expiran, mass assignment, broken function auth.</p>
        <div class="card-meta">
          <span class="badge badge-red">API Security</span>
          <span class="port-tag">:${PORT_API}</span>
        </div>
      </div>
    </a>

    <a class="card cat-attack" href="https://localhost:${PORT_GOPHISH}" target="_blank">
      <div class="card-icon">🎣</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>GoPhish</h3>
          <span class="status-dot" data-href="https://localhost:${PORT_GOPHISH}"></span>
        </div>
        <p>Campaña, email template y landing page pre-configurados. Listo para lanzar.</p>
        <div class="card-meta">
          <span class="badge badge-red">Phishing</span>
          <span class="port-tag">:${PORT_GOPHISH}</span>
        </div>
      </div>
    </a>
  </div>

  <!-- BLUE TEAM -->
  <div class="section-header cat-blue">
    <div class="sh-line"></div>
    <div class="sh-label">Blue Team — Defensa y Aprendizaje</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-blue" href="https://localhost:${PORT_WAZUH}" target="_blank">
      <div class="card-icon">🔍</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Wazuh — SIEM</h3>
          <span class="status-dot" data-href="https://localhost:${PORT_WAZUH}"></span>
        </div>
        <p>Cada ataque que ejecutes genera una alerta aquí. Filtra por group:openseclab_api, openseclab_dvwa, openseclab_gophish.</p>
        <div class="card-meta">
          <span class="badge badge-cyan">Blue Team</span>
          <span class="port-tag">:${PORT_WAZUH}</span>
        </div>
      </div>
    </a>

    <a class="card cat-blue" href="http://localhost:${PORT_DOCS}" target="_blank">
      <div class="card-icon">📖</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Documentación — MkDocs</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_DOCS}"></span>
        </div>
        <p>Escenarios guiados de Phishing, API Security y Web Hacking. Cheat sheets por servicio.</p>
        <div class="card-meta">
          <span class="badge badge-cyan">Guiado</span>
          <span class="port-tag">:${PORT_DOCS}</span>
        </div>
      </div>
    </a>
  </div>

  <!-- INFRAESTRUCTURA -->
  <div class="section-header cat-infra">
    <div class="sh-line"></div>
    <div class="sh-label">Infraestructura del Lab</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-infra" href="http://localhost:${PORT_MAIL}" target="_blank">
      <div class="card-icon">✉️</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Mail — Roundcube</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_MAIL}"></span>
        </div>
        <p>Correo interno del lab. Recibe los emails de phishing de GoPhish. IMAP + SMTP configurados.</p>
        <div class="card-meta">
          <span class="badge badge-blue">Infraestructura</span>
          <span class="port-tag">:${PORT_MAIL}</span>
        </div>
      </div>
    </a>

    <a class="card cat-infra" href="http://localhost:${PORT_DESKTOP}" target="_blank">
      <div class="card-icon">🖥️</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Desktop — XFCE</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_DESKTOP}"></span>
        </div>
        <p>Escritorio Linux en el navegador con Thunderbird pre-configurado al mail server.</p>
        <div class="card-meta">
          <span class="badge badge-blue">Infraestructura</span>
          <span class="port-tag">:${PORT_DESKTOP}</span>
        </div>
      </div>
    </a>

    <a class="card cat-infra" href="http://localhost:${PORT_DNS}" target="_blank">
      <div class="card-icon">🌐</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>DNS — Technitium</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_DNS}"></span>
        </div>
        <p>Servidor DNS del lab. Gestiona la zona ${DOMAIN} con registros para todos los servicios.</p>
        <div class="card-meta">
          <span class="badge badge-blue">Infraestructura</span>
          <span class="port-tag">:${PORT_DNS}</span>
        </div>
      </div>
    </a>
  </div>

  <!-- CREDENCIALES -->
  <div class="creds-wrap">
    <div class="creds-inner">
      <div class="creds-head">
        <span>Credenciales por defecto</span>
      </div>
      <table>
        <thead>
          <tr>
            <th>Servicio</th>
            <th>Usuario</th>
            <th>Contraseña</th>
            <th>URL</th>
          </tr>
        </thead>
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
  </div>

  <footer class="footer">
    <p><a href="https://github.com/opensec-network/opensec-lab" target="_blank">github.com/opensec-network/opensec-lab</a></p>
  </footer>

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
