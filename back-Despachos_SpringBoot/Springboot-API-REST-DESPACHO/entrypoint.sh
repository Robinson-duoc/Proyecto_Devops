#!/bin/sh

echo "===================================================="
echo "Buscando MySQL en $DB_ENDPOINT:3306..."
echo "===================================================="

# Bucle de espera activa usando netcat (nc)
until nc -z -v -w5 $DB_ENDPOINT 3306; do
  echo "MySQL aún no responde. Reintentando en 3 segundos..."
  sleep 3
done

echo "===================================================="
echo "¡Conexión exitosa! MySQL está listo. Iniciando App..."
echo "===================================================="

# Ejecuta la aplicación Java reemplazando el proceso del shell (Práctica DevOps)
exec java -jar app.jar