# Wazuh SIEM

**URL:** https://localhost:5601
**Credenciales:** `admin` / `SecretPassword`
**Proposito:** Ver y analizar las alertas generadas por los ataques del lab.

---

## Filtros utiles en Security Events

| Filtro | Servicio |
|--------|---------|
| `group: openseclab_dvwa` | Ataques a DVWA |
| `group: openseclab_juiceshop` | Ataques a Juice Shop |
| `group: openseclab_api` | Ataques a la API vulnerable |
| `group: openseclab_gophish` | Eventos de phishing |
| `group: ids` | Alertas de Suricata IDS |
| `rule.level: [10 TO *]` | Solo alertas criticas |

## Comandos desde terminal

```bash
# Ver alertas en tiempo real (JSON)
docker exec opsn-wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json

# Ver logs de la API vulnerable
docker exec opsn-wazuh-manager tail -f /var/ossec/logs/api/api.log

# Verificar reglas del lab
docker exec opsn-wazuh-manager grep -c "openseclab" /var/ossec/etc/rules/openseclab.xml
```

## Reglas del lab — resumen

| ID | Nivel | Descripcion |
|----|-------|-------------|
| 100001 | 10 | SQL Injection en DVWA |
| 100002 | 10 | Command Injection en DVWA |
| 100003 | 8 | XSS en DVWA |
| 100020 | 7 | Click en landing page GoPhish |
| 100061 | 10 | API1 BOLA lectura |
| 100062 | 12 | API1 BOLA escritura |
| 100063 | 12 | API3 Mass Assignment |
| 100064 | 10 | API5 Broken Function Level Auth |
| 100065 | 5 | API2 Login fallido |

## Pipeline de logs de la API

```
Flask → /logs/api.log → volumen opsn_api_logs → montado en wazuh-manager → ossec.conf localfile → reglas 100060-100065
```