VAGRANTFILE_API_VERSION = "2"

### Settings of IS_PROVISIONED ###
if ENV["IS_PROVISIONED"].nil?
  IS_PROVISIONED = false
else
  IS_PROVISIONED = ["true", "yes", "on", "t", "1", "y"].include?(ENV["IS_PROVISIONED"])
end

if IS_PROVISIONED
  print "[INFO] Use 'k8s' as the SSH user.\n\n"
  sync_owner = "k8s"
  sync_group = "k8s"
else
  Warning.warn("[WARN] Use 'vagrant' as the SSH user because IS_PROVISIONED is not set.\n\n")
  sync_owner = "vagrant"
  sync_group = "vagrant"
end
###

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "generic/centos9s"

  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end
  
  config.vm.provider "virtualbox" do |v|
    v.memory = 8192
    v.cpus = 4
  end

  config.vm.define "k8s.local" do |k8s|
    k8s.vm.hostname = "k8s.local"
    k8s.vm.network "private_network", ip: "192.168.56.10"
  end

  if IS_PROVISIONED
    config.ssh.username = "k8s"
    config.ssh.private_key_path = "/home/itk/.ssh/vagrant/k8s/id_rsa.pem"
  end

  config.vm.provision "ansible" do |ansible|
    ansible.verbose = "v"
    ansible.playbook = "./ansible/bootstrap.yaml"
    ansible.inventory_path = "./ansible/local_hosts"
    ansible.limit = "all"
    ansible.ask_vault_pass = true
  end

  config.vm.synced_folder "./ansible/files/scripts", "/srv/ansible/scripts", type: "rsync", owner: sync_owner, group: sync_group
  config.vm.synced_folder "./k8s", "/srv/k8s", type: "rsync", owner: sync_owner, group: sync_group
  config.vm.synced_folder "./kubelog", "/var/log/pods"
  config.vm.synced_folder "./share", "/srv/share", owner: sync_owner, group: sync_group
end
