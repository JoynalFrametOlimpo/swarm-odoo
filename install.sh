# Ticgobi Config and Install Odoo Server
# Author: JoynalFrametOlimpo
dt=$(date '+%d-%m-%Y--%H-%M-%S')

echo "$(tput setaf 4)********************** ENVIRONMENT *************************************$(tput setaf 3)"
echo "Production (1)..."
echo "Development (2)..."
read environment

# For backup environment directory
if [ ! -d ./backup-environment ]; then
    mkdir ./backup-environment
fi

if [ $environment -eq 1 ]; then
   ODOO_PATH="./odoo-production"
   ln -s compose/compose-production.yml docker-compose.yml
   cp env/.envPro .env
   if [ -d ./odoo-production ]; then
       mv ./odoo-production "./backup-environment/odoo-production.$dt"
   fi
fi

if [ $environment -eq 2 ]; then
   ODOO_PATH="./odoo-develop"
   ln -s compose/compose-develop.yml docker-compose.yml
   cp env/.envDev .env
   if [ -d ./odoo-develop ]; then
       mv ./odoo-develop "./backup-environment/odoo-develop.$dt"
   fi
fi

rm -rf "$ODOO_PATH"

# OS version
. /etc/os-release
SO=$ID

# Date Config
if [ -f /etc/localtime/ ]; then
  cp /usr/share/zoneinfo/America/Guayaquil /etc/localtime 
fi

# Install docker and docker-compose Centos
if [ "$SO" = "centos" ]; then
     echo "$(tput setaf 4)***************** UPGRADE SO ************************************************$(tput setaf 3)"
     yum -y upgrade
     echo "(tput setaf 4)***************** UPDATE SO ************************************************$(tput setaf 3)"
     yum -y update
     echo "(tput setaf 4)***************** INSTALLING DEPENDS ***************************************$(tput setaf 3)"
     yum install -y yum-utils device-mapper-persistent-data lvm2 --no-install-recommends
     yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
     echo "(tput setaf 4)***************** INSTALL DOCKER ******************************************$(tput setaf 3)"
     yum install -y docker-ce
     usermod -aG docker $(whoami)
     gpasswd -a ${USER} docker
     systemctl enable docker.service
     systemctl start docker.service
     yum install -y epel-release
     echo "(tput setaf 4)*************** INSTALL Python-pip ****************************************$(tput setaf 3)"
     yum install -y python-pip --no-install-recommends
     echo "(tput setaf 4)************** INSTALL DOCKER-COMPOSE *************************************$(tput setaf 3)"
     pip install docker-compose --no-install-recommends
     echo "(tput setaf 4)************* Upgrade Python *********************************************$(tput setaf 3)"
     yum -y upgrade python --no-install-recommends
     docker version
     docker-compose version
fi

if [ "$SO" = "ubuntu" ]; then
     echo "$(tput setaf 4)***************** UPGRADE SO ************************************************$(tput setaf 3)"
     apt-get upgrade -y
     echo "$(tput setaf 4)***************** UPDATE SO ************************************************$(tput setaf 3)"
     apt-get update -y
     echo "$(tput setaf 4)***************** INSTALL DOCKER ******************************************$(tput setaf 3)"
     apt-get -y install docker.io --no-install-recommends
     echo "$(tput setaf 4)***************** INSTALL DOCKER-COMPOSE******************************************$(tput setaf 3)"
     apt-get -y install docker-compose --no-install-recommends
     echo "$(tput setaf 4)***************** INFORMATION DOCKER******************************************$(tput setaf 3)"
     groupadd docker
     usermod -aG docker $USER
     docker version
     docker-compose version
fi


if [ ! -d "$ODOO_PATH/13" ]; then
    mkdir -p "$ODOO_PATH/13"
fi

echo "$(tput setaf 4)******************************* Building image Odoo 13 *********************************$(tput setaf 3)"
docker build -f ./Dockerfile -t odoo:13.0 . --force-rm


