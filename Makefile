.PHONY: release validate clean help test test-static test-smoke

DIST_DIR := dist
SERVICES  := dns mail desktop gophish wiki gitea portal portainer wazuh suricata

# Genera los tarballs por servicio + checksums (equivalente a lo que hace release.yml)
release: clean
	mkdir -p $(DIST_DIR)
	@for svc in $(SERVICES); do \
		if [ -d "services/$$svc" ]; then \
			tar -czf "$(DIST_DIR)/opsn-$$svc.tar.gz" -C services "$$svc"; \
			echo "  Empaquetado: opsn-$$svc.tar.gz"; \
		fi; \
	done
	cp opensec-lab.sh $(DIST_DIR)/
	cp docker-compose.yml $(DIST_DIR)/
	cp config/defaults.env $(DIST_DIR)/
	cd $(DIST_DIR) && sha256sum * > checksums.sha256
	@echo ""
	@echo "Release generado en $(DIST_DIR)/:"
	@ls -lh $(DIST_DIR)/

# Valida el docker-compose.yml (requiere Docker)
validate:
	@echo "Validando docker-compose.yml..."
	cp config/defaults.env .env
	docker compose config --quiet && echo "Compose: OK"
	rm -f .env
	@echo "Validando sintaxis de opensec-lab.sh..."
	bash -n opensec-lab.sh && echo "opensec-lab.sh: OK"

clean:
	rm -rf $(DIST_DIR)

# Tests estáticos (no requieren Docker corriendo con el lab)
test-static:
	@bash tests/static.sh

# Smoke tests (requieren: docker compose --profile all up -d)
test-smoke:
	@bash tests/smoke.sh

# Todos los tests (estáticos + smoke)
test: test-static test-smoke

help:
	@echo "Targets disponibles:"
	@echo "  make release      — Genera tarballs por servicio en dist/"
	@echo "  make validate     — Valida docker-compose.yml y sintaxis del script"
	@echo "  make test-static  — Tests estáticos (sin Docker)"
	@echo "  make test-smoke   — Smoke tests (requiere lab corriendo)"
	@echo "  make test         — Todos los tests"
	@echo "  make clean        — Elimina el directorio dist/"
