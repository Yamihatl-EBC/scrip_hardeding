#!/bin/bash

# Rutas constantes
BACKUP_PATH="/u03/Banner9/BACKUP"
TEMP_PATH="/u03/Banner9/TEMP"

# Solicitar rutas y nombre del WAR
echo "Ingrese el path de Tomcat (por ejemplo: /u01/app/tomcat/DEVL_8080):"
read TOMCAT_PATH
echo "Ingrese el nombre del archivo WAR (por ejemplo: BannerAdmin.ws.war):"
read WAR_NAME

# Validar que las rutas existen
if [ ! -d "$TOMCAT_PATH" ]; then
    echo "Error: El directorio de Tomcat no existe. Verifique la ruta e intente nuevamente."
    exit 1
fi

# Crear un respaldo del WAR actual con fecha
DATE=$(date +%d%m%Y)
BACKUP_FILE="$BACKUP_PATH/${WAR_NAME}_$DATE"
echo "Creando respaldo en: $BACKUP_FILE"
mkdir -p "$BACKUP_PATH"
cp "$TOMCAT_PATH/webapps/$WAR_NAME" "$BACKUP_FILE"

# Preparar el directorio temporal con fecha
TEMP_DIR="$TEMP_PATH/$DATE"
echo "Creando directorio temporal: $TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copiar el WAR al directorio temporal
TEMP_WAR="$TEMP_DIR/$WAR_NAME"
echo "Copiando $WAR_NAME al directorio temporal: $TEMP_WAR"
cp "$TOMCAT_PATH/webapps/$WAR_NAME" "$TEMP_WAR"

# Descomprimir el WAR
cd "$TEMP_DIR"
echo "Descomprimiendo $WAR_NAME en $TEMP_DIR"
jar -xvf "$WAR_NAME"

# Eliminar el WAR previo en el directorio temporal
if [ -f "$TEMP_WAR" ]; then
    echo "Eliminando WAR previo en el directorio temporal"
    rm -f "$TEMP_WAR"
fi

# Indicar al usuario que copie los nuevos JARs al directorio lib
echo "Copie los archivos JAR al directorio $TEMP_DIR/WEB-INF/lib y presione Enter para continuar."
read

# Generar el nuevo WAR
echo "Generando el nuevo archivo WAR"
jar -cvf "$WAR_NAME" *

# Extraer el nombre del servicio desde el path de Tomcat
SERVICE_NAME=$(basename "$TOMCAT_PATH")
echo "El servicio asociado es: $SERVICE_NAME"

# Apagar Tomcat usando systemctl
echo "Apagando el servicio Tomcat: $SERVICE_NAME"
sudo systemctl stop "$SERVICE_NAME.service"

# Limpiar cache y temporales
cd "$TOMCAT_PATH/temp"
echo "Eliminando contenido del directorio temp"
rm -rf *

cd "$TOMCAT_PATH/work"
echo "Eliminando contenido del directorio work"
rm -rf Catalina

cd "$TOMCAT_PATH/webapps"
echo "Eliminando directorio del WAR desplegado"
rm -rf "${WAR_NAME%.*}/"

# Publicar el nuevo WAR
echo "Publicando el nuevo archivo WAR"
cp "$TEMP_DIR/$WAR_NAME" "$TOMCAT_PATH/webapps/$WAR_NAME"

# Validar procesos huérfanos de Tomcat
echo "Validando procesos huérfanos de Tomcat"
PID=$(ps -ef | grep catalina | grep -v grep | awk '{print $2}')
if [ ! -z "$PID" ]; then
    echo "Tomcat aún está corriendo con PID: $PID. Finalizándolo."
    kill -9 "$PID"
fi

# Iniciar Tomcat usando systemctl
echo "Iniciando el servicio Tomcat: $SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME.service"
echo "Proceso completado exitosamente."

# Eliminar el directorio temporal con fecha
echo "Eliminando el directorio temporal: $TEMP_DIR"
rm -rf "$TEMP_DIR"

echo "Proceso completado exitosamente."
