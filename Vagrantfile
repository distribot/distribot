#!/usr/bin/env ruby

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.ssh.username = 'vagrant'
  config.ssh.password = 'vagrant'
  config.vm.box = "ubuntu/trusty64"

  # vagrant-berkshelf is incompatible with vagrant-librarian-chef
  if Vagrant.has_plugin?('vagrant-berkshelf')
    config.berkshelf.enabled = false
  end

  # If this Vagrantfile is in /foo/bar/baz then set the hostname to 'baz':
  app_name = File.split(Dir.getwd)[-1]
  config.vm.network "private_network", type: :dhcp
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2048"]
  end
  installation_path = "/var/www/#{app_name}"
  config.vm.synced_folder "./", installation_path, nfs: true

  # From SO http://stackoverflow.com/a/16127657
  system("ssh-add ~/.ssh/id_rsa") unless `ssh-add -L` =~ %r{#{ENV['HOME']}/\.ssh/id_rsa}
  config.ssh.forward_agent = true
  config.ssh.private_key_path = [
    '~/.vagrant.d/insecure_private_key',
    '~/.ssh/id_rsa'
  ]
  config.vm.provision :shell, privileged: false, inline: '/var/www/distribot/provision_vm.sh'
end
