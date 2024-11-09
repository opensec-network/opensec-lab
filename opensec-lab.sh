#!/bin/bash

#######################
## Algunas variables ##
#######################

# Variables de release
# Version
VERSION="2.0"
OPSN_CONTAINERS="opsn-dvwa opsn-juice-shop opsn-gophish opsn-desktop opsn-dns"
INSTALLED_CONTAINERS=""
NON_INSTALLED_CONTAINERS=""
SELECTED_CONTAINERS=""
SUDO_CMD=""

# Definir colores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE_BRIGHT='\033[1;34m'    # Azul brillante
RED_BRIGHT='\033[1;31m'     # Rojo brillante
YELLOW_BRIGHT='\033[1;33m'  # Amarillo brillante
GREEN_BRIGHT='\033[1;32m'   # Verde brillante
NC='\033[0m'                # Sin color (resetea el color a default)

# Definir variables
FLAG_FILE="$HOME/OpenSec_Lab/.openseclab_installed"
LAB_DIR="$HOME/OpenSec_Lab"
DC_FILE="$LAB_DIR/docker/docker-compose.yml"
NETWORK_NAME="openseclab"
SUBNET="172.18.0.0/16"
ERROR_LOG="$HOME/OpenSec_Lab/installation_errors.log"
LAB_LOG=$ERROR_LOG
UNINSTALL_LOG="/tmp/OpenSec_Lab_Uninstall.log"
PREINSTALL_LOG="/tmp/OpenSec_Lab_PreInstall.log"
RECENT_ERROR=0

#################
### Funciones ###
#################


# Función para añadir errores al log
log_error() {
    RECENT_ERROR=1
    echo -e "${RED}$1${NC}" | tee -a "$ERROR_LOG"
}

# Función para manejar errores
handle_error() {
    local exit_code=$1
    local msg=$2
    local suppress_output=${3:-false}  # Toma el tercer argumento, si no se proporciona, es false por defecto
    local color
    local logmsg

    # Garantizar que el archivo exista
    if [ ! -f "$ERROR_LOG" ]; then
        touch "$ERROR_LOG"
    fi

    if [ "$exit_code" -eq 0 ]; then
        color=$GREEN
        logmsg="INFO: $msg" 
    elif [ "$exit_code" -eq -1 ]; then
        color=$RED
        logmsg="ERROR: $msg" 
    else
        color=$YELLOW_BRIGHT
        logmsg="WARNING: $msg" 
    fi

    # Solo imprimir el mensaje si suppress_output es false
    if [ "$suppress_output" = false ]; then
        echo -e "${color}$msg${NC}"
    fi

    echo "$(date +'%Y-%m-%d %H:%M:%S') - $logmsg" >> $ERROR_LOG
}



#Funcion para validar si el usuario puede ejecutar docker sin la necesidad de sudo
sudo_docker() {
  # Verificar si se pueden ejecutar comandos Docker sin sudo
  if ! docker info &>/dev/null; then
    # Verificar si el usuario actual ya está en el grupo docker
    exit_code=$?
    #echo -e "${RED}El usuario $USER no puede ejecutar comandos de Docker sin sudo, usando sudo...${NC}"
    handle_error $exit_code "El usuario $USER no puede ejecutar comandos de Docker sin sudo, usando sudo..." true
    SUDO_CMD="sudo"
    if id -nG "$USER" | grep -qw docker; then
      #echo -e "${RED}El usuario $USER ya está en el grupo docker, pero necesita reiniciar la sesión para aplicar los cambios.${NC}"
      handle_error 0 "El usuario $USER ya está en el grupo docker, pero necesita reiniciar la sesión para aplicar los cambios." 
    else
      #echo -e "${RED}El usuario $USER no se encontraba en el grupo docker, agregando el usuario al grupo docker${NC}"
      handle_error 0 "El usuario $USER no se encontraba en el grupo docker, agregando el usuario al grupo docker"
      sudo usermod -aG docker $USER
      exit_code=$?
      handle_error $exit_code "sudo usermod -aG docker $USER"  true    
    fi
    instrucciones_finales
  #else
    #echo "El usuario $USER puede ejecutar comandos de Docker sin sudo."
  fi
}

