#!/bin/bash

# Solicitar rutas y nombre del WAR
echo "Ingrese el path de Tomcat (por ejemplo: /u01/app/tomcat/DEVL_8080):"
read TOMCAT_PATH
echo "Ingrese el path para respaldos (por ejemplo: /home/tomcat/RESPALDO):"
read BACKUP_PATH
echo "Ingrese el nombre del archivo WAR (por ejemplo: BannerAdmin.ws.war):"
read WAR_NAME
echo "Ingrese el path temporal para operaciones (por ejemplo: /home/tomcat/TEMP_INSTALL):"
read TEMP_PATH

# Validar que las rutas existen
if [ ! -d "$TOMCAT_PATH" ] || [ ! -d "$BACKUP_PATH" ] || [ ! -d "$TEMP_PATH" ]; then
    echo "Error: Uno o más directorios no existen. Verifique las rutas e intente nuevamente."
    exit 1
fi

# Crear un respaldo del WAR actual
BACKUP_FILE="$BACKUP_PATH/${WAR_NAME}_$(date +%d%m%Y)"
echo "Creando respaldo en: $BACKUP_FILE"
cp "$TOMCAT_PATH/webapps/$WAR_NAME" "$BACKUP_FILE"

# Copiar el WAR al directorio temporal
TEMP_WAR="$TEMP_PATH/$WAR_NAME"
echo "Copiando $WAR_NAME al directorio temporal: $TEMP_WAR"
cp "$TOMCAT_PATH/webapps/$WAR_NAME" "$TEMP_WAR"

# Descomprimir el WAR
cd "$TEMP_PATH"
echo "Descomprimiendo $WAR_NAME en $TEMP_PATH"
jar -xvf "$WAR_NAME"

# Eliminar el WAR previo en el directorio temporal
if [ -f "$TEMP_WAR" ]; then
    echo "Eliminando WAR previo en el directorio temporal"
    rm -f "$TEMP_WAR"
fi

# Indicar al usuario que copie los nuevos JARs al directorio lib
echo "Copie los archivos JAR al directorio $TEMP_PATH/WEB-INF/lib y presione Enter para continuar."
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
cp "$TEMP_PATH/$WAR_NAME" "$TOMCAT_PATH/webapps/$WAR_NAME"

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

# Eliminar el directorio temporal
echo "Eliminando el directorio temporal: $TEMP_PATH"
rm -rf "$TEMP_PATH"

echo "Proceso completado exitosamente."

