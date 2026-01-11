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
