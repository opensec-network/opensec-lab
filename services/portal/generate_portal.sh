#!/bin/sh
# services/portal/generate_portal.sh
# Sidecar: genera index.html del portal usando las variables de entorno (puertos).
# Escribe el HTML en el volumen compartido con nginx.

OUT_DIR="/html"
mkdir -p "$OUT_DIR"

# Leer puertos con fallbacks
PORT_DNS="${OPSN_DNS_CONSOLE_PORT:-5380}"
PORT_DVWA="${OPSN_DVWA_PORT:-8080}"
PORT_JUICE="${OPSN_JUICE_PORT:-3000}"
PORT_GOPHISH="${OPSN_GOPHISH_ADMIN_PORT:-3333}"
PORT_DESKTOP="${OPSN_DESKTOP_PORT:-3100}"
PORT_MAIL="${OPSN_MAIL_WEBMAIL_PORT:-8888}"
PORT_WEBGOAT="${OPSN_WEBGOAT_PORT:-8081}"
PORT_CRAPI="${OPSN_CRAPI_PORT:-8025}"
PORT_PORTAINER="${OPSN_PORTAINER_PORT:-9443}"
PASS_PORTAINER="${OPSN_PORTAINER_PASSWORD:-Password1234}"
PORT_WIKI="${OPSN_WIKI_PORT:-6875}"
PORT_GITEA="${OPSN_GITEA_PORT:-3002}"
DOMAIN="${OPSN_DOMAIN:-opensec.lab}"

