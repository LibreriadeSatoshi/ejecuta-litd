






#!/bin/bash

# Script de Instalación de litd para Ubuntu
# Este script automatiza la instalación del binario de Lightning Terminal (litd) y su configuración

set -e # Salir inmediatamente si un comando termina con un estado distinto de cero

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LIT_CONF_DIR="$USER_HOME/.lit"
LIT_CONF_FILE="$LIT_CONF_DIR/lit.conf"
LND_DIR="$USER_HOME/.lnd"
WALLET_PASSWORD_FILE="$LND_DIR/wallet_password"
SERVICE_FILE="/etc/systemd/system/litd.service"

LITD_VERSION="v0.14.0-alpha" # Versión de litd a instalar
BINARY_URL="https://github.com/lightninglabs/lightning-terminal/releases/download/$LITD_VERSION/lightning-terminal-linux-amd64-$LITD_VERSION.tar.gz"
SIGNATURE_URL="https://github.com/lightninglabs/lightning-terminal/releases/download/$LITD_VERSION/manifest-guggero-$LITD_VERSION.sig"
MANIFEST_URL="https://github.com/lightninglabs/lightning-terminal/releases/download/$LITD_VERSION/manifest-$LITD_VERSION.txt"
KEY_ID="F4FC70F07310028424EFC20A8E4256593F177720"
KEY_SERVER="hkps://keyserver.ubuntu.com"
DOWNLOAD_DIR="/tmp/litd_release_verification"


# --- Instalación de litd ---
echo "[+] Verificando si Lightning Terminal ya está instalado..."
if [[ -f "/usr/local/bin/litd" ]]; then
  echo "[+] Lightning Terminal (litd) ya está instalado. Omitiendo la instalación."
else
  echo "[+] litd no se encontró. Procediendo con la instalación."

  # Crear directorio de descarga y navegar a él
  mkdir -p "$DOWNLOAD_DIR"
  cd "$DOWNLOAD_DIR" || { echo "No se pudo navegar al directorio de descarga."; exit 1; }

  # Importar la clave PGP de Oliver Gugger
  echo "[+] Importando la clave PGP del desarrollador..."
  gpg --keyserver "$KEY_SERVER" --recv-keys "$KEY_ID" || { echo "No se pudo importar la clave PGP."; exit 1; }

  # Descargar binario, manifiesto y firma
  echo "[+] Descargando binario, manifiesto y firma..."
  wget -q --show-progress "$BINARY_URL"
  wget -q --show-progress "$SIGNATURE_URL"
  wget -q --show-progress "$MANIFEST_URL"

  # Verificar la firma del manifiesto (manera robusta)
  echo "[+] Verificando la firma del manifiesto..."
  if gpg --verify "$(basename "$SIGNATURE_URL")" "$(basename "$MANIFEST_URL")"; then
    echo "[+] Verificación de firma exitosa."
  else
    echo "[-] ¡La verificación de la firma falló! No continuar."
    exit 1
  fi

  # Verificar el hash del binario contra el manifiesto
  echo "[+] Verificando el hash SHA256 del binario..."
  if sha256sum --check --ignore-missing "$(basename "$MANIFEST_URL")"; then
      echo "[+] Verificación de hash SHA256 exitosa."
  else
      echo "[-] ¡La verificación de hash SHA256 fallida!"
      exit 1
  fi

  # Extraer y mover binarios
  echo "[+] Extrayendo los binarios..."
  tar -xvzf "$(basename "$BINARY_URL")" --strip-components=1 lightning-terminal-linux-amd64-$LITD_VERSION/litd lightning-terminal-linux-amd64-$LITD_VERSION/lncli

  echo "[+] Moviendo los binarios a /usr/local/bin..."
  sudo mv litd lncli /usr/local/bin/

  # Limpiar
  echo "[+] Limpiando archivos temporales..."
  cd "$USER_HOME" # Volver al directorio de inicio antes de eliminar
  rm -rf "$DOWNLOAD_DIR"

  echo "[+] ¡litd instalado con éxito!"
fi

# --- Configuración de Directorios y Permisos ---
echo "[+] Asegurando que el directorio ~/.lnd existe y tiene los permisos correctos..."
mkdir -p "$LND_DIR"
sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$LND_DIR"

# --- Generación de Contraseña de Billetera ---
if [[ -s "$WALLET_PASSWORD_FILE" ]]; then
  echo "[+] El archivo de contraseña de la billetera ya existe y no está vacío. Omitiendo la generación."
else
  echo "[+] Generando contraseña de la billetera..."
  openssl rand -hex 21 > "$WALLET_PASSWORD_FILE"
  sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$WALLET_PASSWORD_FILE"
  echo "[+] Contraseña de la billetera generada y guardada en $WALLET_PASSWORD_FILE."
