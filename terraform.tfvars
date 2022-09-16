
aws_assume_role = "arn:aws:iam::932999788441:role/eks-admin"

cluster_fqdn    = "i2.robofarming.link"
cluster_version = "1.22"

aws_vpc_cidr        = "172.16.0.0/21"
aws_private_subnets = ["172.16.0.0/24", "172.16.1.0/24", "172.16.2.0/24"]
aws_public_subnets  = ["172.16.3.0/24", "172.16.4.0/24", "172.16.5.0/24"]

aws_tags_cluster_level = {
  owner = "raj13aug@gmail.com"
}

aws_default_region = "us-east-1"


aws_auth_roles = [
  {
    rolearn  = "arn:aws:iam::932999788441:role/eks-admin"
    username = "system:aws:root"
    groups   = ["system:masters"]
  },
  {
    rolearn  = "arn:aws:iam::932999788441:user/Terraform"
    username = "system:aws:root"
    groups   = ["system:masters"]
  },
]


eks_managed_node_groups = {
  i2-ng01 = {
    description = "Amazon EKS managed node group for robofarming.link"
    name        = "eks-ng01"

    ami_type       = "BOTTLEROCKET_x86_64"
    platform       = "bottlerocket"
    instance_types = ["t2.medium"]

    desired_size = 1
    min_size     = 1
    max_size     = 1

    block_device_mappings = {
      root = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 4
          volume_type           = "gp3"
          delete_on_termination = true
          encrypted             = true
        }
      }
      containers = {
        device_name = "/dev/xvdb"
        ebs = {
          volume_size           = 21
          volume_type           = "gp3"
          delete_on_termination = true
          encrypted             = true
        }
      }
    }
  }
}

cloudwatch_log_group_retention_in_days = 1
cluster_enabled_log_types              = [] # "audit", "authenticator" "API server", "Controller manager", "Scheduler"

aws_tags_group_level = {
  cluster_group = "dev-evn"
  entity        = "org"
  environment   = "dev"
}