# Función principal de limpieza
borrar_todo() {
    ERROR_LOG=$UNINSTALL_LOG
    handle_error 0 "Limpiando instalación previa..."
    
    eliminar_contenedores $INSTALLED_CONTAINERS;

    echo

    for CONTAINER in $OPSN_CONTAINERS; do
        if $SUDO_CMD docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
            $SUDO_CMD docker rm $CONTAINER
            exit_code=$?
            handle_error $exit_code "$SUDO_CMD docker rm $CONTAINER"  true
        fi
    done
    
    $SUDO_CMD docker network rm $NETWORK_NAME > /dev/null 2>&1
    exit_code=$?
    handle_error $exit_code "$SUDO_CMD docker network rm $NETWORK_NAME > /dev/null 2>&1"  true
    
    handle_error 0 "Removiendo usuario de grupo docker: $USER"
    sudo gpasswd -d $USER docker 

    exit_code=$?
    handle_error $exit_code "sudo gpasswd -d $USER docker" true


    rm -rf "$LAB_DIR"
    exit_code=$?
    handle_error $exit_code "rm -rf '$LAB_DIR'"  true
    handle_error 0 "Limpieza completa."
    echo
}

contenedores_instalados(){
    # echo -e "${GREEN}Buscando contenedores instalados...${NC}"
    INSTALLED_CONTAINERS=""
    NON_INSTALLED_CONTAINERS=""
    
    for CONTAINER in $OPSN_CONTAINERS; do
        if $SUDO_CMD docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
            INSTALLED_CONTAINERS+=$CONTAINER" "
        else
            NON_INSTALLED_CONTAINERS+=$CONTAINER" "
        fi
    done

    if [ -n "$INSTALLED_CONTAINERS" ]; then
        handle_error 0 "Contenedores instalados:  $INSTALLED_CONTAINERS"
    fi

    if [ -n "$NON_INSTALLED_CONTAINERS" ]; then
        handle_error 0 "Contenedores NO instalados:  $NON_INSTALLED_CONTAINERS"
    fi

    if [ -z "$INSTALLED_CONTAINERS" ]; then
        handle_error 0 "No se encontraron contenedores instalados."
    fi
    echo
}

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
            return 0
        fi
        sleep 1
        ((attempt++))
    done

    handle_error -1 "No se pudo obtener la contraseña de Gophish después de $max_attempts intentos."
    return 1
}

# Crear archivo docker-compose.yml basado en la selección del usuario
generate_docker_compose() {
handle_error 0 "Generando archivo docker-compose.yml..."
cat <<EOF > $DC_FILE
# version: '3.9'
services:
    opsn-dvwa:
        image: howiehowerton/dvwa-howie:v3
        container_name: opsn-dvwa
        restart: unless-stopped
        volumes:
            - dvwa_data:/var
        networks:
            $NETWORK_NAME:
                ipv4_address: 172.18.0.3
        ports:
            - "8080:80"
        profiles:
            - disabled
    opsn-juice-shop:
        image: bkimminich/juice-shop
        container_name: opsn-juice-shop
        restart: unless-stopped
        networks:
            $NETWORK_NAME:
                ipv4_address: 172.18.0.4
        ports:
            - "3000:3000"
        profiles:
            - disabled
    opsn-gophish:
        image: opensecnetwork/gophish:multi-arch
        container_name: opsn-gophish
        restart: unless-stopped
        volumes:
            - gophish:/opt/gophish
        networks:
            $NETWORK_NAME:
                ipv4_address: 172.18.0.5
        ports:
            - "3333:3333"
            - "80:80"
        profiles:
            - disabled
    opsn-desktop:
        image: lscr.io/linuxserver/webtop:ubuntu-kde
        container_name: opsn-desktop
        security_opt:
            - seccomp:unconfined
        environment:
            - PUID=1000
            - PGID=1000
            - TZ=Etc/UTC
            - TITLE=OPSN Desktop
        volumes:
            - $LAB_DIR/opsn-desktop/init.sh:/etc/cont-init.d/99-init-and-install.sh
            - $LAB_DIR/opsn-desktop/custom-init.sh:/custom-cont-init.d/custom-init.sh
            - $LAB_DIR/opsn-desktop/opsn-background.jpg:/config/opsn-background.jpg:ro
            - webtop_data:/config
        networks:
            $NETWORK_NAME:
                ipv4_address: 172.18.0.6
        ports:
            - 3100:3000
            - 3101:3001
        profiles:
            - disabled
        shm_size: "1gb" #opcional
        restart: unless-stopped
    opsn-dns:
        image: technitium/dns-server:latest
        container_name: opsn-dns
        ports:
            - "5380:5380"
            - "53:53/udp"
            - "53:53/tcp"
        environment:
            - DNS_SERVER_DOMAIN=dns.opensec.lab
            - DNS_SERVER_ADMIN_PASSWORD=Password
            - DNS_SERVER_FORWARDERS=172.18.0.1
        volumes:
            - ./configure_dns.sh:/configure_dns.sh
            - opsn_dns_config:/etc/dns/config
        entrypoint: sh -c "/opt/technitium/dns/start.sh & /configure_dns.sh & wait"
        restart: unless-stopped
        networks:
            $NETWORK_NAME:
                ipv4_address: 172.18.0.2
volumes:
    dvwa_data:
    gophish:
    webtop_data:
    opsn_dns_config:
networks:
    $NETWORK_NAME:
        external: true
EOF
}

