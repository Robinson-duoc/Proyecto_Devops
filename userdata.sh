#!/bin/bash
# Actualizar el sistema
sudo apt-get update -y

# Instalar Docker
sudo apt-get install -y docker.io

# Iniciar y habilitar el servicio de Docker
sudo systemctl start docker
sudo systemctl enable docker

# Descargar y ejecutar el contenedor de MySQL 8.0
# Configura la base de datos "innovatech" y la contraseña "root" que usan tus backends
sudo docker run -d \
  --name mysql-server \
  -p 3306:3306 \
  -e MYSQL_DATABASE=innovatech \
  -e MYSQL_ROOT_PASSWORD=root \
  --restart always \
  mysql:8.0