cat > "$OUT_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lab Portal</title>
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
      --border-hov:   rgba(255,255,255,0.15);
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

    /* ── Dot-grid background ── */
    body::before {
      content: '';
      position: fixed;
      inset: 0;
      background-image:
        radial-gradient(circle, rgba(255,255,255,0.045) 1px, transparent 1px);
      background-size: 32px 32px;
      pointer-events: none;
      z-index: 0;
    }

    /* ── Radial glow at top ── */
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

    /* ─────────── HEADER ─────────── */
    .header {
      display: flex;
      flex-direction: row;
      align-items: center;
      gap: 1.1rem;
      padding-bottom: 3rem;
      animation: fadeDown 0.6s ease both;
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
      letter-spacing: 0.02em;
    }

    .domain-pill .pulse {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: var(--cyan);
      animation: pulse-green 2s ease-in-out infinite;
      flex-shrink: 0;
    }

    /* ─────────── SECTION HEADERS ─────────── */
    .section-header {
      display: flex;
      align-items: center;
      gap: 1rem;
      margin: 2.5rem 0 1.2rem;
      animation: fadeIn 0.4s ease both;
    }

    .section-header .sh-line {
      flex: 1;
      height: 1px;
      background: var(--border);
    }

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

    .section-header.cat-game  .sh-label { color: var(--cyan);  border-color: rgba(0,229,179,0.3);  background: var(--cyan-dim); }
    .section-header.cat-red   .sh-label { color: var(--red);   border-color: rgba(255,70,85,0.3);  background: var(--red-dim);  }
    .section-header.cat-infra .sh-label { color: var(--blue);  border-color: rgba(79,163,255,0.3); background: var(--blue-dim); }

    /* ─────────── GRID ─────────── */
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 1px;
      background: var(--border);
      border: 1px solid var(--border);
      border-radius: 12px;
      overflow: hidden;
    }

    /* ─────────── CARD ─────────── */
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

    .card:hover {
      background: var(--bg-card-hov);
    }

    .card.cat-game:hover::before  { background: var(--cyan); }
    .card.cat-red:hover::before   { background: var(--red);  }
    .card.cat-infra:hover::before { background: var(--blue); }
    .card.cat-admin:hover::before { background: var(--gold); }

    /* Subtle shimmer on hover */
    .card::after {
      content: '';
      position: absolute;
      inset: 0;
      background: linear-gradient(135deg, rgba(255,255,255,0.0) 0%, rgba(255,255,255,0.015) 100%);
      opacity: 0;
      transition: opacity 0.2s;
    }
    .card:hover::after { opacity: 1; }

    .card-icon {
      font-size: 1.55rem;
      line-height: 1;
      flex-shrink: 0;
      margin-top: 0.1rem;
    }

    .card-body {
      flex: 1;
      min-width: 0;
    }

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
      letter-spacing: 0.01em;
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
      letter-spacing: 0.04em;
      text-transform: uppercase;
    }

    .badge-cyan   { background: var(--cyan-dim);  color: var(--cyan); }
    .badge-red    { background: var(--red-dim);   color: var(--red);  }
    .badge-blue   { background: var(--blue-dim);  color: var(--blue); }
    .badge-gold   { background: var(--gold-dim);  color: var(--gold); }

    .port-tag {
      font-family: var(--font-mono);
      font-size: 0.65rem;
      color: var(--text-muted);
      margin-left: auto;
    }

    /* ─────────── STATUS DOT ─────────── */
    .status-dot {
      width: 7px;
      height: 7px;
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
    .status-dot.down {
      background: var(--red);
      box-shadow: 0 0 5px var(--red-glow);
    }

    /* ─────────── CREDENTIALS ─────────── */
    .creds-wrap {
      margin-top: 2.5rem;
      animation: fadeIn 0.5s ease both;
    }

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

    .creds-head .icon { font-size: 0.9rem; }

    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.8rem;
    }

    thead tr {
      border-bottom: 1px solid var(--border);
    }

    th {
      text-align: left;
      padding: 0.55rem 1.2rem;
      font-size: 0.65rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: var(--text-muted);
    }

    tbody tr {
      border-bottom: 1px solid rgba(255,255,255,0.03);
      transition: background 0.12s;
    }

    tbody tr:last-child { border-bottom: none; }
    tbody tr:hover { background: rgba(255,255,255,0.025); }

    td {
      padding: 0.55rem 1.2rem;
      color: var(--text-primary);
      font-family: 'Segoe UI', system-ui, sans-serif;
      font-size: 0.8rem;
    }

    td:first-child {
      font-family: var(--font-ui);
      font-weight: 500;
      color: var(--text-secondary);
      font-size: 0.78rem;
    }

    code {
      font-family: var(--font-mono);
      font-size: 0.77rem;
      color: var(--cyan);
      background: var(--cyan-dim);
      padding: 0.15rem 0.45rem;
      border-radius: 3px;
    }

    /* ─────────── FOOTER ─────────── */
    .footer {
      text-align: center;
      margin-top: 3.5rem;
      color: var(--text-muted);
      font-size: 0.72rem;
      font-family: var(--font-mono);
      animation: fadeIn 0.6s ease both;
    }

    .footer a {
      color: var(--text-secondary);
      text-decoration: none;
      transition: color 0.15s;
    }
    .footer a:hover { color: var(--cyan); }

    /* ─────────── ANIMATIONS ─────────── */
    @keyframes fadeDown {
      from { opacity: 0; transform: translateY(-16px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(8px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    @keyframes pulse-green {
      0%, 100% { opacity: 1; box-shadow: 0 0 4px var(--cyan-glow); }
      50%       { opacity: 0.6; box-shadow: 0 0 10px var(--cyan-glow); }
    }

    /* Staggered card animations */
    .card { animation: fadeIn 0.4s ease both; }
    .card:nth-child(1) { animation-delay: 0.05s; }
    .card:nth-child(2) { animation-delay: 0.10s; }
    .card:nth-child(3) { animation-delay: 0.15s; }
    .card:nth-child(4) { animation-delay: 0.20s; }
    .card:nth-child(5) { animation-delay: 0.25s; }

    @media (max-width: 600px) {
      body { padding: 1.5rem 1rem 3rem; }
      .logo-wrap img { height: 42px; }
      .grid { grid-template-columns: 1fr; }
      th, td { padding: 0.5rem 0.8rem; }
    }
  </style>
</head>
<body>
<div class="page-wrap">

  <!-- ── HEADER ── -->
  <header class="header">
    <div class="logo-wrap">
      <img src="/assets/logo_text_white.svg" alt="OpenSec Lab">
    </div>
    <div class="domain-pill">
      <span class="pulse"></span>
      <span>${DOMAIN}</span>
    </div>
  </header>

  <!-- ── GAMIFICACIÓN & APRENDIZAJE ── -->
  <div class="section-header cat-game">
    <div class="sh-line"></div>
    <div class="sh-label">⚡ Aprendizaje</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-game" href="http://localhost:${PORT_WIKI}" target="_blank">
      <div class="card-icon">📚</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>BookStack — Wiki</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_WIKI}"></span>
        </div>
        <p>Guías paso a paso y cheat sheets de nmap, sqlmap, Burp Suite y más.</p>
        <div class="card-meta">
          <span class="badge badge-cyan">Aprendizaje</span>
          <span class="port-tag">:${PORT_WIKI}</span>
        </div>
      </div>
    </a>

    <a class="card cat-game" href="http://localhost:${PORT_GITEA}" target="_blank">
      <div class="card-icon">🐙</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Gitea — Code Review</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_GITEA}"></span>
        </div>
        <p>Repositorios con código intencionalmente vulnerable para ejercicios de code review.</p>
        <div class="card-meta">
          <span class="badge badge-cyan">DevSecOps</span>
          <span class="port-tag">:${PORT_GITEA}</span>
        </div>
      </div>
    </a>
  </div>

  <!-- ── RED TEAM — TARGETS ── -->
  <div class="section-header cat-red">
    <div class="sh-line"></div>
    <div class="sh-label">🔴 Red Team — Targets Vulnerables</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-red" href="http://localhost:${PORT_DVWA}" target="_blank">
      <div class="card-icon">💀</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>DVWA</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_DVWA}"></span>
        </div>
        <p>Damn Vulnerable Web App. SQLi, XSS, CSRF, Command Injection. Niveles Low / Medium / High.</p>
        <div class="card-meta">
          <span class="badge badge-red">Vulnerable</span>
          <span class="port-tag">:${PORT_DVWA}</span>
        </div>
      </div>
    </a>

    <a class="card cat-red" href="http://localhost:${PORT_JUICE}" target="_blank">
      <div class="card-icon">🧃</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>OWASP Juice Shop</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_JUICE}"></span>
        </div>
        <p>E-commerce vulnerable con 100+ retos. Cubre todo el OWASP Top 10.</p>
        <div class="card-meta">
          <span class="badge badge-red">Vulnerable</span>
          <span class="port-tag">:${PORT_JUICE}</span>
        </div>
      </div>
    </a>

    <a class="card cat-red" href="http://localhost:${PORT_WEBGOAT}/WebGoat" target="_blank">
      <div class="card-icon">🐛</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>WebGoat</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_WEBGOAT}/WebGoat"></span>
        </div>
        <p>Plataforma de aprendizaje guiado de OWASP. Lecciones interactivas con explicaciones.</p>
        <div class="card-meta">
          <span class="badge badge-cyan">Guiado</span>
          <span class="port-tag">:${PORT_WEBGOAT}</span>
        </div>
      </div>
    </a>

    <a class="card cat-red" href="http://localhost:${PORT_CRAPI}" target="_blank">
      <div class="card-icon">🔌</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>crAPI — API Security</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_CRAPI}"></span>
        </div>
        <p>Completely Ridiculous API. BOLA, auth rota, mass assignment y más.</p>
        <div class="card-meta">
          <span class="badge badge-red">Vulnerable</span>
          <span class="port-tag">:${PORT_CRAPI}</span>
        </div>
      </div>
    </a>
  </div>

  <!-- ── INFRAESTRUCTURA ── -->
  <div class="section-header cat-infra">
    <div class="sh-line"></div>
    <div class="sh-label">⚙️ Infraestructura del Lab</div>
    <div class="sh-line"></div>
  </div>

  <div class="grid">
    <a class="card cat-infra" href="https://localhost:${PORT_GOPHISH}" target="_blank">
      <div class="card-icon">🎣</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>GoPhish</h3>
          <span class="status-dot" data-href="https://localhost:${PORT_GOPHISH}"></span>
        </div>
        <p>Framework de phishing. Campaña, email template y landing page pre-configurados.</p>
        <div class="card-meta">
          <span class="badge badge-red">Phishing</span>
          <span class="port-tag">:${PORT_GOPHISH}</span>
        </div>
      </div>
    </a>

    <a class="card cat-infra" href="http://localhost:${PORT_MAIL}" target="_blank">
      <div class="card-icon">✉️</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Mail — Roundcube</h3>
          <span class="status-dot" data-href="http://localhost:${PORT_MAIL}"></span>
        </div>
        <p>Servidor de correo interno. Recibe emails de phishing. IMAP + SMTP configurados.</p>
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

    <a class="card cat-admin" href="https://localhost:${PORT_PORTAINER}" target="_blank">
      <div class="card-icon">🐳</div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>Portainer</h3>
          <span class="status-dot" data-href="https://localhost:${PORT_PORTAINER}"></span>
        </div>
        <p>Gestión visual de contenedores Docker. Herramienta administrativa — no es un target.</p>
        <div class="card-meta">
          <span class="badge badge-gold">Admin</span>
          <span class="port-tag">:${PORT_PORTAINER}</span>
        </div>
      </div>
    </a>
  </div>

  <!-- ── CREDENCIALES ── -->
  <div class="creds-wrap">
    <div class="creds-inner">
      <div class="creds-head">
        <span class="icon">🔑</span>
        Credenciales por defecto
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
          <tr><td>BookStack</td><td><code>admin@${DOMAIN}</code></td><td><code>Password</code></td><td>localhost:${PORT_WIKI}</td></tr>
          <tr><td>Gitea</td><td><code>admin</code></td><td><code>Password</code></td><td>localhost:${PORT_GITEA}</td></tr>
          <tr><td>DVWA</td><td><code>admin</code></td><td><code>admin</code></td><td>localhost:${PORT_DVWA}</td></tr>
          <tr><td>GoPhish</td><td><code>admin</code></td><td><code>Password</code></td><td>localhost:${PORT_GOPHISH}</td></tr>
          <tr><td>Mail</td><td><code>admin@${DOMAIN}</code></td><td><code>Password</code></td><td>localhost:${PORT_MAIL}</td></tr>
          <tr><td>Mail (user)</td><td><code>user@${DOMAIN}</code></td><td><code>Password</code></td><td>localhost:${PORT_MAIL}</td></tr>
          <tr><td>DNS</td><td><code>admin</code></td><td><code>Password</code></td><td>localhost:${PORT_DNS}</td></tr>
          <tr><td>Portainer</td><td><code>admin</code></td><td><code>${PASS_PORTAINER}</code></td><td>localhost:${PORT_PORTAINER}</td></tr>
        </tbody>
      </table>
    </div>
  </div>

  <!-- ── FOOTER ── -->

  <footer class="footer">
    <p><a href="https://github.com/opensec-network/opensec-lab" target="_blank">github.com/opensec-network/opensec-lab</a></p>
  </footer>

</div>

<script>
// Health check: intenta cargar cada servicio y colorea el dot correspondiente
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
