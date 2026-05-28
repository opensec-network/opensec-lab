#!/usr/bin/env python3
"""Genera el NDJSON del dashboard "API Breach to Detection" para Wazuh/OpenSearch Dashboards.

Salida: api-breach-dashboard.ndjson (saved objects importables vía
/api/saved_objects/_import). Todas las visualizaciones referencian el
index-pattern wazuh-alerts-* y filtran por rule.groups: openseclab_api.
"""
import json
import os

INDEX_PATTERN_ID = "wazuh-alerts-*"
TIME_FIELD = "timestamp"
VERSION = "2.13.0"
QUERY = "rule.groups: openseclab_api"

OUT = os.path.join(os.path.dirname(__file__), "api-breach-dashboard.ndjson")

INDEX_REF = {
    "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
    "type": "index-pattern",
    "id": INDEX_PATTERN_ID,
}


def search_source(query=None):
    src = {"query": {"language": "kuery", "query": query or ""},
           "filter": [],
           "indexRefName": "kibanaSavedObjectMeta.searchSourceJSON.index"}
    return json.dumps(src)


def viz(obj_id, title, vis_state, query=None):
    return {
        "id": obj_id,
        "type": "visualization",
        "attributes": {
            "title": title,
            "visState": json.dumps(vis_state),
            "uiStateJSON": "{}",
            "description": "",
            "version": 1,
            "kibanaSavedObjectMeta": {"searchSourceJSON": search_source(query)},
        },
        "references": [INDEX_REF],
    }


objects = []

# 1) Metric: total de detecciones del taller
objects.append(viz("opsn-api-metric-total", "OPSN API · Total detecciones", {
    "title": "OPSN API · Total detecciones",
    "type": "metric",
    "aggs": [{"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}}],
    "params": {
        "addTooltip": True, "addLegend": False, "type": "metric",
        "metric": {
            "percentageMode": False, "useRanges": False, "colorSchema": "Green to Red",
            "metricColorMode": "None", "colorsRange": [{"from": 0, "to": 10000}],
            "labels": {"show": True}, "invertColors": False,
            "style": {"bgFill": "#000", "bgColor": False, "labelColor": False,
                       "subText": "", "fontSize": 60},
        },
    },
}))

# 2) Donut: por tipo de ataque (data.event)
objects.append(viz("opsn-api-pie-event", "OPSN API · Ataques por tipo", {
    "title": "OPSN API · Ataques por tipo",
    "type": "pie",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {"field": "data.event", "size": 10, "order": "desc", "orderBy": "1"}},
    ],
    "params": {"type": "pie", "addTooltip": True, "addLegend": True,
               "legendPosition": "right", "isDonut": True,
               "labels": {"show": True, "values": True, "last_level": True, "truncate": 100}},
}))

# 3) Tabla: reglas disparadas (rule.description) con nivel
objects.append(viz("opsn-api-table-rules", "OPSN API · Reglas disparadas", {
    "title": "OPSN API · Reglas disparadas",
    "type": "table",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {"field": "rule.description", "size": 25, "order": "desc", "orderBy": "1"}},
        {"id": "3", "enabled": True, "type": "max", "schema": "metric",
         "params": {"field": "rule.level"}},
    ],
    "params": {"perPage": 10, "showPartialRows": False, "showMetricsAtAllLevels": False,
               "showTotal": True, "totalFunc": "sum", "percentageCol": ""},
}))

