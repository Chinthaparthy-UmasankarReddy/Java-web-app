resource "aws_instance" "k8s_master" {
  ami                    = var.ami_id
  instance_type          = "c7i-flex.large"
  subnet_id              = aws_subnet.k8s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = var.key_pair_name 
  tags = {
    Name          = "Java-web-app-master"
    Environment   = "production"
    KubernetesCluster = "Java-web-app"
    Role          = "master"
  }
}

resource "aws_instance" "k8s_worker1" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.k8s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               =  var.key_pair_name 
  tags = {
    Name          = "Java-web-app-worker1"
    Environment   = "production"
    KubernetesCluster = "Java-web-app"
    Role          = "worker"
    WorkerNumber  = "1"
  }
}

resource "aws_instance" "k8s_worker2" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.k8s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = var.key_pair_name 
  tags = {
    Name          = "Java-web-app-worker2"
    Environment   = "production"
    KubernetesCluster = "Java-web-app"
    Role          = "worker"
    WorkerNumber  = "2"
  }
}

output "master_ip" {
  value = aws_instance.k8s_master.public_ip
}

output "worker1_ip" {
  value = aws_instance.k8s_worker1.public_ip
}

output "worker2_ip" {
  value = aws_instance.k8s_worker2.public_ip
}
