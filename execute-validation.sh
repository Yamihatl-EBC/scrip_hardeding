#!/bin/bash

# Obtiene la lista de contenedores con su estado
all_containers=$(docker ps -a --format "{{.ID}} {{.Status}} {{.Names}}")

# Variable de estado
error_found=0

echo "🔍 Verificando contenedores..."

while IFS= read -r line; do
    container_id=$(echo "$line" | awk '{print $1}')
    container_status=$(echo "$line" | awk '{print $2}')
    container_name=$(echo "$line" | awk '{print $3}')

    if [[ "$container_status" != "Up" ]]; then
        echo "❌ Contenedor detenido: $container_name ($container_id) - Estado: $container_status"
        error_found=1
    else
        echo "✅ Contenedor activo: $container_name ($container_id)"
    fi
done <<< "$all_containers"

# Si hay algún contenedor detenido, salida con error
if [[ $error_found -eq 1 ]]; then
    echo "🚨 Se encontraron contenedores detenidos."
    exit 1
else
    echo "🎉 Todos los contenedores están en ejecución."
    exit 0
fi
 
