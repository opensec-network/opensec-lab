# OpenSec Lab Setup Script

## Descripción
El script opensec-lab.sh automatiza la configuración de un entorno de laboratorio para la seguridad informática especificamente para pruebas de aplicaciones web vulnerables, este script considera la instalación de DVWA, Juice-Shop, Gophish, Technitium y un sistema operativo de escritorio en contenedores de Docker, haciendo un uso eficiente de los recursos de la maquina host. Este entorno está diseñado para ser utilizado para pruebas y aprendizaje en el ámbito de la seguridad informática.

## Prerrequisitos

- El script está diseñado para ejecutarse dentro de una máquina de Kali Linux.
- Tener curl instalado    
- Permisos de superusuario (sudo).    
- Conexión a internet.    

## Instalación

Para una instalación sencilla recomendamos copiar y pegar el siguiente comando en la terminal de Kali Linux. Este script es compatible con arquitecturas ARM64 / AMD64 
```bash
/bin/bash -c "$(curl -fsSL https://lab.opensec.network/install)"
```
Siga las instrucciones en pantalla para completar la instalación.

**NOTA: No es necesario ejecutarlo con sudo, el script ya incluye los comandos de sudo</span>**

## Reinstalación / Desinstalación

El script está diseñado para poder desinstalar o reinstalar los componentes en caso de ser necesario, para esto solo debe ejecutarlo nuevamente en la terminal y seguir las instrucciones.

## Uso

Tras completar la instalación, su entorno de laboratorio de seguridad estará listo para usar. Puede iniciar los contenedores Docker configurados ejecutando comandos específicos de Docker, dependiendo de las herramientas que haya elegido instalar. A continuación las contraseñas por defecto, toma en cuenta que algunos contenedores como DVWA requerirán un cambio de contraseña al primer inicio de sesión.
  
| Aplicación    | Usuario   | Contraseña| URL                 
|---------------|-----------|-----------|---------------------------|
| Juice Shop    | N/A       | Ver Nota  | http://localhost:3000     |
| DVWA          | admin     | admin     | http://localhost:8080     |
| Gophish       | admin     | Ver Nota  | http://localhost:3333     |
| OPSN DNS      | admin     | admin     | http://localhost:5380     |
| OPSN Desktop  | abc       | abc       | http://localhost:3100     |

<div style="background-color: #d4edda; border-left: 5px solid #28a745; padding: 10px;">
  <strong>Nota:</strong>
  <ul>
    <li>La contraseña de Gophish se genera aleatoriamente al momento de la instalación, el script te mostrará la contraseña tan pronto se instale el contenedor.</li>
    <li>Obtener acceso a una cuenta de Juice Shop es parte de los retos que se deben completar.</li>
    <li>Para acceder a las interfaces web de las aplicaciones debes usar la dirección IP de la máquina donde está instalado docker en lugar de localhost.</li>
  </ul>
</div>

Para poder tener persistencia de las configuraciones del contenedor **DVWA** y **Gophish** el script genera un volumen de docker llamado **docker_dvwa_data** y **docker_gophish** respectivamente, para poder encontrar la ruta de donde se encuentra el volumen y poder editar sus archivos se debe ejecutar los siguientes comandos:

- Validar que el volumen existe en la máquina
```bash
┌──(opsn㉿kali)-[~]
└─$ sudo docker volume ls
DRIVER    VOLUME NAME
local     2462967684fa0fb6554662e28599ada4860a08c54d488f2e30bf82befc2bd9e0
local     docker_dvwa_data
local     docker_gophish
```

- Buscar el "Mountpoint" para saber exactamente en cual carpeta dentro del host se encuentra mapeado el volumen

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

```bash
┌──(opsn㉿kali)-[~]
└─$ sudo docker inspect docker_gophish
[
    {
        "CreatedAt": "2024-03-03T08:33:59-05:00",
        "Driver": "local",
        "Labels": {
            "com.docker.compose.project": "docker",
            "com.docker.compose.version": "2.24.6",
            "com.docker.compose.volume": "gophish"
        },
        "Mountpoint": "/var/lib/docker/volumes/docker_gophish/_data",
        "Name": "docker_gophish",
        "Options": null,
        "Scope": "local"
    }
]
 ```

                                                                                                                                                           
En el ejemplo anterior el volumen de el contenedor DVWA está mapeado a la carpeta `/var/lib/docker/volumes/docker_dvwa_data/_data` y el de Gophish está mapeado a `/var/lib/docker/volumes/docker_gophish/_data`

- Para poder editar los archivos dentro de esa carpeta para cualquier de los contenedores se necesita tener permisos de root, esto se puede hacer usando `sudo su` como se muestra en el ejemplo a continuación.

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

Las contribuciones son lo que hace que la comunidad de código abierto sea un lugar increíble para aprender, inspirar y crear. **Cualquier contribución que hagas es muy apreciada.**

Si tiene una sugerencia para mejorar esto, por favor fork el repositorio y cree un pull request. También puede simplemente abrir un issue con el tag "mejora". No olvides darle una estrella al proyecto. ¡Gracias de nuevo!

## Licencia

Distribuido bajo la Licencia MIT. Vea LICENSE para más información.

Contacto

Open Security Network - info@opensec.network

URL del Proyecto: https://github.com/opensec-network/opensec-lab
