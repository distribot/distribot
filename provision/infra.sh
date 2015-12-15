#!/bin/bash

set -e

sudo apt-get -y update
sudo apt-get -y autoremove
sudo apt-get install -y \
  ruby2.0 \
  ruby2.0-dev \
  build-essential \
  git \
  wget \
  psmisc \
  curl \
  vim

setup_redis() {
  if [ -f /etc/init.d/redis-server ]; then
    echo 'redis-server already installed'
  else
    sudo apt-get install -y redis-server
  fi

  if grep -e "bind 0.0.0.0" /etc/redis/redis.conf; then
    echo "redis already willing to accept connections on 0.0.0.0"
  else
    echo 'bind 0.0.0.0' | sudo tee -a /etc/redis/redis.conf
  fi

  sudo service redis-server restart
}

setup_rabbitmq() {
  if [ -d /data/rabbitmq ]; then
    echo "directory /data/rabbitmq already exists"
  else
    sudo mkdir -p /data/rabbitmq
    sudo chmod 0777 -R /data/rabbitmq
    echo 'export RABBITMQ_MNESIA_BASE=/data/rabbitmq' | sudo tee -a /etc/bash.bashrc
    sudo mkdir -p /etc/rabbitmq
    echo 'MNESIA_BASE=/data/rabbitmq' | sudo tee /etc/rabbitmq/rabbitmq-env.conf
  fi

  if grep "www.rabbitmq.com" /etc/apt/sources.list; then
    echo "rabbitmq apt repository already in sources.list"
  else
    echo 'deb http://www.rabbitmq.com/debian/ testing main' | sudo tee -a /etc/apt/sources.list
    wget -O /tmp/rabbitmq-signing-key-public.asc https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
    sudo apt-key add /tmp/rabbitmq-signing-key-public.asc
  fi

  if which rabbitmqctl; then
    echo "rabbitmq already installed"
    sudo service rabbitmq-server start
  else
    sudo apt-get update
    sudo apt-get install -y --force-yes rabbitmq-server
    sudo chown -R rabbitmq:rabbitmq /data/rabbitmq
    sudo service rabbitmq-server restart
    sudo rabbitmq-plugins enable rabbitmq_management
  fi

  if sudo rabbitmqctl list_users | grep $RABBITMQ_USERNAME; then
    echo "user '$RABBITMQ_USERNAME' already exists"
  else
    sudo rabbitmqctl add_user $RABBITMQ_USERNAME $RABBITMQ_PASSWORD
  fi

  if sudo rabbitmqctl list_users | grep $RABBITMQ_USERNAME | grep -F "[administrator]"; then
    echo "user '$RABBITMQ_USERNAME' already tagged as 'administrator'"
  else
    sudo rabbitmqctl set_user_tags $RABBITMQ_USERNAME administrator
  fi

  sudo rabbitmqctl set_permissions -p / $RABBITMQ_USERNAME ".*" ".*" ".*"

  # Reset permissions back to rabbitmq:
  if stat -c %U /data/rabbitmq | grep rabbitmq; then
    echo "/data/rabbitmq/ is already owned by rabbitmq"
  else
    sudo chmod 0755 -R /data/rabbitmq
    sudo chown -R rabbitmq:rabbitmq /data/rabbitmq
  fi
  sudo wget -O /usr/bin/rabbitmqadmin http://localhost:15672/cli/rabbitmqadmin
  sudo chmod +x /usr/bin/rabbitmqadmin
}

setup_elasticsearch() {

  sudo apt-get install -y \
    openjdk-7-jre-headless \
    nginx

  if [ ! -d /etc/nginx/certs/distribot ]; then
    sudo mkdir -p /etc/nginx/certs/distribot
    sudo openssl genrsa -out /etc/nginx/certs/distribot/server.key 2048
    sudo openssl req -new -key /etc/nginx/certs/distribot/server.key -subj "/C=US/ST=California/L=San Francisco/O=Distribot/OU=Engineering/CN=distribot" -out /etc/nginx/certs/distribot/server.csr
    sudo openssl x509 -req -days 365 -in /etc/nginx/certs/distribot/server.csr -signkey /etc/nginx/certs/distribot/server.key -out /etc/nginx/certs/distribot/server.crt
  fi

  (echo '<% installation_path="/var/www/distribot" %>' && cat provision/templates/elasticsearch.nginx.conf.erb) | erb | sudo tee /etc/nginx/sites-available/default > /dev/null
  sudo service nginx restart

  # Install elasticsearch:
  if [ ! -f /etc/init.d/elasticsearch ]; then
    # Download the version we want:
    wget -O /tmp/elasticsearch.deb https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.4.deb

    # Install the elasticsearch package:
    # This also creates the 'elasticsearch' user+group:
    sudo dpkg --install /tmp/elasticsearch.deb

    # Setup the data directory:
    sudo mkdir -p /data/elasticsearch
    sudo chown -R elasticsearch:elasticsearch /data/elasticsearch

    # Make sure elasticsearch starts on boot:
    sudo update-rc.d elasticsearch defaults 95 10

    # Make elasticsearch use /data/elasticsearch to store its data:
    echo 'path.data: /data/elasticsearch' | sudo tee -a /etc/elasticsearch/elasticsearch.yml
  fi

  # Tweak /etc/init.d/elasticsearch to not mess with kernel settings:
  if sudo touch /proc/sys/vm/max_map_count; then
    echo "Not running under Docker."
  else
    # ElasticSearch does some kernel config tweaking which breaks under Docker.
    sudo perl -p -i -e 's{sysctl}{echo "SKIPPING sysctl because /proc/sys/vm/max_map_count is readonly."\n\t\t\#sysctl}sg' /etc/init.d/elasticsearch
  fi

  # Start elasticsearch:
  sudo service elasticsearch restart
  while ! nc -z localhost 9200; do
    echo "Waiting for ElasticSearch on localhost:8500..."
    sleep 1
  done
  echo "ElasticSearch now up - continuing..."

  # Create the distribot index:
  curl -XPUT 'http://localhost:9200/distribot/'

}

setup_redis
setup_rabbitmq
setup_elasticsearch

echo '
#### ##    ## ######## ########     ###
 ##  ###   ## ##       ##     ##   ## ##
 ##  ####  ## ##       ##     ##  ##   ##
 ##  ## ## ## ######   ########  ##     ##
 ##  ##  #### ##       ##   ##   #########
 ##  ##   ### ##       ##    ##  ##     ##
#### ##    ## ##       ##     ## ##     ##
'

