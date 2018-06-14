# kata-sriov-dp

This repository contains all the resource files for setting up [SRIOV](https://github.com/intel/sriov-network-device-plugin) device plugin on a Kubernetes cluster.

`kata-sriov-dp` provides a Dockerfile that builds [Multus CNI](https://github.com/intel/multus-cni) plugin, [SRIOV CNI](https://github.com/intel-corp/sriov-cni) plugin,
[SRIOV Device Plugin](https://github.com/intel/sriov-network-device-plugin) and a patched version of kubelet 1.10 that is required for the device plugin.
A deamonset is also provided that runs the SRIOV device plugin itself.

The steps to set up the device plugin assume you have a Kubernetes cluster setup, with nodes having a SRIOV enabled network card.

## Kata Containers setup

Below instructions to verify the SRIOV Device plugin work with runc.
To test out Kata Containers with device plugin, setup Kata Containers with Kubernetes. Refer [kata-deploy](https://github.com/egernst/kata-deploy).

## SRIOV Device Plugin Setup

1. Build Docker image.

   Build and push an image using the Dockerfile provided.

2. Create SRIOV virtual functions for your SRIOV network interface.
 
   ```
   $ echo 64 | sudo tee --append  /sys/bus/pci/devices/{sriov_interface_pci_address}/sriov_numvfs
   ```

3. Configure Kubernetes network CRD with Multus.

   In order to add multiple interfaces in a Pod, we configure Kubernetes with a Multus CNI meta plugin that enables
   invoking multiple CNI plugins to add additional interfaces. Multus uses Kubernetes Custom Resource Definition or CRDs
   to define network objects. To do this simply run:

   ```
   $ kubectl apply -f crdnetwork.yaml
   ```

4. Create  CNI-Shim Network CRD instance.

   ```
   $ kubectl apply -f cnishim-crd.yaml
   ```

5. Create Multus ConfigMap.

   This contains the CNI configuration for Multus. This will be used by
   the daemonset to mount the CNI configuration at /etc/cni/net.d/ on every node.

   ```
   $ kubectl apply -f multus-config.yaml
   ```

6. Create the daemonset.

   You will need to apply `sriov-daemon.yaml` as shown below. Before you do this,
   make sure to change the `image` in this yaml file to point to the image you built in step 1,
   or can simply use the image `amshinde/sriovt`.

   ```
   $ kubectl apply -f sriov-daemon.yaml
   ```

7. Create a runc test pod.

   ```
   $ kubectl apply -f pod-runc.yaml
   ```

   Verify network interfaces for the pod. In additon to loopback, you should see two other
   network interfaces.

   ```
   $ kubectl exec -it testpod1 -- ip addr show
	1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
	    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
	    inet 127.0.0.1/8 scope host lo
	       valid_lft forever preferred_lft forever
	    inet6 ::1/128 scope host
	       valid_lft forever preferred_lft forever
	3: eth0@if5835: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP
	    link/ether 0a:58:0a:f4:00:08 brd ff:ff:ff:ff:ff:ff link-netnsid 0
	    inet 10.244.0.8/24 scope global eth0
	       valid_lft forever preferred_lft forever
	    inet6 fe80::3c08:c2ff:fe48:2d8f/64 scope link
	       valid_lft forever preferred_lft forever
	5582: net0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP qlen 1000
	    link/ether 8a:5a:80:d6:e2:3f brd ff:ff:ff:ff:ff:ff
	    inet 10.56.217.172/24 scope global net0
	       valid_lft forever preferred_lft forever
	    inet6 fe80::885a:80ff:fed6:e23f/64 scope link
	       valid_lft forever preferred_lft forever
   ```

8. Create a Kata test pod.

   ```
   $ kubectl apply -f pod-kata.yaml
   ```

   Verify network interface as above. In addition, running `lspci` inside Kata Container should
   show the SRIOV virtual function passed to the VM with device passthrough.
