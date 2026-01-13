variable "region" {
  description = "AWS region"
  type        = string
  default     = "your-region"
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-02b8269d5e85954ef"
}

variable "key_pair_name" {
  description = "Existing AWS EC2 Key Pair name"
  type        = string
  default     = "uma"  # Your existing key pair
}

variable "availability_zone" {
  description = "AWS Availability Zone"
  type        = string
  default     = "ap-south-1a"
}
