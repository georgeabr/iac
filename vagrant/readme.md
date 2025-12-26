#### Guide to set up a vagrant lab for RHCSA
Version 9
These labs will create 2 VMs via libvirt on linux  
In a folder `/mnt/data/backup/rhcsa-lab/rhcsa9` put the corresponding `Vagrantfile`
Two VMs will be created  
Name: `alma9-1`, IP: `192.168.40.11`  
Name: `alma9-2`, IP: `192.168.40.12`  


To start the lab VMs
```bash
vagrant up
```
To connect to any of the VMs
```bash
vagrant ssh alma9-1
```
Become `root` in the VM
```bash
sudo -i
```
To stop the lab VMs
```bash
vagrant down
```

To destroy the VMs
```bash
vagrant destroy -f
```
### Get rid of warnings for `libvirt_ip_command`
```bash
cd ~
git clone https://github.com/vagrant-libvirt/vagrant-libvirt.git
cd vagrant-libvirt
grep -R "libvirt_ip_command" .
vim ./lib/vagrant-libvirt/driver.rb
# comment out the libvirt_ip line
less ./lib/vagrant-libvirt/driver.rb
# make another branch
git checkout -b no-libvirt-ip-command
# needed if build errors on Debian
sudo apt install -y ruby-full build-essential libvirt-dev
# build the gem
gem build vagrant-libvirt.gemspec
# uninstall buggy version
vagrant plugin uninstall vagrant-libvirt
vagrant plugin install ./vagrant-libvirt-0.12.3.pre.18.gem
# confirm the gem is newer
vagrant plugin list
```
