#!/bin/bash

#Update /etc/hosts file on each machine to configure DNS between HAProxy and 3 Master Node KVMs
ansible-playbook -i playbooks/inventory.ini playbooks/update_hosts_file.yml

#Configure HAProxy on HAProxy KVM
ansible-playbook -i playbooks/inventory.ini playbooks/haproxy_setup.yml

#Install necessary packages and properly configure 3 Master Node KVMs
ansible-playbook -i playbooks/inventory.ini playbooks/kubernetes_master_prerequisites.yml

#Initialize three Master Node KVMs
ansible-playbook -i playbooks/inventory.ini playbooks/init_master_leader.yml
ansible-playbook -i playbooks/inventory.ini playbooks/join_master_member.yml

