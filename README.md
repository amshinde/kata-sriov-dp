This repo cntains all the resource files for setting up Kata with SRIOV device plugin.

It contains a daemonset to copy binaries for multus,sriov,cni-shim and patched kubelet
to the host and start the sriov device plugin.
Also included are multus CRD and a test pod yaml for Kata.
