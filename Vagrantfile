VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "centos/stream9"
  
  config.vm.provider "virtualbox" do |v|
    v.memory = 8192
    v.cpus = 4
  end

  config.vm.define "k8s.local" do |k8s|
    k8s.vm.hostname = "k8s.local"
    k8s.vm.network "private_network", ip: "192.168.56.10"
  end

  config.vm.provision "ansible" do |ansible|
    ansible.verbose = "v"
    ansible.playbook = "./ansible/bootstrap.yaml"
    ansible.inventory_path = "./ansible/local_hosts"
    ansible.limit = "all"
    ansible.ask_vault_pass = true
  end

  config.vm.synced_folder "./ansible/files/scripts", "/srv/ansible/scripts", type: "rsync"
  config.vm.synced_folder "./k8s", "/srv/k8s", type: "rsync"
end
