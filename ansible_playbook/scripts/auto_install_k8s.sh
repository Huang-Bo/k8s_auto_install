#!/bin/bash
####################################################
### Description: Kubernetes Auto Install Scripts.###
### Auther: Huang-Bo                             ###
### Email: 17521365211@163.com                   ###
### Blog: https://blog.csdn.net/Habo_            ###
### Create Date: 2022-07-13                      ###
####################################################
#############################################################################################
# 颜色函数
#############################################################################################
function COLOR_RED() {
        echo -e "\033[1;31m$1\033[0m"
}

function COLOR_GREEN() {
        echo -e "\033[1;32m$1\033[0m"
}

function COLOR_YELLOW() {
        echo -e "\033[1;33m$1\033[0m"
}
#############################################################################################
# 文本颜色函数
#############################################################################################
function echo_check() {
        echo -e "$1  [\033[32m √ \033[0m]"
}

function log_success() {
        COLOR_GREEN "[SUCCESS] $1"
}

function log_error() {
        COLOR_RED "[ERROR] $1"
}
function log_info() {
        COLOR_YELLOW "[INFO] $1"
}
echo -e "\033[33m###################### K8s Auto Install Scripts Description ###################### \033[0m"
echo -e "\033[32m#\033[0m"
echo -e "\033[32m# 1. Initialize the operating system. \033[0m"
echo -e "\033[32m# 2. Install Docker and Configure Docker Mirror Acceleration. \033[0m"
echo -e "\033[32m# 3. Install Kubernetes Master. \033[0m"
echo -e "\033[32m# 4. Kubernetes Version v1.22.3 \033[0m"
echo -e "\033[32m# 5. Network plugins  Calico|Flannel(v0.14.0) Choose one of the two. \033[0m"
echo -e "\033[32m# 6. podSubnet: 10.244.0.0/16   serviceSubnet: 10.96.0.0/12. \033[0m"
echo -e "\033[32m# 7. Ingress Version v1.1.0. \033[0m"
echo -e "\033[33m################################################################################## \033[0m"
echo ""
echo ""
function replace_yum_source()
{
# 首先运行配置yum源脚本
echo "请先运行设置yum源脚本"
bash /k8s_auto_install/ansible_playbook/scripts/repo.sh
}
function configure_ansible()
{
echo -e "\033[33m############################# step 1. configure Ansible. ############################# \033[0m"
#############################################################################################
# kubernetes master节点配置ansible作为集群管理机
#############################################################################################
yum -y install epel-release ansible

cat >>/etc/ansible/hosts <<EOF
#添加被管理端IP组
[k8s_master]
192.168.1.100
192.168.1.101
[k8s_nodes]
192.168.1.102
192.168.1.103
192.168.1.104
EOF
#********************************************************************************************
# 可选操作，默认ansible远程用户为root用户                                                    ***
# 将远程用户设置为ops用户                                                                  ***
# sed -i  '10 a\remote_user=ops\n' /etc/ansible/ansible.cfg                               ***
# 开启普通用户提权参数                                                                     ***
# cat >> /etc/ansible/ansible.cfg << EOF                                                  ***
# [privilege_escalation]                                                                  ***
# become=True                                                                             ***
# become_method=sudo                                                                      ***
# become_user=root                                                                        ***
# become_ask_pass=False                                                                   ***
# [defaults]                                                                              ***
# remote_user=ops                                                                         ***
# EOF                                                                                     ***
#********************************************************************************************
}
#############################################################################################
function secret_free_configuration()
{
echo -e "\033[33m############################# step 2. Configure Password Free Login. ############################# \033[0m"
# 安装expect软件包及分发公钥
#############################################################################################
# cat /k8s_auto_install/ansible_playbook/scripts/iplist.txt
# 192.168.1.102 root redhat
# 192.168.1.103 root redhat
# 192.168.1.104 root redhat
# 创建密钥
if ssh-keygen -t rsa;then
   log_success "密钥创建成功"
else
   log_error "密钥创建失败"
fi
yum -y install expect

while read host;do
        ip=$(echo "$host" |cut -d " " -f1)
        username=$(echo "$host" |cut -d " " -f2)
        password=$(echo "$host" |cut -d " " -f3)
expect <<EOF
        spawn ssh-copy-id -i $username@$ip
        expect {
               "yes/no" {send "yes\n";exp_continue}
               "password" {send "$password\n"}
        }
        expect eof
EOF
done < /k8s_auto_install/ansible_playbook/tools/iplist.txt

echo -e "\033[33m############################# step 3. host $ip pub-key check ############################# \033[0m"
IP_DIR="/k8s_auto_install/ansible_playbook/tools/iplist.txt"
USERNAME="root"
HOSTS=$(cat ${IP_DIR} | awk '{print $1}')
for ip in ${HOSTS}; do
        if ssh "$USERNAME"@"$ip" "echo success"; then
                log_success "${ip} Connection successful."
        else
                log_error "${ip} connection failed."
        fi
done
}
function execute_scripts()
{
# #############################################################################################
# 0.分发所需脚本和文件至集群内所有机器（可选，脚本不需要分发到客户端也可以远程执行脚本.）
# #############################################################################################
#ansible-playbook /k8s_auto_install/ansible_playbook/file/file_distribution.yaml
# #############################################################################################
# 1.所有服务器配置yum源
# #############################################################################################
ansible k8s_nodes -m script -a "/k8s_auto_install/ansible_playbook/scripts/repo.sh"
# #############################################################################################
# 2.所有服务器安装常用运维软件
# #############################################################################################
ansible-playbook /k8s_auto_install/ansible_playbook/file/install_software.yaml
# #############################################################################################
# 3.创建运维账号，并配置sudo权限
# #############################################################################################
ansible k8s_nodes -m script -a "/k8s_auto_install/ansible_playbook/scripts/user_create.sh"
# #############################################################################################
# 4.字符集修改 && 内核优化 && 关闭防火墙 && 关闭交换分区 && 设置主机名
# #############################################################################################
ansible k8s_nodes -m script -a "/k8s_auto_install/ansible_playbook/scripts/os_init.sh"
# #############################################################################################
# 5.配置ipvs
# #############################################################################################
ansible k8s_nodes -m script -a "/k8s_auto_install/ansible_playbook/scripts/install_ipvs.sh"
# #############################################################################################
# 6.安装docker并配置docker
# #############################################################################################
ansible k8s_nodes -m script -a "/k8s_auto_install/ansible_playbook/scripts/install_docker.sh"
}
function install_kubernetes()
{
# 配置kubernetes.repo
ansible k8s_nodes -m script -a "/k8s_auto_install/ansible_playbook/scripts/install_k8s.sh"

}
#secret_free_configuration