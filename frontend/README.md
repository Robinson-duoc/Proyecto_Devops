Terraform AWS Infrastructure - Proyecto E-Commerce
Descripción Infraestructura gestionada con Terraform para desplegar una arquitectura de microservicios en AWS:

Red (VPC, subredes, Internet Gateway y Security Groups).

Una instancia EC2 que aloja el motor de base de datos MySQL 8.

Repositorios de contenedores (AWS ECR) para las imágenes de las aplicaciones.

Un clúster Serverless en AWS ECS (Fargate).

Tres microservicios en contenedores: Frontend, Ventas (Backend) y Despacho (Backend).

Temporizador de sincronización (time_sleep) para evitar fallos por conexiones tempranas a la base de datos.

🧭 Estructura del proyecto
Plaintext
proyecto_aws_ecommerce/
├── main.tf                 # Definición de recursos (VPC, EC2, ECS, ECR, Temporizador)
├── variables.tf            # Variables globales (nombres, puertos, credenciales DB)
├── outputs.tf              # Salidas de información (IP de EC2, URLs)
├── backend-ventas/         # Código fuente de Spring Boot
│   └── Dockerfile
├── backend-despacho/       # Código fuente de Spring Boot
│   └── Dockerfile
├── frontend/               # Código fuente del Frontend
│   └── Dockerfile
└── README.md
🚀 Requisitos
Terraform CLI versión >= 1.0

AWS CLI instalado y configurado con tus credenciales (aws configure)

Docker Desktop o Docker Engine instalado localmente (para construir las imágenes)

Versión del provider AWS: hashicorp/aws >= 4.0

Versión del provider Time: hashicorp/time

⚙️ Flujo de uso
Clona el repositorio y ubícate en la carpeta del proyecto.

Inicializa Terraform (descargará los providers de AWS y Time):

Bash
terraform init -upgrade
Verifica el plan de infraestructura:

Bash
terraform plan
Aplica los cambios para crear la infraestructura base (repositorios vacíos, EC2 y redes):

Bash
terraform apply -auto-approve
Subir imágenes (Paso Manual Crucial): Una vez que Terraform termine, debes autenticar tu Docker y subir las imágenes a los repositorios ECR recién creados:

Bash
# 1. Autenticar Docker con AWS
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <TU_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 2. Construir y subir Ventas
cd backend-ventas
docker build -t proyecto-devops-ventas .
docker tag proyecto-devops-ventas:latest <TU_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/proyecto-devops-ventas:latest
docker push <TU_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/proyecto-devops-ventas:latest

# (Repetir el paso 2 para 'backend-despacho' y 'frontend')
📦 ¿Qué despliega este proyecto?
Capa de Datos (EC2): Despliega una máquina EC2 que instala Docker y MySQL mediante user_data. Se incluye un recurso time_sleep de 3 minutos que congela a Terraform, dándole ventaja a la máquina para que encienda el motor de base de datos antes de continuar.

Capa de Aplicación (ECS/ECR): Despliega repositorios para alojar imágenes. Una vez que las imágenes están en ECR, levanta tareas en AWS Fargate que inician el Frontend y los Backends. Los backends (Spring Boot) se conectan a la IP privada de la EC2, creando automáticamente las tablas necesarias gracias a la configuración de Hibernate.

🧭 Diagrama de arquitectura
(Añade aquí una imagen de tu diagrama de red si tienes uno)

📌 Mejores prácticas incluidas
Control de Condiciones de Carrera (Race Conditions): Uso de depends_on y temporizadores para asegurar que la base de datos exista antes de arrancar los microservicios, evitando crasheos (Exit Code 1).

Creación automática de Schemas: Las aplicaciones Java están configuradas con createDatabaseIfNotExist=true y ddl-auto=update para manejar la DB sin scripts manuales.

Serverless Compute: Uso de Fargate para la capa de aplicación, reduciendo la administración de servidores subyacentes.

Seguridad (Security Groups): Reglas estrictas para aislar el tráfico entre la capa de contenedores y la base de datos.

🔧 Cómo extender este proyecto
Automatización CI/CD: Integrar GitHub Actions, GitLab CI o AWS CodePipeline para que los comandos docker build y docker push se ejecuten solos al hacer push al código.

Balanceador de Carga: Agregar un Application Load Balancer (ALB) frente al clúster de ECS para exponer un único punto de entrada público seguro en el puerto 80/443.

Migrar Base de Datos: Cambiar la instancia EC2 gestionada manualmente por un servicio administrado como AWS RDS (Relational Database Service) para obtener respaldos automáticos y alta disponibilidad.