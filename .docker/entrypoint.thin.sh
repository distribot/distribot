#!/bin/sh -e

echo Waiting

while ! curl -s "http://$RABBITMQ_USERNAME:$RABBITMQ_PASWORD@$RABBITMQ_HOSTNAME:15672/$RABBITMQ_USERNAME" > /dev/null; do
  echo "Waiting for rabbitmq to come up at $RABBITMQ_HOSTNAME:15672"
  sleep 1
done

auto_start=${AUTO_START:-false}
delay=${AUTO_START_DELAY:-0}
if [ "$auto_start" == "true" ]; then
  echo "RABBITMQ IS UP...starting"
  sleep $delay
  foreman start
else
  tail -f /dev/null
fi

foreman start