# Función para desinstalar contenedores seleccionados V2 Cesar
eliminar_contenedores() {
    handle_error 0 "Eliminando contenedores seleccionados...${NC}"
    local containers_to_remove="$@"
    update_profiles "todelete" $containers_to_remove
    $SUDO_CMD docker compose -f $DC_FILE --profile "todelete" down --volumes --rmi all
    exit_code=$?
    handle_error $exit_code '$SUDO_CMD docker compose -f $DC_FILE --profile "todelete" down --volumes --rmi all' true
    update_profiles "disabled" $containers_to_remove
    contenedores_instalados
    handle_error 0 "Proceso de eliminación de contenedores completado.${NC}"
}

validate_containers() {
    handle_error 0 "Validando el estado de los contenedores...${NC}"
    CONTAINERS=$($SUDO_CMD docker compose -f $DC_FILE --profile enabled config --services)
    ALL_UP=true
    for CONTAINER in $CONTAINERS; do
        STATE=$($SUDO_CMD docker inspect --format="{{.State.Running}}" $($SUDO_CMD docker compose -f $DC_FILE ps -q $CONTAINER) 2>/dev/null)
        if [ "$STATE" != "true" ]; then
            handle_error -1 "El contenedor $CONTAINER no se ha levantado correctamente."
            ALL_UP=false
        else
            # echo -e "${GREEN}El contenedor $CONTAINER está corriendo.${NC}"
            if [ "$CONTAINER" = "opsn-gophish" ]; then
                extract_gophish_password
                echo
            fi
        fi
    done
    echo
    if [ "$ALL_UP" = true ]; then
        handle_error 0 "Todos los contenedores están corriendo.${NC}"
    else
        handle_error -1 "Algunos contenedores no se levantaron correctamente. Revisa los logs para más detalles."
        handle_error -1 "Ruta del log: ${NC} $ERROR_LOG${NC}"
    fi
}


