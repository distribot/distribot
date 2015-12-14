#!/bin/bash

set -e

setup_dependencies() {
  sudo apt-get -y update
  sudo apt-get -y autoremove
  sudo apt-get install -y \
    ruby2.0 \
    ruby2.0-dev \
    build-essential \
    git \
    wget \
    vim \
    librabbitmq-dev \
    psmisc \
    curl \
    libcurl4-gnutls-dev \
    python

  sudo ln -sf /usr/bin/ruby2.0 /usr/bin/ruby && sudo ln -sf /usr/bin/gem2.0 /usr/bin/gem

  if ! gem list | grep bundler; then
    sudo gem install bundler --no-ri --no-rdoc
  fi

  # Don't fail because we haven't added github.com's ssh key to our known_hosts:
  cat <<EOF | sudo tee -a /etc/ssh/ssh_config > /dev/null
Host github.com
    StrictHostKeyChecking no
EOF

  sudo gem install eye --no-ri --no-rdoc
}

setup_fluentd() {
  if [ -f /etc/init.d/td-agent ]; then
    echo "fluentd is already installed"
  else
    curl -L http://toolbelt.treasuredata.com/sh/install-ubuntu-trusty-td-agent2.sh | sudo sh
  fi

  if td-agent-gem list | grep fluent-plugin-elasticsearch; then
    echo "fluent-plugin-elasticsearch is already installed"
  else
    sudo td-agent-gem install fluent-plugin-elasticsearch -v 0.7.0 --no-ri --no-rdoc
  fi

  if grep "distribot" /etc/rsyslog.conf; then
    echo "syslogd already forwarding events to fluentd"
  else
    echo '!distribot' | sudo tee -a /etc/rsyslog.conf
    echo "*.* @127.0.0.1:42185" | sudo tee -a /etc/rsyslog.conf
    sudo service rsyslog restart
  fi

  sudo cp provision/templates/fluentd.conf /etc/td-agent/td-agent.conf

  # Finally, restart td-agent:
  sudo service td-agent restart
}

setup_dependencies
setup_fluentd

cd /var/www/distribot
bundle


