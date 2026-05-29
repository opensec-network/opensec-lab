#!/usr/bin/env python3
"""Genera el dashboard "OpenSec Lab — Overview" (todos los servicios) y un set de
saved searches como atajos en Discover.

Salidas (en este mismo directorio):
  - lab-overview.ndjson      → dashboard general + sus visualizaciones
  - lab-saved-searches.ndjson → búsquedas guardadas

Todo referencia el index-pattern wazuh-alerts-* y se filtra al universo del lab
con `rule.groups: openseclab*` (captura DVWA, Juice Shop, GoPhish, WebGoat,
Suricata y la API, ya que toda regla del lab cuelga del grupo padre `openseclab`).
"""
import json
import os

INDEX_PATTERN_ID = "wazuh-alerts-*"
TIME_FIELD = "timestamp"
VERSION = "2.13.0"
LAB_QUERY = "rule.groups: openseclab*"

HERE = os.path.dirname(__file__)

INDEX_REF = {
    "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
    "type": "index-pattern",
    "id": INDEX_PATTERN_ID,
}


def search_source(query=None):
    return json.dumps({
        "query": {"language": "kuery", "query": query or ""},
        "filter": [],
        "indexRefName": "kibanaSavedObjectMeta.searchSourceJSON.index",
    })


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


def saved_search(obj_id, title, query, columns):
    return {
        "id": obj_id,
        "type": "search",
        "attributes": {
            "title": title,
            "description": "",
            "hits": 0,
            "columns": columns,
            "sort": [[TIME_FIELD, "desc"]],
            "version": 1,
            "kibanaSavedObjectMeta": {"searchSourceJSON": search_source(query)},
        },
        "references": [INDEX_REF],
    }


def write_ndjson(path, objects):
    with open(path, "w") as f:
        for obj in objects:
            f.write(json.dumps(obj) + "\n")
    print(f"Escrito {path} con {len(objects)} saved objects")


# ─── Index-pattern base ──────────────────────────────────────────────────────
# En una instalación limpia el index-pattern wazuh-alerts-* aún no existe, así que
# los dashboards/búsquedas fallarían el import por missing_references. Generamos
# este archivo con prefijo 00- para que el sidecar lo importe PRIMERO (orden
# alfabético del glob); una vez creado, las referencias de los demás .ndjson
# resuelven contra el objeto ya existente en el sistema.
index_pattern = {
    "id": INDEX_PATTERN_ID,
    "type": "index-pattern",
    "attributes": {"title": INDEX_PATTERN_ID, "timeFieldName": TIME_FIELD},
    "references": [],
}
write_ndjson(os.path.join(HERE, "00-index-pattern-wazuh-alerts.ndjson"),
             [index_pattern])


# ─── Dashboard Overview ──────────────────────────────────────────────────────

overview = []

overview.append(viz("opsn-lab-metric-total", "OpenSec Lab · Total alertas", {
    "title": "OpenSec Lab · Total alertas",
    "type": "metric",
    "aggs": [{"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}}],
    "params": {
        "addTooltip": True, "addLegend": False, "type": "metric",
        "metric": {"percentageMode": False, "useRanges": False, "colorSchema": "Green to Red",
                    "metricColorMode": "None", "colorsRange": [{"from": 0, "to": 100000}],
                    "labels": {"show": True}, "invertColors": False,
                    "style": {"bgFill": "#000", "bgColor": False, "labelColor": False,
                               "subText": "", "fontSize": 60}},
    },
}))

overview.append(viz("opsn-lab-pie-groups", "OpenSec Lab · Alertas por servicio", {
    "title": "OpenSec Lab · Alertas por servicio",
    "type": "pie",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {"field": "rule.groups", "size": 15, "order": "desc", "orderBy": "1",
                     "include": "openseclab_.*"}},
    ],
    "params": {"type": "pie", "addTooltip": True, "addLegend": True,
               "legendPosition": "right", "isDonut": True,
               "labels": {"show": True, "values": True, "last_level": True, "truncate": 100}},
}))

overview.append(viz("opsn-lab-table-rules", "OpenSec Lab · Top reglas", {
    "title": "OpenSec Lab · Top reglas",
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

overview.append(viz("opsn-lab-timeline", "OpenSec Lab · Línea de tiempo", {
    "title": "OpenSec Lab · Línea de tiempo",
    "type": "histogram",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": TIME_FIELD, "useNormalizedOsdInterval": True,
                     "interval": "auto", "drop_partials": False, "min_doc_count": 1}},
        {"id": "3", "enabled": True, "type": "terms", "schema": "group",
         "params": {"field": "rule.groups", "size": 6, "order": "desc", "orderBy": "1",
                     "include": "openseclab_.*"}},
    ],
    "params": {"type": "histogram", "grid": {"categoryLines": False},
               "categoryAxes": [{"id": "CategoryAxis-1", "type": "category", "position": "bottom",
                                  "show": True, "scale": {"type": "linear"},
                                  "labels": {"show": True, "filter": True, "truncate": 100}, "title": {}}],
               "valueAxes": [{"id": "ValueAxis-1", "name": "LeftAxis-1", "type": "value",
                               "position": "left", "show": True,
                               "scale": {"type": "linear", "mode": "normal"},
                               "labels": {"show": True, "rotate": 0, "filter": False, "truncate": 100},
                               "title": {"text": "Count"}}],
               "seriesParams": [{"show": True, "type": "histogram", "mode": "stacked",
                                  "data": {"label": "Count", "id": "1"}, "valueAxis": "ValueAxis-1",
                                  "drawLinesBetweenPoints": True, "showCircles": True}],
               "addTooltip": True, "addLegend": True, "legendPosition": "right",
               "times": [], "addTimeMarker": False, "labels": {}, "thresholdLine": {"show": False}},
}))