# Función para actualizar el atributo 'profiles' de las imágenes especificadas en un archivo YAML
update_profiles() {
  local NEW_PROFILES=$1
  shift

  # Verificar si se proporcionaron los argumentos necesarios
  if [ $# -lt 1 ]; then
    handle_error -1 "Uso: update_profiles NEW_PROFILES YAML_FILE service_name1 [service_name2 ...]"
    return 1
  fi

 # Convertir NEW_PROFILES a JSON array
  local NEW_PROFILES_JSON=$(printf '[\"%s\"]' "$NEW_PROFILES")

  # Iterar sobre cada container_name proporcionado como argumento
  for CONTAINER_NAME in "$@"; do
    yq -y --in-place --argjson new_profiles "$NEW_PROFILES_JSON" '
      (.services[] | select(.container_name == "'$CONTAINER_NAME'") | .profiles) = $new_profiles
    ' "$DC_FILE"
  done
}

inicio(){
    clear
    # Arte ASCII con colores y signos de dólar escapados
    echo -e "${BLUE_BRIGHT}"'  ______                                  ______                      '"${NC}"
    echo -e "${RED_BRIGHT}"' /      \                                /      \                     '"${NC}"
    echo -e "${YELLOW_BRIGHT}"'/$$$$$$  |  ______    ______   _______  / $$$$$$ |   ______    _______ '"${NC}"
    echo -e "${GREEN_BRIGHT}"'$$ |  $$ | /      \  /      \ /       \ $$ \__$$/   /      \  /       |'"${NC}"
    echo -e "${BLUE_BRIGHT}"'$$ |  $$ |/$$$$$$  |/$$$$$$  |$$$$$$$  |$$      \  /$$$$$$  |/$$$$$$$/ '"${NC}"
    echo -e "${RED_BRIGHT}"'$$ |  $$ |$$ |  $$ |$$    $$ |$$ |  $$ | $$$$$$  | $$    $$ |$$ |      '"${NC}"
    echo -e "${YELLOW_BRIGHT}"'$$ \__$$ |$$ |__$$ |$$$$$$$$/ $$ |  $$ |/  \__$$ | $$$$$$$$/ $$ \_____ '"${NC}"
    echo -e "${GREEN_BRIGHT}"'$$    $$/ $$    $$/ $$       |$$ |  $$ |$$    $$/  $$       |$$       |'"${NC}"
    echo -e "${BLUE_BRIGHT}"' $$$$$$/  $$$$$$$/   $$$$$$$/ $$/   $$/  $$$$$$/    $$$$$$$/  $$$$$$$/  '"${NC}"
    echo -e "${RED_BRIGHT}"'          $$ |                                                         '"${NC}"
    echo -e "${YELLOW_BRIGHT}"'          $$ |                                                         '"${NC}"
    echo -e "${GREEN_BRIGHT}"'          $$/                                                          '"${NC}"
    echo 
    echo
    echo -e "${GREEN}Este script debe ejecutarse en un entorno de pruebas, no en sistemas de producción.${NC}"
    echo
    echo
    inicializar_carpeta
}

inicializar_carpeta(){
    if [ ! -d "$LAB_DIR" ]; then
        ERROR_LOG=$PREINSTALL_LOG
        # Solicitar confirmación del usuario
        handle_error 0 "Este script preparara la instalación de el OpenSec Lab, ¿deseas continuar? [s/N]"
        read -r response
        handle_error 0 "Response: $response" true
        if [[ ! "$response" =~ ^([yY]|[sS])$ ]]; then
            handle_error -1 "Instalación cancelada."
            exit 1
        fi
        # Si no existe, crear la carpeta
        mkdir -p "$LAB_DIR"
        exit_code=$?
        handle_error $exit_code 'mkdir -p "$LAB_DIR"' true
        ERROR_LOG=$LAB_LOG
        #echo "La carpeta $LAB_DIR ha sido creada."
    #else
        #echo "La carpeta $LAB_DIR ya existe."
    fi
}

menu(){
    inicio
    sudo_docker
    #Verificar instalaciones previas
    if [ ! -f "$DC_FILE" ]; then
        handle_error 1 "**** No se ha encontrado una instalación previa ****"
        instalar_binarios
        sleep 1
        inicio
    fi

    contenedores_instalados
    if [ -n "$INSTALLED_CONTAINERS" ]; then
        validate_containers
        echo
    fi
    echo

    echo "Selecciona una opción:"

    echo "1) Instalar contenedores"
    echo "2) Eliminar contenedores"
    echo "3) Reinstalar contenedores (Por que quiero una instalación fresca)"
    echo "4) Eliminar todo"
    echo "5) Actualizar definiciones (yaml)"
    echo "q) Salir"
    echo 

    read -p "Escoge una opción: " user_choice

    echo

    case $user_choice in
            1)
                seleccionar_contenedores $NON_INSTALLED_CONTAINERS
                if [ -n  "$SELECTED_CONTAINERS" ]; then
                    handle_error 0 "Contenedores a instalar:  $SELECTED_CONTAINERS"
                    instalar_contenedores $SELECTED_CONTAINERS
                else
                    handle_error -1 "Ningun contenedor seleccionado: $SELECTED_CONTAINERS"
                fi
                ;;
            2)
                seleccionar_contenedores $INSTALLED_CONTAINERS
                if [ -n  "$SELECTED_CONTAINERS" ]; then
                    handle_error -1 "Contenedores a eliminar: $SELECTED_CONTAINERS"
                    eliminar_contenedores $SELECTED_CONTAINERS
                else
                    handle_error -1 "Ningun contenedor seleccionado: $SELECTED_CONTAINERS"
                fi
                ;;
            3)
                seleccionar_contenedores $INSTALLED_CONTAINERS
                if [ -n  "$SELECTED_CONTAINERS" ]; then
                    handle_error 1 "Contenedores a reinstalar: $SELECTED_CONTAINERS"
                    eliminar_contenedores $SELECTED_CONTAINERS
                    instalar_contenedores $SELECTED_CONTAINERS
                else
                    handle_error -1 "Ningun contenedor seleccionado: $SELECTED_CONTAINERS"
                fi
                ;;
            4)
                handle_error -1 "Eliminar todo"
                borrar_todo
                return 0;
                ;;
            5)
                generate_docker_compose
                update_profiles "enabled" $INSTALLED_CONTAINERS
                ;;
            q)
                return 0
                ;;
            *)
                handle_error -1 "Opción no válida. Cancelando..."
                ;;
        esac
    sleep 1
    return 1
}