# 4) Barras verticales: línea de tiempo por tipo de ataque
objects.append(viz("opsn-api-timeline", "OPSN API · Línea de tiempo", {
    "title": "OPSN API · Línea de tiempo",
    "type": "histogram",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": TIME_FIELD, "useNormalizedOsdInterval": True,
                     "interval": "auto", "drop_partials": False, "min_doc_count": 1}},
        {"id": "3", "enabled": True, "type": "terms", "schema": "group",
         "params": {"field": "data.event", "size": 5, "order": "desc", "orderBy": "1"}},
    ],
    "params": {"type": "histogram", "grid": {"categoryLines": False},
               "categoryAxes": [{"id": "CategoryAxis-1", "type": "category", "position": "bottom",
                                  "show": True, "scale": {"type": "linear"},
                                  "labels": {"show": True, "filter": True, "truncate": 100},
                                  "title": {}}],
               "valueAxes": [{"id": "ValueAxis-1", "name": "LeftAxis-1", "type": "value",
                               "position": "left", "show": True, "scale": {"type": "linear", "mode": "normal"},
                               "labels": {"show": True, "rotate": 0, "filter": False, "truncate": 100},
                               "title": {"text": "Count"}}],
               "seriesParams": [{"show": True, "type": "histogram", "mode": "stacked",
                                  "data": {"label": "Count", "id": "1"},
                                  "valueAxis": "ValueAxis-1", "drawLinesBetweenPoints": True,
                                  "showCircles": True}],
               "addTooltip": True, "addLegend": True, "legendPosition": "right",
               "times": [], "addTimeMarker": False, "labels": {}, "thresholdLine": {"show": False}},
}))

# 5) Tabla: endpoints atacados (data.path)
objects.append(viz("opsn-api-table-paths", "OPSN API · Endpoints atacados", {
    "title": "OPSN API · Endpoints atacados",
    "type": "table",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {"field": "data.path", "size": 25, "order": "desc", "orderBy": "1"}},
    ],
    "params": {"perPage": 10, "showPartialRows": False, "showMetricsAtAllLevels": False,
               "showTotal": True, "totalFunc": "sum", "percentageCol": ""},
}))

# 6) Donut: técnicas MITRE ATT&CK
objects.append(viz("opsn-api-pie-mitre", "OPSN API · Técnicas MITRE", {
    "title": "OPSN API · Técnicas MITRE",
    "type": "pie",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {"field": "rule.mitre.technique", "size": 10, "order": "desc", "orderBy": "1"}},
    ],
    "params": {"type": "pie", "addTooltip": True, "addLegend": True,
               "legendPosition": "right", "isDonut": True,
               "labels": {"show": True, "values": True, "last_level": True, "truncate": 100}},
}))

# Dashboard: layout en grid de 48 columnas
panels = [
    ("opsn-api-metric-total", {"x": 0,  "y": 0,  "w": 12, "h": 9}),
    ("opsn-api-pie-mitre",    {"x": 0,  "y": 9,  "w": 12, "h": 14}),
    ("opsn-api-pie-event",    {"x": 12, "y": 0,  "w": 18, "h": 23}),
    ("opsn-api-table-rules",  {"x": 30, "y": 0,  "w": 18, "h": 23}),
    ("opsn-api-timeline",     {"x": 0,  "y": 23, "w": 28, "h": 15}),
    ("opsn-api-table-paths",  {"x": 28, "y": 23, "w": 20, "h": 15}),
]

panels_json = []
references = []
for i, (viz_id, grid) in enumerate(panels, start=1):
    panel_ref = f"panel_{i}"
    grid["i"] = str(i)
    panels_json.append({
        "version": VERSION,
        "gridData": grid,
        "panelIndex": str(i),
        "embeddableConfig": {},
        "panelRefName": panel_ref,
    })
    references.append({"name": panel_ref, "type": "visualization", "id": viz_id})

dashboard = {
    "id": "opsn-api-breach-dashboard",
    "type": "dashboard",
    "attributes": {
        "title": "OpenSec · API Breach to Detection",
        "hits": 0,
        "description": "Detecciones del taller API Breach (OWASP API Top 10 → Wazuh).",
        "panelsJSON": json.dumps(panels_json),
        "optionsJSON": json.dumps({"useMargins": True, "hidePanelTitles": False}),
        "version": 1,
        "timeRestore": True,
        "timeTo": "now",
        "timeFrom": "now-24h",
        "refreshInterval": {"pause": True, "value": 0},
        "kibanaSavedObjectMeta": {
            "searchSourceJSON": json.dumps({
                "query": {"language": "kuery", "query": QUERY},
                "filter": [],
            })
        },
    },
    "references": references,
}

objects.append(dashboard)

with open(OUT, "w") as f:
    for obj in objects:
        f.write(json.dumps(obj) + "\n")

print(f"Escrito {OUT} con {len(objects)} saved objects")
