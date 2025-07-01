# Ejecuta Litd

![Alt text](litd.png "Ejecuta Litd")

La siguiente guía y los scripts de automatización fueron creados para el curso **Autocustodia LN: Tu Nodo Lightning, Tus Reglas**.
Los mismos sirven de ayuda para correr un nodo Bitcoin Core y la suite de herramientas Lightning Terminal, que incluye un nodo LND, junto a las utilidades Loop, Pool y Faraday.

Esta versión en español es un fork revisado y actualizado del trabajo de [HannahMR](https://github.com/HannahMR/run-litd). Gracias por inspirarnos y ser tan clara!
Se basa a su vez en el repositorio de [Alex Bosworth](https://github.com/alexbosworth/run-lnd/). Allí puede encontrar información más detallada sobre la configuración de un nodo Lightning.

¡Importante!: Estos ejemplos y scripts están diseñados para ayudar a los desarrolladores a configurar todo rápidamente para comenzar las pruebas y el desarrollo de aplicaciones. Por favor, no confíe en estos archivos para su entorno de producción.

Puede ver un video en inglés de demostración de estos scripts [aquí](https://www.youtube.com/watch?v=lopHP_nF0tE)

## Contenido

1. [Instrucciones](#instrucciones)
2. [Requisitos del Servidor](#requisitos-del-servidor)
3. [Preparando el Servidor](#preparando-el-servidor)
4. [Configurnado Bitcoind](#configurando-bitcoind)
5. [Configurando Litd](#configurando-litd)

## Instrucciones

Esta guía contiene listas de verificación para hacer una instalación manual paso a paso, archivos de configuración de ejemplo y scripts de automatización para poner en funcionamiento un nodo Bitcoin Core y uno de Litd en un servidor Ubuntu. Estos scripts se han probado en Ubuntu 24.04. Hay tres secciones principales en la guía: preparación del servidor, configuración de bitcoind y configuración de litd. En cada una de estas secciones encontrará una descripción de lo que debe suceder, una lista de verificación a seguir, enlaces a archivos de ejemplo y, si lo prefiere, scripts bash que ejecutarán automáticamente todos los pasos por usted.

Las versiones actuales de las listas de verificación y scripts instalan...

- bitcoind v29.0
- litd v0.14.0-alpha

## Requisitos del Servidor

Esta configuración está bien testeada en servidores barebone o virtulaes, con al menos este nivel de recursos:

- 2+ Núcleos de CPU
- 80GB+ de Almacenamiento (nodo podado a 50GB)
- 2GB+ de RAM

Deberá aumentar estos recursos cuando ejecute un servidor de producción o cuando ejecute un nodo completo.

## Clonar el Repositorio

Para tener acceso a los scripts de bash y demás archivos, puede clonar este repositorio dentro del nuevo servidor.

```git clone https://github.com/LibreriadeSatoshi/ejecuta-litd/ejecuta-litd.git```

## Preparando el Servidor

Este paso configura el servidor Ubuntu existente. Se crea un nuevo usuario de Ubuntu con acceso sudo. Se generan y agregan claves SSH. La seguridad se refuerza deshabilitando el inicio de sesión de root y la autenticación por contraseña.

Este paso se puede realizar de forma manual siguiendo la lista de verificación que se encuentra en [/checklists/server-setup-checklist.txt](/checklists/server-setup-checklist.txt) o ejecutando el script bash de configuración automática en [/scripts/server_setup.sh](/scripts/server_setup.sh)

### Script de Ayuda para la Preparación del Servidor

Tenga en cuenta que se le pedirá que pegue las claves SSH de su equipo, en el medio de la ejecución del script.

Ingresar a la carpeta **~/ejecuta-litd/scripts** del repositorio que se clonó.
```cd ~/ejecuta-litd/scripts```

No olvide hacer el script ejecutable antes de intentar ejecutarlo.

```chmod +x server_setup.sh```

El script debe ejecutarse con **sudo**. 

```sudo ./server_setup.sh```

Cuando el script pida la clave SSH, debe generarla **dentro de la terminal de su computadora -no en el nuevo servidor-**, con estos comandos:

```ssh-keygen -t ed25519 -C "tu_email@ejemplo.com"```

Le pedirá una ubicación para guardar las claves, solo presione Enter para que las guarde con el nombre y en el directorio por defecto: **/home/tu_usuario/.ssh/id_ed25519**.
Luego le pedirá de forma opcional una passphrase, que en entornos de test puede obviarse. Una vez completado mostrará algo similar a esto:

```
Your identification has been saved in /home/tu_usuario/.ssh/id_ed25519
Your public key has been saved in /home/tu_usuario/.ssh/id_ed25519.pub
The key's randomart image is:
+--[ED25519 256]--+
|      .+         |
|     B.          |
|    o. + .       |
|   .+ * * B      |
|  . + o S +      |
|   . o + =       |
|    E = B .      |
|     . = +       |
|      ...o.      |
+----[SHA256]-----+
```

Luego debe copiar la clave ssh y pegarla en la terminal donde está ejecutando el script server_setup.sh. Para eso, ir a la carpeta **/home/tu_usuario/.ssh** y ejecutar:

```cat id_ed25519.pub```

**Toda la línea completa que se muestra** es lo que se debe copiar y pegar en la terminal del servidor. Ej: 

```ssh-ed25519 AAA1lZDI1NTEAAAIHOO7upjhjrW0a3obS47upjhjrW0a/LB usuario@mail.com```

Cuando el script finaliza su ejecución, **deberá iniciar una nueva sesión** en el servidor, ingresando como el nuevo usuario "ubuntu" a través de SSH (o por consola si estuviera acceso al equipo). 

Si originalmente clonó el repositorio con un usuario root o con otro nombre, es recomendable mover el repositorio **ejecuta-litd** al directorio de inicio del nuevo usuario "ubuntu" y luego transferir la propiedad.

```sudo mv /home/NOMBRE_DE_USUARIO_ORIGINAL/ejecuta-litd/ /home/ubuntu/ejecuta-litd/```

```sudo chown -R ubuntu:ubuntu /home/ubuntu/ejecuta-litd/```

## Configurando Bitcoind

En este paso el servidor se actualiza, se instalan las dependencias de bitcoind, se compila o se descarga el binario de bitcoind y se verifican las firmas, se crea un archivo de configuración, se crea un archivo **bitcoind.service** de systemd para arranque automático y se ejecuta **bitcoind**. Aquí hay dos scripts y listas de verificación. Uno para compilar desde la fuente y otro para descargar un binario.

A medida que se ejecutan los scripts, se le pedirá que seleccione la red: **mainnet, testnet o signet**.

Este paso se puede realizar siguiendo la lista de verificación que se encuentra aquí [bitcoind-setup-checklist.txt](/checklists/bitcoind-setup-checklist.txt) y aquí [bitcoind-setup-binary-checklist.txt](/checklists/bitcoind-setup-binary-checklist.txt) o ejecutando uno de los scripts bash de configuración aquí [bitcoind_setup.sh](/scripts/bitcoind_setup.sh) o aquí [bitcoind_setup_binary.sh](/scripts/bitcoind_setup_binary.sh)

### Script de Ayuda para la Configuración de Bitcoind

Por favor, revise los valores predeterminados incluidos en el archivo de configuración de los scripts antes de ejecutar uno de los scripts. Los valores como la red, las contraseñas, etc. se seleccionarán/generarán cuando se ejecuten los scripts.

Aquí hay dos scripts para elegir, uno que instala desde el código fuente, **bitcoind_setup.sh**, y otro que instala un binario, **bitcoind_setup_binary.sh**. Cualquiera que sea el script que elija, querrá ejecutarlo con el nuevo usuario "ubuntu" que se creó en el proceso de configuración del servidor.

Estos scripts ejecutan de forma predeterminada un nodo podado, configurado en 50 GB. Si desea ejecutar un nodo completo o almacenar los datos de la cadena de bloques en un disco adjunto, deberá editar el script en consecuencia o de forma posterior el archivo **bitcoin.conf**.

Al ejecutar un nodo completo en mainnet, el servidor debe tener al menos 800 GB. Es común utilizar un disco extra para toda la Blockchain. Cuando haga eso, deberá montar el disco extra y luego agregar la siguiente línea a su archivo **bitcoin.conf**.

```datadir=/ruta/al/directorio/de/almacenamiento```

Al ejecutar un nodo podado, la siguiente línea debe estar descomentada en el archivo **bitcoin.conf**. Es la opción por defecto del script.

```prune=50000 # Podar a 50GB```

Ambos scripts también ejecutan comprobaciones para ver lo que se ha hecho a medida que avanzan, por lo que deberían ser seguros para ejecutar varias veces en caso de que alguna ejecución se haya interrumpido.

No olvide hacer que los scripts sean ejecutables antes de intentar ejecutarlos.

```chmod +x bitcoind_setup.sh```

```chmod +x bitcoind_setup_binary.sh```

Recuerde correr el script con el nuevo usuario. El script **debe ejecutarse como sudo**. No se preocupe, los repositorios, archivos, etc. serán propiedad de su usuario actual, (el nuevo usuario llamado "ubuntu", si se utilizó el script **server_setup.sh**).

Para compilar desde código fuente:

```sudo ./bitcoind_setup.sh```

Para descagar el binario:

```sudo ./bitcoind_setup_binary.sh``` 

Responda a las consultas de configuración por pantalla y revise las últimas líneas al finalizar el script.

## Configurando Litd

Este paso instala y ejecuta litd. Al instalar desde la fuente, se instalan GoLang y NodeJS, se clona el repositorio y se compila litd. Al instalar desde el binario, se descargan los archivos necesarios, se verifican las firmas, se genera un archivo **lit.conf**, se crea una billetera LND y se guarda la contraseña, luego se configura para desbloquearse automáticamente al inicio, creando un archivo **litd.service** de systemd y se inicia **litd**.

La instalación de Litd se ve facilitada con este repositorio de varias maneras. Puede continuar con cualquiera de las opciones de configuración, la lista de verificación de instalación desde la fuente está aquí [litd-setup-checklist.txt](/checklists/litd-setup-checklist.txt) y la lista de verificación de instalación desde el binario está aquí [litd-setup-binary-checklist.txt](/checklists/litd-setup-binary-checklist.txt)

También se pueden utilizar los scripts bash para instalar desde la fuente o desde el binario. Para instalar desde la fuente, ejecute los scripts bash de configuración en [litd_setup.sh](/scripts/litd_setup.sh), [litd_setup2.sh](/scripts/litd_setup2.sh) y [litd_setup3.sh](/scripts/litd_setup3.sh)

Para instalar un binario, ejecute los scripts bash de configuración en [litd_setup_binary.sh](/scripts/litd_setup_binary.sh) y [litd_setup3.sh](/scripts/litd_setup3.sh)

### Script de Ayuda para la Configuración de Litd

Estos scripts ejecutan comprobaciones para ver lo que se ha hecho a medida que avanzan, por lo que deberían ser seguros para ejecutar varias veces en caso de que alguna ejecución se haya interrumpido.

Si está instalando desde la fuente, hay tres scripts que debe ejecutar aquí: **litd_setup.sh, luego litd_setup2.sh** y por último **litd_setup3.sh**.


**Deberá seguir el proceso de creación de la billetera después de ejecutar el segundo script y antes del tercer script.**

Si está instalando el binario, son solo dos los scripts para ejecutar: **litd_setup_binary.sh** y **litd_setup3.sh**.

Después de ejecutar el script **litd_setup_binary.sh**, deberá completar el proceso de creación de la billetera antes de ejecutar **litd_setup3.sh**.

No olvide hacerlos ejecutables antes de intentar ejecutarlos.

```chmod +x litd_setup*```

Recuerde correr los scripts con el nuevo usuario. Los scripts **deben ejecutarse como sudo**. No se preocupe, los repositorios, archivos, etc. serán propiedad de su usuario actual (un usuario llamado "ubuntu" si se utilizó el script **server_setup.sh**).

Para compilar desde código fuente:

```sudo ./litd_setup.sh```

**Luego de ejecutar el primer script, al finalizar debe cerrar la sesión actual e iniciar una nueva antes de ejecutar el segundo script**. 

```sudo ./litd_setup2.sh```

```sudo ./litd_setup3.sh```

Para descagar el binario:

```sudo ./litd_setup_binary.sh``` 

```sudo ./litd_setup3.sh```

Ahora a desarrollar! 
