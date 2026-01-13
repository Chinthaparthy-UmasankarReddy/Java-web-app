
# Kubernetes Cluster on AWS EC2 - Terraform Deployment

## Overview
Production-grade Kubernetes cluster deployment using Terraform with:
- **1 x c7i-flex.large** (Master node)
- **2 x t3.small** (Worker nodes) 
- Ubuntu AMI: `ami-02b8269d5e85954ef`
- Default VPC
- Cluster name: **Java-web-app**
- Custom key pair required

## Terraform Files

### providers.tf
```hcl
terraform {
  required_version = ">= 1.4.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Default VPC region, adjust as needed
}
```

### variables.tf
```hcl
variable "key_name" {
  description = "Name of the custom EC2 KeyPair"
  type        = string
  default     = "k8s-cluster-key"  # Create this keypair in AWS first
}

variable "cluster_name" {
  description = "Name of the K8s cluster"
  type        = string
  default     = "Java-web-app"
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-02b8269d5e85954ef"
}
```

### main.tf (Data Sources & Security Group)
```hcl
# Data source for default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  default_for_az    = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group for K8s cluster (production grade)
resource "aws_security_group" "k8s_cluster" {
  name_prefix = "${var.cluster_name}-"
  vpc_id      = data.aws_vpc.default.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
  }

  # K8s API Server (6443)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to worker nodes/VPC CIDR
  }

  # Kubelet API (NodePorts, 30000-32767)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd (2379-2380)
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  # Kubelet (10250, 10255)
  ingress {
    from_port   = 10250
    to_port     = 10255
    protocol    = "tcp"
    self        = true
  }

  tags = {
    Name = "${var.cluster_name}-sg"
  }
}
```

### Master Node Configuration
```hcl
# Master Node - c7i-flex.large
resource "aws_instance" "k8s_master" {
  ami                    = var.ami_id
  instance_type          = "c7i.flex.large"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_cluster.id]
  subnet_id              = data.aws_subnet.default.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    
    # Install Kubernetes components
    apt-get install -y apt-transport-https ca-certificates curl gnupg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    
    # Initialize kubeadm
    kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    # Setup kubectl
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    
    # Install Flannel CNI
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
    
    # Save kubeconfig for external access
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
  EOF

  tags = {
    Name        = "${var.cluster_name}-master"
    Role        = "master"
    Environment = "production"
  }
}
```

### Worker Nodes Configuration
```hcl
# Worker Node 1 - t3.small
resource "aws_instance" "k8s_worker1" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_cluster.id]
  subnet_id              = data.aws_subnet.default.id
  associate_public_ip_address = true
  depends_on             = [aws_instance.k8s_master]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    
    # Install Kubernetes
    apt-get install -y apt-transport-https ca-certificates curl gnupg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    
    # Join cluster (command will be available after master initialization)
  EOF

  tags = {
    Name        = "${var.cluster_name}-worker-1"
    Role        = "worker"
    Worker      = "1"
    Environment = "production"
  }
}

# Worker Node 2 - t3.small (identical to worker1)
```

### Outputs
```hcl
output "master_public_ip" {
  value = aws_instance.k8s_master.public_ip
}

output "worker1_public_ip" {
  value = aws_instance.k8s_worker1.public_ip
}

output "worker2_public_ip" {
  value = aws_instance.k8s_worker2.public_ip
}
```

## 🚀 Deployment Steps

1. **Create Key Pair**
   ```bash
   # Create key pair in AWS EC2 console named "k8s-cluster-key"
   ```

2. **Terraform Commands**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Get Join Command** (SSH to master)
   ```bash
   ssh -i k8s-cluster-key.pem ubuntu@<MASTER_PUBLIC_IP>
   kubeadm token create --print-join-command
   ```

4. **Join Workers**
   ```bash
   # On each worker node
   ssh -i k8s-cluster-key.pem ubuntu@<WORKER_PUBLIC_IP>
   <PASTE_JOIN_COMMAND_HERE>
   ```

5. **Verify Cluster**
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

## 🔒 Production Security Recommendations

- **Restrict Security Groups**: Limit SSH (22), API Server (6443) to your IP
- **Use Bastion Host**: Instead of direct public access
- **Enable AWS SSM**: For secure access without key pairs
- **Network Policies**: Implement for pod-to-pod security
- **RBAC**: Configure proper role-based access control
- **Monitoring**: Add Prometheus + Grafana
- **Logging**: Deploy EFK (Elasticsearch, Fluentd, Kibana) stack

## 📊 Cluster Specifications

| Component | Instance Type | Count | Role | Storage |
|-----------|---------------|-------|------|---------|
| Master    | c7i.flex.large | 1     | Control Plane | 30GB gp3 |
| Worker 1  | t3.small      | 1     | Worker Node   | 20GB gp3 |
| Worker 2  | t3.small      | 1     | Worker Node   | 20GB gp3 |

## Next Steps for Java Web App

1. Deploy your Java application
2. Set up Horizontal Pod Autoscaler
3. Configure Ingress controller (nginx/ALB)
4. Add persistent storage (EBS CSI driver)
5. Enable cluster autoscaler

---
*Production-grade K8s cluster ready for Java web applications*
```













🚀 COMPLETE EXECUTION SEQUENCE
# On your Ansible control machine (Amazon Linux 2023)

# 1. Verify dynamic inventory
ansible-inventory -i aws_ec2.yaml --graph
# Should show: role_masters, role_workers

# 2. CLEANUP everything
ansible-playbook -i aws_ec2.yaml cleanup.yml --forks 5

# 3. Setup MASTER
ansible-playbook -i aws_ec2.yaml master.yml

# 4. Setup WORKERS
ansible-playbook -i aws_ec2.yaml workers.yml

# 5. SSH to MASTER and initialize
ssh -i ~/.ssh/uma.pem ubuntu@MASTER_PUBLIC_IP
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=1.30.0

# Setup kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

6. Install CNI + Join Workers
# On MASTER
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Copy join command from kubeadm init output
# On each WORKER:
ssh -i ~/.ssh/uma.pem ubuntu@WORKER1_IP
sudo kubeadm join [JOIN_COMMAND]

7. Verify Production Cluster
# On MASTER
kubectl get nodes
# NAME              STATUS   ROLES           AGE   VERSION
# master            Ready    control-plane   5m    v1.30.0
# worker1           Ready    <none>          2m    v1.30.0
# worker2           Ready    <none>          2m    v1.30.0

kubectl get pods -n kube-system  # All Running
sudo crictl ps  # containerd ✅ No Docker
