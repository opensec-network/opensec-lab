# Cheat Sheet — Wazuh para el lab

Comandos y filtros para analizar alertas del OpenSec Lab.

---

## Acceso rapido

| Elemento | Valor |
|----------|-------|
| URL | https://localhost:5601 |
| Usuario | admin |
| Contrasena | SecretPassword |

## Filtros en Security Events

```
group: openseclab
group: openseclab_api
group: openseclab_dvwa
group: openseclab_gophish
group: ids AND suricata
rule.level: [10 TO *]
rule.mitre.id: T1190
rule.id: 100061
```

## Comandos desde terminal

```bash
# Ver logs de Wazuh en tiempo real
docker logs opsn-wazuh-manager -f

# Ver alertas en el archivo de alertas
docker exec opsn-wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json

# Ver log de la API vulnerable
docker exec opsn-wazuh-manager tail -f /var/ossec/logs/api/api.log

# Verificar reglas del lab
docker exec opsn-wazuh-manager \
  grep -c "openseclab" /var/ossec/etc/rules/openseclab.xml
```

## Reglas del lab — referencia rapida

| ID | Nivel | Descripcion |
|----|-------|-------------|
| 100001 | 10 | SQL Injection en DVWA |
| 100002 | 10 | Command Injection en DVWA |
| 100003 | 8 | XSS en DVWA |
| 100004 | 8 | File Inclusion en DVWA |
| 100020 | 7 | Click en landing page GoPhish |
| 100061 | 10 | API1 BOLA lectura |
| 100062 | 12 | API1 BOLA escritura |
| 100063 | 12 | API3 Mass Assignment |
| 100064 | 10 | API5 Broken Function Level Auth |
| 100065 | 5 | API2 Login fallido |