# Copy odoo configuration file in new project
if [ ! -f "$ODOO_PATH/13/conf/odoo.conf" ]; then
    echo "$(tput setaf 4)***************** Copiando archivo odoo.conf en ruta de proyecto*********************$(tput setaf 3)"
    mkdir "$ODOO_PATH/13/conf/" &&  cp ./odoo.conf "$ODOO_PATH/13/conf/"
fi

# Copy nginx configuration file in new project
if [ ! -f "$ODOO_PATH/13/nginx/nginx.conf" ]; then
   echo "$(tput setaf 4)***************** Copiando archivo nginx.conf en ruta de proyecto*********************$(tput setaf 3)"
   mkdir "$ODOO_PATH/13/nginx/" && cp ./nginx/nginx.conf "$ODOO_PATH/13/nginx/"
fi

if [ $environment -eq 1 ]; then
echo "$(tput setaf 4)###########################################################################################$(tput setaf 3)"
echo "EL sitio que va a contruir cuenta con un dominio? Seleccione la opción correcta y dar enter"
echo "1 .- Con dominio"
echo "0 .- Sin dominio"
echo "$(tput setaf 4)###########################################################################################$(tput setaf 3)"

read isDomain

if [ $isDomain -eq 1 ]; then
   echo  "$(tput setaf 4)Ingrese el nombre del Dominio:  (Ejemplo: prueba.dominio.com) $(tput setaf 3)"
   read DOMINIO
   SUBDOMINIOS=*.$DOMINIO
   MAIL=admin@$DOMINIO

# Install Certbot
    if [ "$SO" = "centos" ]; then
       echo "$(tput setaf 4)################## Installing Certbot ############ $(tput setaf 3)"
       pip install requests==2.6.0
       easy_install --upgrade pip
       yum -y install certbot -y --no-install-recommends

    fi
    if [ "$SO" = "ubuntu" ]; then
       apt-get install certbot -y --no-install-recommends
    fi

  # Install certificates

  if [ ! -d /etc/letsencrypt/live/$DOMINIO ]; then
     certbot certonly --manual \
      -d $SUBDOMINIOS \
      -d $DOMINIO \
      --preferred-challenges dns-01 \
      --server https://acme-v02.api.letsencrypt.org/directory \
      -m $MAIL
   fi

   # Copy certificates
   if [ ! -d "$ODOO_PATH/13/certbot/conf/live" ]; then
     cp -R /etc/letsencrypt/live/ "$ODOO_PATH/13/certbot/conf/"
   
     rm -f "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/cert.pem"
     cp /etc/letsencrypt/live/$DOMINIO/cert.pem "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/"

     rm -f "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/chain.pem"
     cp /etc/letsencrypt/live/$DOMINIO/chain.pem "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/"

     rm -f "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/fullchain.pem"
     cp /etc/letsencrypt/live/$DOMINIO/fullchain.pem "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/"

     rm -f "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/privkey.pem"
     cp /etc/letsencrypt/live/$DOMINIO/privkey.pem "$ODOO_PATH/13/certbot/conf/live/$DOMINIO/"

     cp ./nginx/options-ssl-nginx.conf "$ODOO_PATH/13/certbot/conf/"
     openssl dhparam -dsaparam -out "$ODOO_PATH/13/certbot/conf/ssl-dhparams.pem" 4096
     echo "$(tput setaf 4)Proceder a cambiar contraseñas en .ENV... y configuracion en".$ODOO_PATH."13/nginx/nginx.conf $(tput setaf 3)"
  fi
fi
fi


chmod +x ./entrypoint.sh ./wait-for-psql.py
chmod -R 777 "$ODOO_PATH/13/"
echo "$(tput setaf 1)****************** Levantando Servicios *******************************$(tput setaf 3)"
docker rm -f $(docker ps -a -q)
docker-compose up -d

chmod -R 777 "$ODOO_PATH/13/"
