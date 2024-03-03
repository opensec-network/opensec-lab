# OpenSec Lab Setup Script

## Descripción
El script opensec-lab.sh automatiza la configuración de un entorno de laboratorio para la seguridad informática especificamente para pruebas de aplicaciones web vulnerables, este script comnsidera la instalación de WebGOAT, DVWA y Juice-Shop en contenedores de Docker, y haciendo un uso eficiente de los recursos de la maquina host. Este entorno está diseñado para ser utilizado para pruebas y aprendizaje en el ámbito de la seguridad informática.

## Prerrequisitos

- El script está diseñado para ejecutarse dentro de una máquina de Kali Linux.
- Tener curl instalado    
- Permisos de superusuario (sudo).    
- Conexión a internet.    

## Instalación

Para una instalación sencilla recomendamos copiar y pegar el siguiente comando en la terminal de Kali Linux. Este script es compatible con arquitecturas ARM64 / AMD64 
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/opensec-network/opensec-lab/main/opensec-lab.sh)"
```
Siga las instrucciones en pantalla para completar la instalación.

**NOTA: No es necesario ejecutarlo con sudo, el script ya incluye los comandos de sudo</span>**

## Reinstalación / Desinstalación

El script está diseñado para poder desinstalar o reinstalar los componentes en caso de ser necesario, para esto solo debe ejecutarlo nuevamente en la terminal y seguir las instrucciones.

## Uso

Tras completar la instalación, su entorno de laboratorio de seguridad estará listo para usar. Puede iniciar los contenedores Docker configurados ejecutando comandos específicos de Docker, dependiendo de las herramientas que haya elegido instalar. Si no hiciste cambios al script los tres contenedores (WebGOAT, DVWA, Juice-Shop) estarán instalados y ejecutandose automaticamente.

**WebGOAT** -> http://localhost:4000  
**Juice-Shop** -> http://localhost:3000   
**DVWA** -> http://localhost:8080  

Para poder tener persistencia de las configuraciones del contenedor **DVWA** el script genera un volumen de docker llamado **docker_dvwa_data**, para poder encontrar la ruta de donde se encuentra el volumen y poder editar sus archivos se debe ejecutar los siguientes comandos:

- Validar que el volumen existe en la máquina
```bash
┌──(opsn㉿kali)-[~]
└─$ sudo docker volume ls
DRIVER    VOLUME NAME
local     2462967684fa0fb6554662e28599ada4860a08c54d488f2e30bf82befc2bd9e0
local     docker_dvwa_data
```

- Buscar el "Mountpoint" para saber exactamente en cual carpeta dentro del host se encuentra manpeado el volumen

```bash
┌──(opsn㉿kali)-[~]
└─$ sudo docker inspect docker_dvwa_data
[
    {
        "CreatedAt": "2024-03-03T08:33:59-05:00",
        "Driver": "local",
        "Labels": {
            "com.docker.compose.project": "docker",
            "com.docker.compose.version": "2.24.6",
            "com.docker.compose.volume": "dvwa_data"
        },
        "Mountpoint": "/var/lib/docker/volumes/docker_dvwa_data/_data",
        "Name": "docker_dvwa_data",
        "Options": null,
        "Scope": "local"
    }
]
 ```                                                                                                                                                                
En el ejemplo anterior el volumen está mapeado a la carpeta `/var/lib/docker/volumes/docker_dvwa_data/_data`

- Para poder editar los archivos dentro de esa carpeta se necesitar tener permisos de root, esto se puede hacer usando `sudo su` como se muestra en el ejemplo a continuación.

```bash
┌──(opsn㉿kali)-[~]
└─$ sudo su                             
┌──(root㉿kali)-[/home/opsn]
└─# cd /var/lib/docker/volumes/docker_dvwa_data/_data
                                                                                                                                                                 
┌──(root㉿kali)-[/var/…/docker/volumes/docker_dvwa_data/_data]
└─# ls
backups  cache  lib  local  lock  log  mail  opt  run  spool  tmp  www
 ```

## Contribuir

Las contribuciones son lo que hace que la comunidad de código abierto sea un lugar increíble para aprender, inspirar y crear. **Cualquier contribución que haga es muy apreciada.**

Si tiene una sugerencia para mejorar esto, por favor fork el repositorio y cree un pull request. También puede simplemente abrir un issue con el tag "mejora". No olvide darle una estrella al proyecto. ¡Gracias de nuevo!

## Licencia

Distribuido bajo la Licencia MIT. Vea LICENSE para más información.

Contacto

Open Security Network - info@opensec.network

URL del Proyecto: https://github.com/opensec-network/opensec-lab