overview.append(viz("opsn-lab-pie-mitre", "OpenSec Lab · Técnicas MITRE", {
    "title": "OpenSec Lab · Técnicas MITRE",
    "type": "pie",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {"field": "rule.mitre.technique", "size": 12, "order": "desc", "orderBy": "1"}},
    ],
    "params": {"type": "pie", "addTooltip": True, "addLegend": True,
               "legendPosition": "right", "isDonut": True,
               "labels": {"show": True, "values": True, "last_level": True, "truncate": 100}},
}))

overview.append(viz("opsn-lab-bar-level", "OpenSec Lab · Severidad", {
    "title": "OpenSec Lab · Severidad",
    "type": "histogram",
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {"field": "rule.level", "size": 16, "order": "desc", "orderBy": "_key"}},
    ],
    "params": {"type": "histogram", "grid": {"categoryLines": False},
               "categoryAxes": [{"id": "CategoryAxis-1", "type": "category", "position": "bottom",
                                  "show": True, "scale": {"type": "linear"},
                                  "labels": {"show": True, "filter": True, "truncate": 100},
                                  "title": {"text": "rule.level"}}],
               "valueAxes": [{"id": "ValueAxis-1", "name": "LeftAxis-1", "type": "value",
                               "position": "left", "show": True,
                               "scale": {"type": "linear", "mode": "normal"},
                               "labels": {"show": True, "rotate": 0, "filter": False, "truncate": 100},
                               "title": {"text": "Count"}}],
               "seriesParams": [{"show": True, "type": "histogram", "mode": "normal",
                                  "data": {"label": "Count", "id": "1"}, "valueAxis": "ValueAxis-1",
                                  "drawLinesBetweenPoints": True, "showCircles": True}],
               "addTooltip": True, "addLegend": False, "times": [], "addTimeMarker": False,
               "labels": {"show": True}, "thresholdLine": {"show": False}},
}))

panels = [
    ("opsn-lab-metric-total", {"x": 0,  "y": 0,  "w": 12, "h": 9}),
    ("opsn-lab-bar-level",    {"x": 0,  "y": 9,  "w": 12, "h": 14}),
    ("opsn-lab-pie-groups",   {"x": 12, "y": 0,  "w": 18, "h": 23}),
    ("opsn-lab-table-rules",  {"x": 30, "y": 0,  "w": 18, "h": 23}),
    ("opsn-lab-timeline",     {"x": 0,  "y": 23, "w": 30, "h": 15}),
    ("opsn-lab-pie-mitre",    {"x": 30, "y": 23, "w": 18, "h": 15}),
]

panels_json, references = [], []
for i, (viz_id, grid) in enumerate(panels, start=1):
    grid["i"] = str(i)
    panels_json.append({"version": VERSION, "gridData": grid, "panelIndex": str(i),
                         "embeddableConfig": {}, "panelRefName": f"panel_{i}"})
    references.append({"name": f"panel_{i}", "type": "visualization", "id": viz_id})

overview.append({
    "id": "opsn-lab-overview-dashboard",
    "type": "dashboard",
    "attributes": {
        "title": "OpenSec Lab · Overview",
        "hits": 0,
        "description": "Vista general de todas las alertas del laboratorio OpenSec.",
        "panelsJSON": json.dumps(panels_json),
        "optionsJSON": json.dumps({"useMargins": True, "hidePanelTitles": False}),
        "version": 1,
        "timeRestore": True,
        "timeTo": "now",
        "timeFrom": "now-24h",
        "refreshInterval": {"pause": True, "value": 0},
        "kibanaSavedObjectMeta": {"searchSourceJSON": json.dumps({
            "query": {"language": "kuery", "query": LAB_QUERY}, "filter": []})},
    },
    "references": references,
})

write_ndjson(os.path.join(HERE, "lab-overview.ndjson"), overview)

# ─── Saved searches (atajos en Discover) ─────────────────────────────────────

searches = [
    saved_search("opsn-search-all-attacks", "OpenSec Lab · Todos los ataques",
                 "rule.groups: openseclab*",
                 ["rule.level", "rule.description", "agent.name"]),
    saved_search("opsn-search-api", "OpenSec Lab · Solo API",
                 "rule.groups: openseclab_api",
                 ["data.event", "rule.description", "data.path", "data.user_id", "data.target_id"]),
    saved_search("opsn-search-suricata", "OpenSec Lab · Solo Suricata IDS",
                 "rule.groups: suricata",
                 ["rule.level", "rule.description"]),
    saved_search("opsn-search-dvwa", "OpenSec Lab · Solo DVWA",
                 "rule.groups: openseclab_dvwa",
                 ["rule.level", "rule.description", "data.url"]),
]

write_ndjson(os.path.join(HERE, "lab-saved-searches.ndjson"), searches)
