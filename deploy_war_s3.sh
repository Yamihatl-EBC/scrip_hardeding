#!/bin/bash

# Solicitar rutas y nombre del WAR
echo "Ingrese el path de Tomcat (por ejemplo: /u01/app/tomcat/DEVL_8080):"
read TOMCAT_PATH
echo "Ingrese el bucket de S3 para respaldos (por ejemplo: s3://mi-bucket/respaldos):"
read S3_BUCKET
echo "Ingrese el nombre del archivo WAR (por ejemplo: BannerAdmin.ws.war):"
read WAR_NAME
echo "Ingrese el path temporal para operaciones (por ejemplo: /home/tomcat/TEMP_INSTALL):"
read TEMP_PATH

# Validar que las rutas existen
if [ ! -d "$TOMCAT_PATH" ] || [ ! -d "$TEMP_PATH" ]; then
    echo "Error: Uno o más directorios no existen. Verifique las rutas e intente nuevamente."
    exit 1
fi

# Crear un respaldo del WAR actual
BACKUP_FILE="${WAR_NAME}_$(date +%d%m%Y)"
echo "Creando respaldo y subiéndolo a S3: $S3_BUCKET/$BACKUP_FILE"
aws s3 cp "$TOMCAT_PATH/webapps/$WAR_NAME" "$S3_BUCKET/$BACKUP_FILE"
if [ $? -ne 0 ]; then
    echo "Error al subir el respaldo a S3. Verifique su configuración de AWS CLI."
    exit 1
fi

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

# Apagar Tomcat
echo "Apagando el servicio Tomcat"
cd "$TOMCAT_PATH/bin"
./shutdown.sh

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

# Iniciar Tomcat
echo "Iniciando el servicio Tomcat"
cd "$TOMCAT_PATH/bin"
./startup.sh

# Eliminar el directorio temporal
echo "Eliminando el directorio temporal: $TEMP_PATH"
rm -rf "$TEMP_PATH"

echo "Proceso completado exitosamente."
