#!/bin/bash

# Definir colores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE_BRIGHT='\033[1;34m'    # Azul brillante
RED_BRIGHT='\033[1;31m'     # Rojo brillante
YELLOW_BRIGHT='\033[1;33m'  # Amarillo brillante
GREEN_BRIGHT='\033[1;32m'   # Verde brillante
NC='\033[0m'         # Sin color (resetea el color a default)

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

# Solicitar confirmación del usuario
echo -e "${GREEN}OpenSec Lab, ¿deseas continuar? [s/N]${NC}"
read -r response
if [[ ! "$response" =~ ^([yY]|[sS])$ ]]; then
    echo -e "${RED}Instalación cancelada.${NC}"
    exit 1
fi

# Continuar con el script si el usuario confirma
echo -e "${GREEN}Iniciando la instalación...${NC}"
echo""

# Archivo temporal para almacenar mensajes de error
ERROR_LOG="/tmp/installation_errors.log"
> "$ERROR_LOG" # Limpiar el archivo de log al inicio

# Función para añadir errores al log
log_error() {
    echo -e "${RED}$1${NC}" | tee -a "$ERROR_LOG"
}

# Definir variables
FLAG_FILE="$HOME/OpenSec_Lab/.openseclab_installed"
LAB_DIR="$HOME/OpenSec_Lab"
DC_FILE="$LAB_DIR/docker/docker-compose.yml"
NETWORK_NAME="openseclab"
SUBNET="172.18.0.0/16"

# Función desinstalar

cleanup_previous_installation() {
    echo -e "${GREEN}Limpiando instalación previa...${NC}"
    # Detener y eliminar todos los contenedores y la red Docker
    sudo docker compose -f "$DC_FILE" down > /dev/null 2>&1
    sudo docker network rm $NETWORK_NAME > /dev/null 2>&1
    
    # Buscar y eliminar el volumen dvwa_data, si existe
    VOLUME_NAME=$(sudo docker volume ls | grep dvwa_data | awk '{print $2}')
    if [ ! -z "$VOLUME_NAME" ]; then
        echo -e "${GREEN}Eliminando el volumen $VOLUME_NAME...${NC}"
        sudo docker volume rm "$VOLUME_NAME" > /dev/null 2>&1
    else
        echo -e "${YELLOW_BRIGHT}No se encontró el volumen dvwa_data, continuando...${NC}"
    fi

    # Eliminar las imágenes Docker descargadas
    echo -e "${GREEN}Eliminando las imágenes Docker utilizadas...${NC}"
    sudo docker image rm bkimminich/juice-shop -f > /dev/null 2>&1
    sudo docker image rm howiehowerton/dvwa-howie:v3 -f > /dev/null 2>&1
    
    # Eliminar el directorio LAB_DIR y el archivo de marca
    rm -rf "$LAB_DIR"
    rm -f "$FLAG_FILE"
    echo -e "${GREEN}Limpieza completa.${NC}"
}
X=U2NyaXB0IGRlc2Fycm9sbGFkbyBwb3IgT3BlblNlYw==
# Verificar si Docker está instalado
is_docker_installed() {
    if docker --version &>/dev/null; then
        echo "1"
    else
        echo "0"
    fi
}

start_ssh_tunnel() {

    
    # Ejecuta el comando SSH y procesa su salida en tiempo real
   
    ssh -o ServerAliveInterval=60 -o StrictHostKeyChecking=no -R 80:localhost:3000 nokey@localhost.run 2>&1 | while read -r line; do
        # echo "$line" # Opcional: Imprime toda la salida para depuración
        # Busca la línea que contiene la URL después de "tunneled with tls termination,"
        if echo "$line" | grep -q "tunneled with tls termination,"; then
            URL=$(echo "$line" | grep -oP 'https?://[^\s]+')
            echo -e "${GREEN_BRIGHT}Túnel establecido en: $URL${NC}"
            # Aquí puedes hacer break si solo quieres capturar la primera URL y salir del bucle
            # break
        fi
    done
    
    echo -e "${RED_BRIGHT}El túnel SSH se ha desconectado. Reintentando en 10 segundos...${NC}"
    sleep 10
}

