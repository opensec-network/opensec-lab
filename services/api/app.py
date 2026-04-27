#!/usr/bin/env python3
"""
OPSN API -- API vulnerable para practica de OWASP API Security Top 10.

Vulnerabilidades implementadas:
  API1:2023 -- Broken Object Level Authorization (BOLA)
  API2:2023 -- Broken Authentication (tokens que nunca expiran)
  API3:2023 -- Broken Object Property Level Authorization
               (mass assignment + excessive data exposure)
  API5:2023 -- Broken Function Level Authorization

Cada explotacion genera un evento JSON en LOG_FILE (/logs/api.log por defecto),
leido por Wazuh via localfile.
"""

import json
import os
from datetime import datetime, timezone
from functools import wraps

from flask import Flask, request, jsonify, g

app = Flask(__name__)

LOG_FILE = os.environ.get("LOG_FILE", "/logs/api.log")
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

# --- Usuarios en memoria -------------------------------------------------------
USERS = {
    1: {
        "id": 1, "username": "alice", "email": "alice@opensec.lab",
        "role": "user", "password": "alice123",
        "credit_card": "4111-1111-1111-1111", "ssn": "123-45-6789",
        "address": "123 Main St", "salary": 75000,
    },
    2: {
        "id": 2, "username": "bob", "email": "bob@opensec.lab",
        "role": "user", "password": "bob456",
        "credit_card": "4222-2222-2222-2222", "ssn": "987-65-4321",
        "address": "456 Oak Ave", "salary": 80000,
    },
    3: {
        "id": 3, "username": "admin", "email": "admin@opensec.lab",
        "role": "admin", "password": "admin_secret",
        "credit_card": "4333-3333-3333-3333", "ssn": "555-55-5555",
        "address": "789 Admin Rd", "salary": 120000,
    },
}

# Tokens estaticos que nunca expiran -- API2:2023 Broken Authentication
TOKENS = {
    "token_alice": 1,
    "token_bob": 2,
    "token_admin": 3,
}


def _write_log(event_data: dict) -> None:
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "source": "opsn-api",
        "remote_ip": request.remote_addr,
        "method": request.method,
        "path": request.path,
        **event_data,
    }
    try:
        with open(LOG_FILE, "a") as fh:
            fh.write(json.dumps(record) + "\n")
    except OSError:
        pass


def _current_user():
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    user_id = TOKENS.get(token)
    return USERS.get(user_id) if user_id else None


def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        user = _current_user()
        if not user:
            _write_log({"event": "auth_failed", "reason": "invalid_or_missing_token"})
            return jsonify({"error": "Unauthorized"}), 401
        g.current_user = user
        return f(*args, **kwargs)
    return decorated


# --- Health -------------------------------------------------------------------

@app.route("/api/health")
def health():
    return jsonify({"status": "ok", "service": "opsn-api"})


# --- Autenticacion -- API2: token estatico, sin expiracion -------------------

@app.route("/api/auth/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    username = data.get("username", "")
    password = data.get("password", "")

    for user in USERS.values():
        if user["username"] == username and user["password"] == password:
            token = f"token_{username}"
            _write_log({"event": "login_success", "user_id": user["id"],
                        "username": username})
            return jsonify({
                "token": token,
                "note": "Este token nunca expira -- API2:2023 Broken Authentication",
            })

    _write_log({"event": "login_failed", "username": username})
    return jsonify({"error": "Invalid credentials"}), 401


# --- Perfil de usuario -- API1: BOLA + API3: Excessive Data Exposure ---------

@app.route("/api/users/<int:user_id>/profile", methods=["GET"])
@require_auth
def get_user_profile(user_id):
    target = USERS.get(user_id)
    if not target:
        return jsonify({"error": "User not found"}), 404

    if g.current_user["id"] != user_id:
        _write_log({
            "event": "bola_attempt",
            "user_id": g.current_user["id"],
            "target_id": user_id,
        })

    # API3: devuelve todos los campos incluyendo credit_card, ssn, salary
    return jsonify(target)


# --- Actualizar perfil -- API1: BOLA + API3: Mass Assignment -----------------

@app.route("/api/users/<int:user_id>/profile", methods=["PUT"])
@require_auth
def update_user_profile(user_id):
    target = USERS.get(user_id)
    if not target:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json(silent=True) or {}
    updated_fields = list(data.keys())

    if g.current_user["id"] != user_id:
        _write_log({
            "event": "bola_write_attempt",
            "user_id": g.current_user["id"],
            "target_id": user_id,
            "fields": updated_fields,
        })

    if "role" in data or "id" in data:
        _write_log({
            "event": "mass_assignment_attempt",
            "user_id": g.current_user["id"],
            "attempted_fields": updated_fields,
        })

    # Mass assignment: aplica todos los campos sin filtrar
    target.update(data)
    return jsonify({"message": "Updated", "user": target})


# --- Ordenes -- API1: BOLA adicional -----------------------------------------

@app.route("/api/users/<int:user_id>/orders", methods=["GET"])
@require_auth
def get_user_orders(user_id):
    target = USERS.get(user_id)
    if not target:
        return jsonify({"error": "User not found"}), 404

    if g.current_user["id"] != user_id:
        _write_log({
            "event": "bola_attempt",
            "user_id": g.current_user["id"],
            "target_id": user_id,
            "endpoint": f"/api/users/{user_id}/orders",
        })

    orders = [
        {"id": user_id * 100 + 1, "item": "Laptop", "amount": 1200.00,
         "status": "shipped"},
        {"id": user_id * 100 + 2, "item": "Mouse", "amount": 25.00,
         "status": "delivered"},
    ]
    return jsonify({"user_id": user_id, "orders": orders})


# --- Admin -- API5: Broken Function Level Authorization ----------------------

@app.route("/api/admin/users", methods=["GET"])
@require_auth
def list_all_users():
    if g.current_user.get("role") != "admin":
        _write_log({
            "event": "broken_function_auth",
            "user_id": g.current_user["id"],
            "endpoint": "/api/admin/users",
        })

    # Sin verificacion de rol: cualquier usuario autenticado accede
    return jsonify(list(USERS.values()))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
