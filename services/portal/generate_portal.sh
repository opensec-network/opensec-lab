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
      --cyan-dim:     rgba(0,229,179,0.12);
      --cyan-glow:    rgba(0,229,179,0.25);
      --red:          #ff4655;
      --red-dim:      rgba(255,70,85,0.12);
      --red-glow:     rgba(255,70,85,0.25);
      --blue:         #4fa3ff;
      --blue-dim:     rgba(79,163,255,0.12);
      --blue-glow:    rgba(79,163,255,0.25);
      --gold:         #f0b429;
      --gold-dim:     rgba(240,180,41,0.12);
      --font-ui:      'Chakra Petch', sans-serif;
      --font-mono:    'JetBrains Mono', monospace;
    }

    html { scroll-behavior: smooth; }

    body {
      font-family: var(--font-ui);
      background-color: var(--bg-deep);
      color: var(--text-primary);
      min-height: 100vh;
      padding: 2.5rem 2rem 4rem;
      position: relative;
      overflow-x: hidden;
    }

    body::before {
      content: '';
      position: fixed;
      inset: 0;
      background-image: radial-gradient(circle, rgba(255,255,255,0.045) 1px, transparent 1px);
      background-size: 32px 32px;
      pointer-events: none;
      z-index: 0;
    }

    body::after {
      content: '';
      position: fixed;
      top: -120px;
      left: 50%;
      transform: translateX(-50%);
      width: 900px;
      height: 500px;
      background: radial-gradient(ellipse at center, rgba(0,229,179,0.06) 0%, transparent 70%);
      pointer-events: none;
      z-index: 0;
    }

    .page-wrap {
      position: relative;
      z-index: 1;
      max-width: 1280px;
      margin: 0 auto;
    }

    .header {
      display: flex;
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 1rem;
      padding-bottom: 2.5rem;
      animation: fadeDown 0.6s ease both;
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 1.1rem;
    }

    .logo-wrap img {
      height: 54px;
      width: auto;
      display: block;
      filter: drop-shadow(0 0 18px rgba(0,229,179,0.2));
    }

    .domain-pill {
      display: inline-flex;
      align-items: center;
      gap: 0.55rem;
      background: rgba(0,229,179,0.06);
      border: 1px solid rgba(0,229,179,0.2);
      border-radius: 999px;
      padding: 0.3rem 0.9rem;
      font-family: var(--font-mono);
      font-size: 0.75rem;
      color: var(--cyan);
    }

    .domain-pill .pulse {
      width: 6px; height: 6px;
      border-radius: 50%;
      background: var(--cyan);
      animation: pulse-green 2s ease-in-out infinite;
      flex-shrink: 0;
    }

    .header-ctas {
      display: flex;
      gap: 0.75rem;
      flex-wrap: wrap;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      padding: 0.5rem 1.1rem;
      border-radius: 6px;
      font-family: var(--font-ui);
      font-size: 0.78rem;
      font-weight: 600;
      text-decoration: none;
      transition: all 0.18s ease;
      border: 1px solid;
    }

    .btn-primary {
      background: rgba(0,229,179,0.12);
      border-color: rgba(0,229,179,0.35);
      color: var(--cyan);
    }
    .btn-primary:hover {
      background: rgba(0,229,179,0.22);
      border-color: rgba(0,229,179,0.6);
    }

    .btn-secondary {
      background: rgba(255,255,255,0.04);
      border-color: rgba(255,255,255,0.12);
      color: var(--text-secondary);
    }
    .btn-secondary:hover {
      background: rgba(255,255,255,0.08);
      color: var(--text-primary);
    }

    .section-header {
      display: flex;
      align-items: center;
      gap: 1rem;
      margin: 2.5rem 0 1.2rem;
    }

    .section-header .sh-line { flex: 1; height: 1px; background: var(--border); }

    .section-header .sh-label {
      display: flex;
      align-items: center;
      gap: 0.55rem;
      font-size: 0.7rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.15em;
      white-space: nowrap;
      padding: 0.28rem 0.85rem;
      border-radius: 4px;
      border: 1px solid;
    }

    .section-header.cat-attack  .sh-label { color: var(--red);   border-color: rgba(255,70,85,0.3);  background: var(--red-dim);  }
    .section-header.cat-defense .sh-label { color: var(--cyan);  border-color: rgba(0,229,179,0.3);  background: var(--cyan-dim); }
    .section-header.cat-infra   .sh-label { color: var(--blue);  border-color: rgba(79,163,255,0.3); background: var(--blue-dim); }
    .section-header.cat-learn   .sh-label { color: var(--gold);  border-color: rgba(240,180,41,0.3); background: var(--gold-dim); }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 1px;
      background: var(--border);
      border: 1px solid var(--border);
      border-radius: 12px;
      overflow: hidden;
    }

    .card {
      background: var(--bg-card);
      padding: 1.25rem 1.4rem 1.1rem;
      text-decoration: none;
      color: inherit;
      display: flex;
      align-items: flex-start;
      gap: 1rem;
      position: relative;
      transition: background 0.18s ease;
      overflow: hidden;
    }

    .card::before {
      content: '';
      position: absolute;
      top: 0; left: 0; bottom: 0;
      width: 3px;
      background: transparent;
      transition: background 0.2s ease;
    }

    .card:hover { background: var(--bg-card-hov); }

    .card.cat-attack:hover::before  { background: var(--red);  }
    .card.cat-defense:hover::before { background: var(--cyan); }
    .card.cat-infra:hover::before   { background: var(--blue); }
    .card.cat-learn:hover::before   { background: var(--gold); }

    .card-icon { font-size: 1.55rem; line-height: 1; flex-shrink: 0; margin-top: 0.1rem; }
    .card-body { flex: 1; min-width: 0; }

    .card-title-row {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      margin-bottom: 0.25rem;
    }

    .card-body h3 {
      font-size: 0.88rem;
      font-weight: 600;
      color: var(--text-primary);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .card-body p {
      font-size: 0.77rem;
      color: var(--text-secondary);
      line-height: 1.5;
      font-family: 'Segoe UI', system-ui, sans-serif;
    }

    .card-meta {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      margin-top: 0.6rem;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      font-family: var(--font-mono);
      font-size: 0.62rem;
      font-weight: 500;
      padding: 0.15rem 0.55rem;
      border-radius: 3px;
      text-transform: uppercase;
    }

    .badge-cyan { background: var(--cyan-dim);  color: var(--cyan); }
    .badge-red  { background: var(--red-dim);   color: var(--red);  }
    .badge-blue { background: var(--blue-dim);  color: var(--blue); }
    .badge-gold { background: var(--gold-dim);  color: var(--gold); }

    .port-tag {
      font-family: var(--font-mono);
      font-size: 0.65rem;
      color: var(--text-muted);
      margin-left: auto;
    }

    .status-dot {
      width: 7px; height: 7px;
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

    .creds-wrap { margin-top: 2.5rem; }

    .creds-inner {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 12px;
      overflow: hidden;
    }

    .creds-head {
      display: flex;
      align-items: center;
      gap: 0.6rem;
      padding: 0.9rem 1.4rem;
      border-bottom: 1px solid var(--border);
      background: rgba(255,255,255,0.02);
      font-size: 0.68rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      color: var(--text-secondary);
    }

    table { width: 100%; border-collapse: collapse; }
    thead tr { border-bottom: 1px solid var(--border); }
    th {
      text-align: left;
      padding: 0.55rem 1.2rem;
      font-size: 0.65rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: var(--text-muted);
    }
    tbody tr { border-bottom: 1px solid rgba(255,255,255,0.03); transition: background 0.12s; }
    tbody tr:last-child { border-bottom: none; }
    tbody tr:hover { background: rgba(255,255,255,0.025); }
    td {
      padding: 0.55rem 1.2rem;
      color: var(--text-primary);
      font-family: 'Segoe UI', system-ui, sans-serif;
      font-size: 0.8rem;
    }
    td:first-child { font-family: var(--font-ui); font-weight: 500; color: var(--text-secondary); font-size: 0.78rem; }
    code {
      font-family: var(--font-mono);
      font-size: 0.77rem;
      color: var(--cyan);
      background: var(--cyan-dim);
      padding: 0.15rem 0.45rem;
      border-radius: 3px;
    }

    .footer {
      text-align: center;
      margin-top: 3.5rem;
      color: var(--text-muted);
      font-size: 0.72rem;
      font-family: var(--font-mono);
    }
    .footer a { color: var(--text-secondary); text-decoration: none; }
    .footer a:hover { color: var(--cyan); }

    @keyframes fadeDown { from { opacity: 0; transform: translateY(-16px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes fadeIn   { from { opacity: 0; transform: translateY(8px); }  to { opacity: 1; transform: translateY(0); } }
    @keyframes pulse-green {
      0%, 100% { opacity: 1; }
      50%       { opacity: 0.6; }
    }

    .card { animation: fadeIn 0.4s ease both; }
    .card:nth-child(1) { animation-delay: 0.05s; }
    .card:nth-child(2) { animation-delay: 0.10s; }
    .card:nth-child(3) { animation-delay: 0.15s; }
    .card:nth-child(4) { animation-delay: 0.20s; }

    @media (max-width: 600px) {
      body { padding: 1.5rem 1rem 3rem; }
      .logo-wrap img { height: 42px; }
      .grid { grid-template-columns: 1fr; }
      .header { flex-direction: column; align-items: flex-start; }
      th, td { padding: 0.5rem 0.8rem; }
    }
  </style>
</head>
<body>
<div class="page-wrap">

  <header class="header">
    <div class="header-left">
      <div class="logo-wrap">
        <img src="/assets/logo_text_white.svg" alt="OpenSec Lab">
      </div>
      <div class="domain-pill">
        <span class="pulse"></span>
        <span>${DOMAIN}</span>
      </div>
    </div>
    <div class="header-ctas">
      <a class="btn btn-primary" href="http://localhost:${PORT_DOCS}" target="_blank">
        Sigue un escenario
      </a>
      <a class="btn btn-secondary" href="#servicios">
        Explora libremente
      </a>
    </div>
  </header>

  <div id="servicios"></div>

  <div class="section-header cat-attack">
    <div class="sh-line"></div>
    <div class="sh-label">ATAQUE — Targets Vulnerables</div>
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
        <p>Damn Vulnerable Web App. SQLi, XSS, CSRF, Command Injection. Niveles Low / Medium / High.</p>
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
        <p>API REST con OWASP API Top 10: BOLA, tokens que nunca expiran, mass assignment, broken function auth.</p>
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
        <p>Framework de phishing. Campaña, email template y landing page pre-configurados. Listo para lanzar.</p>
        <div class="card-meta">
          <span class="badge badge-red">Phishing</span>
          <span class="port-tag">:${PORT_GOPHISH}</span>
        </div>
      </div>
    </a>
  </div>

  <div class="section-header cat-defense">
    <div class="sh-line"></div>
    <div class="sh-label">DEFENSA — Visibilidad y Deteccion</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-defense" href="https://localhost:${PORT_WAZUH}" target="_blank">
      <div class="card-icon">🔍</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Wazuh — SIEM</h3>
          <span class="status-dot" data-href="https://localhost:${PORT_WAZUH}"></span>
        </div>
        <p>Cada ataque que ejecutes genera una alerta aqui. Busca por group:openseclab_api, openseclab_dvwa, openseclab_gophish.</p>
        <div class="card-meta">
          <span class="badge badge-cyan">Blue Team</span>
          <span class="port-tag">:${PORT_WAZUH}</span>
        </div>
      </div>
    </a>
  </div>

  <div class="section-header cat-infra">
    <div class="sh-line"></div>
    <div class="sh-label">INFRAESTRUCTURA del Lab</div>
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
        <p>Servidor de correo interno. Recibe emails de phishing de GoPhish. IMAP + SMTP configurados.</p>
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

  <div class="section-header cat-learn">
    <div class="sh-line"></div>
    <div class="sh-label">APRENDIZAJE — Documentacion y Escenarios</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-learn" href="http://localhost:${PORT_DOCS}" target="_blank">
      <div class="card-icon">📖</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Documentacion — MkDocs</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_DOCS}"></span>
        </div>
        <p>Escenarios guiados de Phishing, API Security y Web Hacking. Cheat sheets y paginas de cada servicio.</p>
        <div class="card-meta">
          <span class="badge badge-gold">Guiado</span>
          <span class="port-tag">:${PORT_DOCS}</span>
        </div>
      </div>
    </a>
  </div>

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
            <th>Contrasena</th>
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
          <tr><td>Wazuh</td><td><code>admin</code></td><td><code>SecretPassword</code></td><td>localhost:${PORT_WAZUH}</td></tr>
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
