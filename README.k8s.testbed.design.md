# SONiC Kubernetes Testbed Design

This document describes the design to test Kubernetes features in SONiC. 

## Background

Each SONiC DUT is a worker node managed by a High Availability Kubernetes master in Starlab. The High Availability Kubernetes master is composed of multiple master nodes.

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
![alt text](https://github.com/isabelmsft/k8s-ha-master/blob/master/k8s-testbed-diagram.PNG)
- Each high availability master setup requires 4 new Linux KVMs running on Starlab server(s) via bridged networking.
    - KVM Bridged networking in 10.64.246.0/23 subnet allows for connectivity from SONiC DUTs in Starlab. 
- The 4 new KVMs are as follows: 
    - 3 Linux KVMs to serve as 3-node high availability Kubernetes master
    - 1 Linux KVM to serve as HAProxy Load Balancer node
- For the initial set up of the high availability master, an Ansible agent is required to run the Ansible jobs to set up and configure the HA functionality through the 4 Linux KVMs mentioned above. 

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


In this setup, we do not consider load balancer performance. For Kubernetes feature testing purposes, HAProxy is configured to perform vanilla round-robin load balancing on available master servers. In production, we will use BGPSpeaker anycast routing to support high availability master performance. Testing of BGPSpeaker load balancing performance is beyond the scope of this design.

## How to Setup High Availability Kubernetes Master
1. Allocate 4 available IPs in 10.64.246.0/23 subnet.
2. Spin up 4 new KVMs (3 master servers, 1 HAProxy server) using the IPs above.<Was using virt-install, will port this to an Ansible job to automate) 
3. From Ansible agent (could be set up on Starlab server or using sonic-mgmt container), run the Ansible jobs in this repository.
4. Join Kubernetes-enabled SONiC DUT to cluster (kube_join function to be written)

## How to Create Tests
Each manifest is a yaml file

CLI to make changes to manifest files

pytests to apply manifest changes and check status
