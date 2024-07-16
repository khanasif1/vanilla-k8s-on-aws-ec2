#  ===================
#  Ubantu - Master node
#  ===================
 sudo su
 
 sudo apt-get update

 sudo apt-get install docker.io

 sudo systemctl start docker
 sudo systemctl enable docker
 sudo usermod -aG docker ubuntu
 sudo systemctl restart docker

 sudo swapoff -a
 sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo sysctl net.bridge.bridge-nf-call-iptables=1

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg



# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl


sudo systemctl enable --now kubelet

sudo kubeadm init

sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes



#  ===================
#  Calico CNI
#  ===================

sudo curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml -O
kubectl apply -f calico.yaml

# OR

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O
kubectl create -f custom-resources.yaml
watch kubectl get pods -n calico-system

#  ===================
#  Ubantu - Worker node
#  ===================

sudo apt-get update

 sudo apt-get install docker.io

 sudo systemctl start docker
 sudo systemctl enable docker
 sudo usermod -aG docker ubuntu
 sudo systemctl restart docker

 sudo swapoff -a
 sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo sysctl net.bridge.bridge-nf-call-iptables=1



sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg



# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
# sudo apt-mark hold kubelet kubeadm kubectl


# sudo systemctl enable --now kubelet


#  ===================
#  Join Master
#  ===================


sudo kubeadm token create --print-join-command

kubectl get componentstatuses

#  ===================
#  Deploy pod
#  ===================

kubectl create deployment nginxdeploy --image=nginx