# Verificar si el script ya se ha ejecutado con éxito
if [ -f "$FLAG_FILE" ]; then
    echo "OpenSec Lab ya ha sido instalado."
    echo ""
    echo "Selecciona una opción:"
    echo ""
    echo "1) Reinstalar"
    echo ""
    echo "2) Eliminar todo"
    echo ""
    echo "3) Reiniciar Tunel SSH"
    echo ""
    echo "4) Cancelar"
    echo ""
    read -p "Escoge una opción (1/2/3/4): " user_choice
    
    case $user_choice in
        1)
            cleanup_previous_installation
            ;;
        2)
            cleanup_previous_installation
            echo -e "${RED}OpenSec Lab ha sido eliminado completamente.${NC}"
            exit 0
            ;;

        3)  echo -e "${GREEN}Reiniciando el tunel SSH...${NC}"
            start_ssh_tunnel
            exit 0
            ;;
        4)
            echo "Operación cancelada."
            exit 0
            ;;
        *)
            echo "Opción no válida. Cancelando..."
            exit 1
            ;;
    esac
fi

# Instalar Docker si no está instalado
if [ "$(is_docker_installed)" -eq "0" ]; then
    echo -e "${GREEN}Instalando Docker...${NC}"
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
#Añadir el repositorio para docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
else
    echo -e "${GREEN}Docker ya está instalado, continuando con el resto de la instalación...${NC}"
fi
Y=YWxlamFuZHJvQG9wZW5zZWMubmV0d29yaw==
# Crear estructura de carpetas
echo -e "${GREEN}Creando estructura de carpetas...${NC}"
mkdir -p $LAB_DIR/docker

# Crear y configurar la red Docker personalizada
echo -e "${GREEN}Creando red Docker personalizada...${NC}"
sudo docker network create --subnet=$SUBNET $NETWORK_NAME

# Crear archivo docker-compose.yml
echo -e "${GREEN}Generando archivo docker-compose.yml...${NC}"
cat <<EOF > $DC_FILE
version: '3.7'
services:

  dvwa:
    image: howiehowerton/dvwa-howie:v3
    container_name: opsn-dvwa
    volumes:
      - dvwa_data:/var
    networks:
      $NETWORK_NAME:
        ipv4_address: 172.18.0.3
    ports:
      - "8080:80"

  juice-shop:
    image: bkimminich/juice-shop
    container_name: opsn-juice-shop
    networks:
      $NETWORK_NAME:
        ipv4_address: 172.18.0.4
    ports:
      - "3000:3000"

volumes:
  dvwa_data:

networks:
  $NETWORK_NAME:
    external: true
    name: $NETWORK_NAME
EOF

# Ejecutar docker compose
echo -e "${GREEN}Levantando contenedores Docker con docker compose...${NC}"
sudo docker compose -f $DC_FILE up -d

# Validar que todos los contenedores estén corriendo
echo -e "${GREEN}Validando el estado de los contenedores...${NC}"
CONTAINERS=$(sudo docker compose -f $DC_FILE config --services)
ALL_UP=true

for CONTAINER in $CONTAINERS; do
    STATE=$(sudo docker inspect --format="{{.State.Running}}" $(sudo docker compose -f $DC_FILE ps -q $CONTAINER) 2>/dev/null)

    if [ "$STATE" != "true" ]; then
        echo -e "${RED}El contenedor $CONTAINER no se ha levantado correctamente.${NC}"
        ALL_UP=false
    else
        echo -e "${GREEN}El contenedor $CONTAINER está corriendo.${NC}"
    fi
done

if [ "$ALL_UP" = true ]; then
    echo -e "${GREEN}Todos los contenedores están corriendo.${NC}"
else
    echo -e "${RED}Algunos contenedores no se levantaron correctamente. Revisa los logs para más detalles.${NC}"
fi

if [ ! -s "$ERROR_LOG" ]; then
    touch "$FLAG_FILE"
    echo -e "${GREEN}La instalación ha finalizado con éxito.${NC}"
else
    echo -e "${RED}Se encontraron errores durante la instalación. Considera corregir los errores y volver a ejecutar el script.${NC}"
fi

# Limpieza: Borrar el archivo de log de errores al finalizar
rm "$ERROR_LOG"
z=T3BlbiBTZWN1cml0eSBOZXR3b3Jr
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

# Start the SSH tunnel in the background
start_ssh_tunnel &

#echo -e "${RED}IMPORTANTE: Necesitas reiniciar tu sesión para usar Docker sin necesidad de sudo${NC}"
echo -e "${GREEN}Este script debe ejecutarse en un entorno de pruebas, no en sistemas de producción.${NC}"
