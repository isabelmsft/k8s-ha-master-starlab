# SONiC Kubernetes Design

This document describes the design to test Kubernetes features in SONiC. 

## Background

Each SONiC DUT is a worker node managed by a High Availability Kubernetes master. The High Availability Kubernetes master is composed of three master node machines and one load balancer machine.

By connecting each SONiC DUT to HA Kubernetes master, containers running in SONiC can be managed by the Kubernetes master. SONiC containers managed by the Kubernetes master are termed to be running in "Kubernetes mode" as opposed to the original "Local mode." 

In Kubernetes mode, SONiC container properties are based on specifications defined in the associated Kubernetes manifest. A Kubernetes manifest is a file in the Kubernetes master that defines the Kubernetes object and container configurations. In our case, we use Kubernetes Daemonset objects. The Kubernetes Daemonset object ensures that each worker node is running exactly one container of the image specified in the Daemonset manifest file.  

For example, in order to run SNMP and Telemetry containers in Kubernetes mode, we must have two manifests that define two Kubernetes Daemonset objects- one for each container running in "Kubernetes mode." 

The following is a snippet of the Telemetry Daemonset manifest file that specifies the Kubernetes object type and container image:

```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: telemetry-ds
spec:
  template:
    metadata:
      labels:
        name: telemetry
    spec:
      hostname: sonic
      hostNetwork: true
      containers:
      - name: telemetry
        image: sonicanalytics.azurecr.io/sonic-dockers/any/docker-sonic-telemetry:20200531
        tty: true
            .
            .
            .
```


## Topology Overview

In order to connect each SONiC DUT to a High Availability Kubernetes master, we need to set up the following topology: 
![alt text](https://github.com/isabelmsft/k8s-ha-master-starlab/blob/master/k8s-testbed-linux.png)
- Each high availability master setup requires 4 new Linux KVMs running on a Testbed Server via bridged networking.
    - 3 Linux KVMs to serve as 3-node high availability Kubernetes master
    - 1 Linux KVM to serve as HAProxy Load Balancer node    
- Each KVM has one management interface assigned an IP address reachable from SONiC DUT
- HAProxy Load Balancer proxies requests to 3 backend Kubernetes master nodes. 

## How to Setup High Availability Kubernetes Master

1. Prepare Testbed Server and build and run `docker-sonic-mgmt` container as described [here](https://github.com/Azure/sonic-mgmt/blob/master/ansible/doc/README.testbed.Setup.md) 
2. Allocate 4 available IPs reachable from SONiC DUT.
3. Update [`ansible/k8s-ubuntu`](../k8s-ubuntu) to include your 4 newly allocated IP addresses for the HA Kubernetes master.

We will walk through an example of setting up HA Kubernetes master set 1 on server 19 (STR-ACS-SERV-19). The following snippet is the relevant portion from [`ansible/k8s-ubuntu`](../k8s-ubuntu).

  ```
  k8s_vms1_19:
  hosts:
    kvm19-1m1:
      ansible_host: 10.250.0.2
      master: true
      master_leader: true
    kvm19-1m2:
      ansible_host: 10.250.0.3
      master: true
      master_member: true
    kvm19-1m3:
      ansible_host: 10.250.0.4
      master_member: true
      master: true
    kvm19-1ha:
      ansible_host: 10.250.0.5
      haproxy: true 
  ```
  

Replace each ansible_host value with an available IP address. 

Take note of the group name `k8s_vms1_19`. At the bottom of [`ansible/k8s-ubuntu`](../k8s-ubuntu), make sure that `k8s_server_19` has its `host_var_file` and two `children` properly set: 

```
k8s_server_19:
  vars:
    host_var_file: host_vars/STR-ACS-SERV-19.yml
  children:
    k8s_vm_host19:
    k8s_vms1_19:
```

4. Update the server network configuration for the Kubernetes VM management interfaces in [`ansible/host_vars/STR-ACS-SERV-19.yml`](../host_vars/STR-ACS-SERV-19.yml).
    - `mgmt_gw`: ip of the gateway for the VM management interfaces
    - `mgmt_prefixlen`: prefixlen for the management interfaces
5. Update the testbed server credentials in [`ansible/group_vars/k8s_vm_host/creds.yml`](../group_vars/k8s_vm_host/creds.yml).   
6. From `docker-sonic-mgmt` container, run `./testbed-cli.sh -m k8s-ubuntu [additional OPTIONS] create-master 'k8s-server-name' ~/.password.txt"`
   - k8s_server_name corresponds to the group name used to describe the testbed server in the [`ansible/k8s-ubuntu`](../k8s-ubuntu) inventory file. 
   - Please note: password.txt is the ansible vault password file name/path. Ansible allows users to use ansible-vault to encrypt password files. By default, this shell script requires a password file. If you are not using ansible-vault, just create an empty file and pass the file name to the command line. The file name and location are created and maintained by the user.
   
For HA Kubernetes master set 1 running on server 19 shown above, the proper command would be: 
`./testbed-cli.sh -m k8s-ubuntu create-master k8s_server_19 ~/.password` 

OPTIONAL: We offer the functionality to run multiple master sets on one server. 
  - Each master set is one HA Kubernetes master composed of 4 Linux KVMs. 
  - Should an additional HA master be necessary on an occupied server, add the option `-s {msetnumber}`, where `msetnumber` would be 2 if this is the 2nd master set running on `{k8s-server-name}`. Make sure that [`ansible/k8s-ubuntu`](../k8s-ubuntu) is updated accordingly. `msetnumber` is 1 by default. 


7. Join Kubernetes-enabled SONiC DUT to cluster (kube_join function to be written).

The setup above meets Kubernetes Minimum Requirements to setup a High Available cluster. The Minimum Requirements are as follows:
- 2 GB or more of RAM per machine
- 2 CPUs or more per machine
- Full network connectivity between all machines in the cluster (public or private network)
- sudo privileges on all machines
- SSH access from one device to all nodes in the system

To remove a HA Kubernetes master, run `./testbed-cli.sh -m k8s-ubuntu [additional OPTIONS] destroy-master 'k8s-server-name' ~/.password.txt"`
For HA Kubernetes master set 1 running on server 19 shown above, the proper command would be: 
`./testbed-cli.sh -m k8s-ubuntu destroy-master k8s_server_19 ~/.password` 

## Testing Scope

This setup allows us to test the following: 
- Successful deployment of SONiC containers via manifests defined in master
- Expected container behavior after the container is intentionally or unintentionally stopped
- Switching between Local and Kubernetes management mode for a given container
  - Addition and removal of SONiC DUT labels
- Changing image version in middle of Daemonset deployment

During each of the following states:
- When all master servers are up and running
- When one master server is down
- When two master servers are down
- When all master servers are down

Down: shut off, disconnected, or in the middle of reboot


In this setup, we do not consider load balancer performance. For Kubernetes feature testing purposes, HAProxy is configured to perform vanilla round-robin load balancing on available master servers.


## How to Create Tests
Each manifest is a yaml file

CLI to make changes to manifest files

pytests to apply manifest changes and check status