fi

# --- Creación del Archivo de Configuración de litd ---
echo "[+] Verificando el archivo de configuración de litd..."
mkdir -p "$LIT_CONF_DIR" # Asegurar que el directorio existe primero
sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$LIT_CONF_DIR"

if [[ -s "$LIT_CONF_FILE" ]]; then
  echo "[+] El archivo de configuración $LIT_CONF_FILE ya existe y no está vacío. Omitiendo la creación."
else
  # -- INICIO DEL BLOQUE 'else' -- TODO ESTO SÓLO SE EJECUTA SI EL ARCHIVO NO EXISTE
  echo "[+] Generando nuevo archivo de configuración..."

  while true; do
    read -p "¿Su backend de bitcoind se está ejecutando en mainnet, testnet o signet? [mainnet/testnet/signet]: " NETWORK
    NETWORK=$(echo "$NETWORK" | tr '[:upper:]' '[:lower:]')
    if [[ "$NETWORK" == "mainnet" || "$NETWORK" == "testnet" || "$NETWORK" == "signet" ]]; then
      break
    else
      echo "[-] Selección de red inválida. Por favor, elija 'mainnet', 'testnet' o 'signet'."
    fi
  done

  read -s -p "Ingrese la contraseña RPC para su backend de bitcoind: " RPC_PASSWORD
  echo
  if [[ -z "$RPC_PASSWORD" ]]; then
    echo "[-] La contraseña RPC no puede estar vacía. Saliendo."
    exit 1
  fi

  read -s -p "Ingrese una contraseña de UI para litd: " UI_PASSWORD
  echo
  if [[ -z "$UI_PASSWORD" ]]; then
    echo "[-] La contraseña de la UI no puede estar vacía. Saliendo."
    exit 1
  fi

  read -p "Ingrese un alias de nodo Lightning: " NODE_ALIAS

  # Habilitar Pool y Loop para mainnet por defecto
  POOL_MODE="pool-mode=active"
  LOOP_MODE="loop-mode=active"
  AUTOPILOT_DISABLE="autopilot.disable=true"
  if [[ "$NETWORK" != "mainnet" || "NETWORK" != "testnet" ]]; then
    POOL_MODE="pool-mode=disable"
    LOOP_MODE="loop-mode=disable"
    AUTOPILOT_DISABLE="autopilot.disable=true"
  fi

  # Escribir el archivo de configuración usando un "Heredoc"
  cat > "$LIT_CONF_FILE" << EOF
# Configuración de Litd
enablerest=true
httpslisten=0.0.0.0:8443
uipassword=$UI_PASSWORD
network=$NETWORK
lnd-mode=integrated
$POOL_MODE
$LOOP_MODE
$AUTOPILOT_DISABLE

# Configuración de Bitcoin
lnd.bitcoin.active=1
lnd.bitcoin.node=bitcoind
lnd.bitcoind.rpchost=127.0.0.1
lnd.bitcoind.rpcuser=bitcoinrpc
lnd.bitcoind.rpcpass=$RPC_PASSWORD
lnd.bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
lnd.bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

# Configuración General de LND
lnd.debuglevel=debug
lnd.alias=$NODE_ALIAS
lnd.maxpendingchannels=3
lnd.accept-keysend=true
lnd.accept-amp=true
lnd.rpcmiddleware.enable=true
lnd.autopilot.active=0

# Configuración del Protocolo LND
lnd.protocol.simple-taproot-chans=true
lnd.protocol.simple-taproot-overlay-chans=true
lnd.protocol.option-scid-alias=true
lnd.protocol.zero-conf=true
lnd.protocol.custom-message=17
EOF

  sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$LIT_CONF_FILE"
  echo "[+] Archivo de configuración creado en $LIT_CONF_FILE."
fi 

# --- Instrucciones Finales ---
echo
echo "------------------------------------------------------------------"
echo "¡TAREA PENDIENTE!"
echo "------------------------------------------------------------------"
echo "1. Inicie litd por primera vez con el comando: litd"
echo "   (Ejecútelo como el usuario '${SUDO_USER:-$USER}')"
echo
echo "2. En una NUEVA terminal, cree la billetera con el comando:"
echo "   lncli --network=$NETWORK create"
echo
echo "3. Se le pedirá una contraseña de billetera. ¡NO INVENTE UNA!"
echo "   Use la contraseña que ya fue generada con este comando:"
echo "   cat $WALLET_PASSWORD_FILE"
echo
echo "4. ¡¡¡RESPALDE SU FRASE SEMILLA DE 24 PALABRAS INMEDIATAMENTE!!!"
echo
echo "5. Una vez respaldada, puede detener litd (Ctrl+C) y proceder con los siguientes pasos."
echo "------------------------------------------------------------------"
