# Build multus plugin
FROM golang:1.10 AS multus
RUN git clone -q -b v2.0 --depth 1 https://github.com/intel/multus-cni.git /go/src/github.com/intel/multus-cni
WORKDIR /go/src/github.com/intel/multus-cni
RUN ./build

# Build sriov plugin
FROM golang:1.10 AS sriov-cni
RUN git clone -q https://github.com/Intel-Corp/sriov-cni.git /go/src/github.com/intel-corp/sriov-cni
WORKDIR /go/src/github.com/intel-corp/sriov-cni
RUN git fetch -q && git checkout -q dev/sriov-network-device-plugin-alpha
RUN ./build

# Build sriov device plugin
FROM golang:1.10 AS sriov-dp
## Install protoc
RUN apt-get update -y && apt-get install -y unzip
RUN curl -sOL https://github.com/google/protobuf/releases/download/v3.2.0/protoc-3.2.0-linux-x86_64.zip && \
    unzip protoc-3.2.0-linux-x86_64.zip -d protoc3 && \
    mv protoc3/bin/* /usr/local/bin/ && mv protoc3/include/* /usr/local/include/
## Install protobuf 1.0
RUN go get -u github.com/golang/protobuf/proto && \
    go get -u github.com/golang/protobuf/protoc-gen-go && \
    cd /go/src/github.com/golang/protobuf && git checkout -q v1.0.0 && \
    make install
RUN git clone -q https://github.com/intel/sriov-network-device-plugin.git /go/src/github.com/intel/sriov-network-device-plugin
WORKDIR /go/src/github.com/intel/sriov-network-device-plugin
RUN ./build.sh

# Patch Kubelet
FROM golang:1.10 AS k8s
RUN apt-get update -y && apt-get install -y rsync
RUN git clone -q -b v1.10.0 --depth 1 https://github.com/kubernetes/kubernetes /go/src/github.com/kubernetes/kubernetes
WORKDIR /go/src/github.com/kubernetes/kubernetes
COPY --from=sriov-dp /go/src/github.com/intel/sriov-network-device-plugin/patches/device_plugin_pod_info_to_allocate.patch .
RUN git apply device_plugin_pod_info_to_allocate.patch && make WHAT=cmd/kubelet

# Final image
FROM centos/systemd
WORKDIR /tmp/cni/bin
COPY --from=multus /go/src/github.com/intel/multus-cni/bin/multus .
COPY --from=sriov-cni /go/src/github.com/intel-corp/sriov-cni/bin/sriov .
COPY --from=sriov-dp /go/src/github.com/intel/sriov-network-device-plugin/bin/cnishim .
WORKDIR /tmp/bin
COPY --from=sriov-dp /go/src/github.com/intel/sriov-network-device-plugin/bin/sriovdp .
COPY --from=k8s /go/src/github.com/kubernetes/kubernetes/_output/bin/kubelet .
