# k8s_auto_install
The functions of this script are as follows
1. Initialize the operating system.
2. Install Docker and Configure Docker Mirror Acceleration.
3. Install Kubernetes Master.
4. Kubernetes Version v1.22.3.
5. Network plugins  Calico|Flannel(v0.14.0) Choose one of the two.
6. podSubnet: 10.244.0.0/16   serviceSubnet: 10.96.0.0/12.
7. Ingress Version v1.1.0.
