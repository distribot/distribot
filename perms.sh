#!/bin/bash

set -e

RABBITMQ_USERNAME=distribot
RABBITMQ_PASSWORD=distribot

sudo cat <<EOF | sudo tee -a /etc/redis/redis.conf
bind 0.0.0.0
EOF

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

sudo service rabbitmq-server restart
sudo service redis-server restart
echo "Infra ready..."
