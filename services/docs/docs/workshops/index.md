# La ruta: del ataque a la deteccion

OpenSec Lab no es solo una coleccion de objetivos vulnerables. Es una **ruta de aprendizaje** de cuatro talleres que recorren el ciclo completo de seguridad: ejecutas un ataque real y luego encuentras la evidencia que deja, como lo haria un analista defensivo.

Cada taller cubre un **dominio distinto** y enseña una **habilidad de deteccion diferente**. No son el mismo ejercicio repintado: pasar por los cuatro te da una vision amplia de como se detectan ataques de naturalezas muy distintas.

## Orden sugerido

Los talleres son autocontenidos —puedes hacer cualquiera por separado— pero este orden va de lo mas concreto a lo mas avanzado:

| # | Taller | Dominio | Habilidad de deteccion | Nivel |
| --- | --- | --- | --- | --- |
| 1 | [Hacking Web](web-hacking.md) | Aplicacion web (DVWA) | **Firma de payload**: un patron malicioso en el trafico | Principiante |
| 2 | [Ataque y deteccion en APIs](api-breach.md) | API REST | **Eventos estructurados**: la app registra lo que pasa | Intermedio |
| 3 | [Phishing](phishing.md) | Ingenieria social (GoPhish) | **Comportamiento**: el robo de credenciales como accion sospechosa | Intermedio |
| 4 | [Kill Chain](kill-chain.md) | Red / multi-señal | **Correlacion**: hilar varias señales en una historia | Avanzado |

## Que vas a aprender en cada uno

### 1. Hacking Web → deteccion por firma

Explotas SQL Injection, Command Injection, XSS y File Inclusion en DVWA. Aprendes que un IDS de red (Suricata) detecta estos ataques por el **patron** que viaja en el trafico, sin necesidad de leer los logs de la aplicacion. Guia de instructor: [Web Hacking](web-hacking-instructor.md).

### 2. Ataque y deteccion en APIs → eventos de aplicacion

Explotas fallas de logica de una API (BOLA, mass assignment, broken function auth). Aqui la deteccion viene de los **eventos estructurados** que la propia aplicacion escribe y que Wazuh ingiere. Guia de instructor: [APIs](api-breach-instructor.md).

### 3. Phishing → deteccion por comportamiento

Lanzas una campaña de phishing, capturas credenciales con una landing falsa y aprendes a detectar el **robo de credenciales** como un comportamiento sospechoso (credenciales en claro por la red), correlacionando por origen. Guia de instructor: [Phishing](phishing-instructor.md).

### 4. Kill Chain → correlacion

Ejecutas una cadena de ataque (reconocimiento + explotacion) y aprendes la habilidad mas avanzada: **correlacionar** señales separadas que comparten un origen para reconstruir la historia completa, como un analista de SOC. Guia de instructor: [Kill Chain](kill-chain-instructor.md).

## Antes de empezar

- Asegurate de tener `opsn-wazuh` y `opsn-suricata` iniciados para la parte defensiva de cada taller.
- Cada guia lista sus servicios y herramientas en la seccion **Requisitos**.
- Para resetear un taller entre corridas, usa la opcion **15) Reset del taller** del menu del lab.