instalar_binarios(){
    # Continuar con el script si el usuario confirma
    # echo -e "${GREEN}Iniciando la instalación de binarios...${NC}"

    # Solicitar confirmación del usuario
    echo -ne "${GREEN}OpenSec Lab; estaremos instalando alguno paquetes incluyendo docker, ¿deseas continuar? [s/N]: ${NC}"
    handle_error 0 "OpenSec Lab; estaremos instalando alguno paquetes incluyendo docker, ¿deseas continuar? [s/N]: " true
    read response
    if [[ ! "$response" =~ ^([yY]|[sS])$ ]]; then
         handle_error -1 "Instalación cancelada."
         exit 1
     fi

    # Detectar sistema operativo
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    fi

    # Instalar yq
    sudo apt-get update
    exit_code=$?
    handle_error $exit_code 'sudo apt-get update' true

    if  type yq > /dev/null; then
        handle_error 0 true
    else
        sudo apt-get install -y yq 
        exit_code=$?
        handle_error $exit_code 'sudo apt-get install -y yq ' true
    fi
    

    # Instalar Docker si no está instalado
    if ! type docker > /dev/null; then
        handle_error 0 "Instalando Docker..."
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
        exit_code=$?
        handle_error $exit_code 'sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release' true
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo sh -c 'gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg'
        exit_code=$?
        handle_error $exit_code 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo sh -c 'gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg'' true

        #Añadir el repositorio para docker
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        exit_code=$?
        handle_error $exit_code 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null' true
        sudo apt-get update
        exit_code=$?
        handle_error $exit_code 'sudo apt-get update' true
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        exit_code=$?
        handle_error $exit_code 'sudo apt-get install -y docker-ce docker-ce-cli containerd.io' true
        # instrucciones_finales
    else
        handle_error 0 "Docker ya está instalado, continuando con el resto de la instalación..."
    fi

    # Crear estructura de carpetas
    handle_error 0 "Creando estructura de carpetas..."
    mkdir -p $LAB_DIR/docker
    exit_code=$?
    handle_error $exit_code 'mkdir -p $LAB_DIR/docker' true

    generate_docker_compose

    # Crear y configurar la red Docker personalizada
    if [ "$( $SUDO_CMD docker network ls -f name=$NETWORK_NAME|grep $NETWORK_NAME |wc -l )" -eq "0" ]; then
        echo -e "${GREEN}Creando red Docker personalizada...${NC}"
        $SUDO_CMD docker network create --subnet=$SUBNET $NETWORK_NAME
        exit_code=$?
        handle_error $exit_code '' true
    else   
        echo -e "Red ya existente, reusando..."
    fi
}

