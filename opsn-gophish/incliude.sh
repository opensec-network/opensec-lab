#!/bin/bash

# Función para extraer la contraseña de Gophish de los logs
extract_gophish_password() {
    local container_name="opsn-gophish"
    local password=""
    local max_attempts=30
    local attempt=0

    # echo -e "${YELLOW_BRIGHT}Esperando a que Gophish genere la contraseña...${NC}"

    while [ $attempt -lt $max_attempts ]; do
        password=$($SUDO_CMD docker logs $container_name 2>&1 | grep "Please login with the username admin and the password" | awk '{print $NF}' | tr -d '"')
        if [ ! -z "$password" ]; then
            echo 
            handle_error 0 "Contraseña inicial de Gophish: ${RED_BRIGHT}$password"
            handle_error 10 "Ignora este mensaje si ya la cambiaste"
            PASSWORD=$password
            return 0
        fi
        sleep 1
        ((attempt++))
    done

    handle_error -1 "No se pudo obtener la contraseña de Gophish después de $max_attempts intentos."
    return 1
}