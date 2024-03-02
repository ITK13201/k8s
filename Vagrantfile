Vagrant.configure("2") do |config|
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
  end

  config.vm.synced_folder "./bin", "/usr/local/src/k8s/bin"
  config.vm.synced_folder "./manifests", "/usr/local/src/k8s/manifests"
  config.vm.synced_folder "./log/pods", "/var/log/pods"
end