# Función para preparar los contenedores
preparar_contenedores() {
  # Iterar sobre cada container_name proporcionado como argumento
  for CONTAINER_NAME in "$@"; do
    PREPARE_FILE="https://raw.githubusercontent.com/opensec-network/opensec-lab/refs/heads/main/$CONTAINER_NAME/prepare.sh"
    mkdir -p $LAB_DIR/$CONTAINER_NAME
    cd $LAB_DIR/$CONTAINER_NAME
    status_code=$(curl -o /dev/null --silent --head --write-out '%{http_code}' "$PREPARE_FILE")
    if [[ "$status_code" -eq 200 ]]; then
        /bin/bash -c "$(curl -H "Pragma: no-cache" -fsSL $PREPARE_FILE)"
    fi
  done
}

instalar_contenedores(){
    RECENT_ERROR=0
    local containers_to_install="$@"
    update_profiles "toinstall" $containers_to_install
    preparar_contenedores $containers_to_install

    # Ejecutar docker compose
    handle_error 0 "Levantando contenedores Docker con docker compose..."

    $SUDO_CMD docker compose -f $DC_FILE --profile toinstall up -d
    exit_code=$?
    handle_error $exit_code '$SUDO_CMD docker compose -f $DC_FILE --profile toinstall up -d' true
    update_profiles "enabled" $containers_to_install

    contenedores_instalados

    # Validar que todos los contenedores estén corriendo

    if [ $RECENT_ERROR ]; then
        handle_error 0 "La instalación ha finalizado con éxito."
    else
        handle_error -1 "Se encontraron errores durante la instalación. Considera corregir los errores y volver a ejecutar el script."
    fi
}

# Función para seleccionar contenedores de una lista
seleccionar_contenedores() {
  inicio
  local containers_list=("$@")
  local selected_containers=()
  handle_error 0 "Seleccionar contenedores" true
  
  echo "Lista de contenedores disponibles:"
  echo
  
  # Imprimir la lista de contenedores con índices numéricos
  for i in "${!containers_list[@]}"; do
    echo "$((i + 1))) ${containers_list[$i]}"
  done
  echo "a) Todos los contenedores"
  echo
  
  echo -n "Selecciona los contenedores de interés (separados por espacio, por ejemplo: 1 3 4 o 'a' para todos): "
  read -a selected_indices

  if [[ " ${selected_indices[@]} " =~ " a " ]]; then
    # Seleccionar todos los contenedores si se elige 'a'
    selected_containers=("${containers_list[@]}")
  else
    # Mapear los índices seleccionados a los contenedores correspondientes
    for index in "${selected_indices[@]}"; do
      selected_containers+=("${containers_list[$((index - 1))]}")
    done
  fi

  # Convertir el array en una cadena de texto separada por espacio
  SELECTED_CONTAINERS="${selected_containers[*]}"
  
  handle_error 0 "Contenedores seleccionados: $SELECTED_CONTAINERS"
  echo
}

instrucciones_finales(){
    
    # Instrucciones finales al usuario
    echo -e "${YELLOW_BRIGHT}"
    echo "***********************************************************"
    echo " _____                            _              _       "
    echo "|_   _|                          | |            | |      "
    echo "  | |  _ __ ___  _ __   ___  _ __| |_ __ _ _ __ | |_ ___ "
    echo "  | | | '_ \` _ \\| '_ \\ / _ \\| '__| __/ _\` | '_ \\| __/ _ \\"
    echo " _| |_| | | | | | |_) | (_) | |  | || (_| | | | | ||  __/"
    echo "|_____|_| |_| |_| .__/ \\___/|_|   \\__\\__,_|_| |_|\\__\\___|"
    echo "                | |                                      "
    echo "                |_|                                      "
    echo "***********************************************************"

    echo -e "${RED}IMPORTANTE: Necesitas reiniciar tu sesión para usar Docker sin necesidad de sudo${NC}"

}

######################
## Logica Principal ##
######################


# Main loop
while true; do
    if menu; then
        break
    fi
done

handle_error 0 "Hasta pronto."