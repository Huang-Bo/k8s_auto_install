#!/bin/bash
K8S_VERSION="1.22.3"
# 安装kubeadm kubectl kubelet.
sudo yum install -y kubelet-${K8S_VERSION} kubeadm-${K8S_VERSION} kubectl-${K8S_VERSION}--disableexcludes=kubernetes
sudo systemctl enable --now kubelet