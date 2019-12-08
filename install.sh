# Ticgobi Config and Install Odoo Server
# Author: JoynalFrametOlimpo

echo "$(tput setaf 4)********************** ENVIRONMENT *************************************$(tput setaf 3)"
echo "Production (1)..."
echo "Development (2)..."
read environment

# OS version
. /etc/os-release
SO=$ID

# Date Config
cp /usr/share/zoneinfo/America/Guayaquil /etc/localtime 


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
     apt-get upgrade
     echo "$(tput setaf 4)***************** UPDATE SO ************************************************$(tput setaf 3)"
     apt-get update
     echo "$(tput setaf 4)***************** INSTALL DOCKER ******************************************$(tput setaf 3)"
     apt-get -y install docker.io --no-install-recommends
     echo "$(tput setaf 4)***************** INSTALL DOCKER-COMPOSE******************************************$(tput setaf 3)"
     apt-get -y install docker-compose --no-install-recommends
     echo "$(tput setaf 4)***************** INFORMATION DOCKER******************************************$(tput setaf 3)"
     docker version
     docker-compose version
fi

if [ $environment -eq 1 ]; then
    ln -s compose/compose-production.yml docker-compose.yml
    cp compose/.envPro .env
fi
if [ $environment -eq 2 ]; then
    ln -s compose/compose-develop.yml docker-compose.yml
    cp compose/.envDev .env
fi

echo "$(tput setaf 4)******************************* Building image Odoo 13 *********************************$(tput setaf 3)"
docker build -t odoo:13 .

# Create and stop project
#if [ ! -d /opt/odoo/13 ]; then
#    mkdir -p /opt/odoo/13 
#    echo "$(tput setaf 4)************************** Up Service ****************************************$(tput setaf 3)"
#    docker-compose up -d
#    echo "$(tput setaf 4)************************* Stop Services **************************************$(tput setaf 3)"
#    docker-compose stop
#fi

# Copy odoo configuration file in new project
if [ ! -f /opt/odoo/13/conf/odoo.conf ]; then
    echo "$(tput setaf 4)***************** Copiando archivo odoo.conf en ruta de proyecto*********************$(tput setaf 3)"
    cp ./odoo.conf /opt/odoo/13/conf
fi

# Copy nginx configuration file in new project
if [ ! -f /opt/odoo/13/nginx/nginx.conf ]; then
   echo "$(tput setaf 4)***************** Copiando archivo nginx.conf en ruta de proyecto*********************$(tput setaf 3)"
   cp ./nginx.conf /opt/odoo/13/nginx
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
   if [ ! -d /opt/odoo/13/certbot/conf/live ]; then
     cp -R /etc/letsencrypt/live/ /opt/odoo/13/certbot/conf/
   
     rm -f /opt/odoo/13/certbot/conf/live/$DOMINIO/cert.pem
     cp /etc/letsencrypt/live/$DOMINIO/cert.pem /opt/odoo/13/certbot/conf/live/$DOMINIO/

     rm -f /opt/odoo/13/certbot/conf/live/$DOMINIO/chain.pem
     cp /etc/letsencrypt/live/$DOMINIO/chain.pem /opt/odoo/13/certbot/conf/live/$DOMINIO/

     rm -f /opt/odoo/13/certbot/conf/live/$DOMINIO/fullchain.pem
     cp /etc/letsencrypt/live/$DOMINIO/fullchain.pem /opt/odoo/13/certbot/conf/live/$DOMINIO/

     rm -f /opt/odoo/13/certbot/conf/live/$DOMINIO/privkey.pem
     cp /etc/letsencrypt/live/$DOMINIO/privkey.pem /opt/odoo/13/certbot/conf/live/$DOMINIO/

     cp ./certbot-conf/options-ssl-nginx.conf /opt/odoo/13/certbot/conf/
     openssl dhparam -dsaparam -out /opt/odoo/13/certbot/conf/ssl-dhparams.pem 4096
     echo "$(tput setaf 4)Proceder a cambiar contraseñas en .ENV... y configuracion en /opt/odoo/13/nginx/nginx.conf $(tput setaf 3)"
  fi
fi
fi

#chmod -R 777 /opt/odoo/13

echo "$(tput setaf 1)****************** Levantando Servicios *******************************$(tput setaf 3)"
docker-compose up -d

