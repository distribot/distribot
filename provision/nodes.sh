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
  vim \
  librabbitmq-dev \
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

cd /var/www/distribot
bundle


