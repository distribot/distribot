#!/bin/sh -e

echo Waiting

while ! curl -s "http://$RABBITMQ_USERNAME:$RABBITMQ_PASWORD@$RABBITMQ_HOSTNAME:15672/$RABBITMQ_USERNAME" > /dev/null; do
  echo "Waiting for rabbitmq to come up at $RABBITMQ_HOSTNAME:15672"
  sleep 1
done

echo "RABBITMQ IS UP...starting"
foreman start
