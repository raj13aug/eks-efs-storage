# based on https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html

# add efs_csi_driver

module "efs_csi_driver_irsa_role" {
  count   = var.enable_efs ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "4.20.1"

  role_name             = "efs-csi-driver"
  attach_efs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-driver"]
    }
  }
}

resource "kubernetes_service_account" "efs_csi_driver" {
  count = var.enable_efs ? 1 : 0
  metadata {
    name      = "efs-csi-driver"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "driver"
      "app.kubernetes.io/name"      = "efs-csi-driver"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.efs_csi_driver_irsa_role[0].iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

/* resource "helm_release" "efs_csi_driver" {
  count      = var.enable_efs ? 1 : 0
  name       = "aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  version    = "2.2.5"
  namespace  = "kube-system"

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-efs-csi-driver"
  }
  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.efs_csi_driver[0].metadata[0].name
  }

} */



# add efs file system with mount points

resource "aws_efs_file_system" "efs" {
  #count            = var.enable_efs ? 1 : 0
  creation_token   = "efs-staging"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
}


# EFS Mount Targets
/* resource "aws_efs_mount_target" "xac-airflow-efs-mt" {
  count           = length(data.aws_availability_zones.available.names)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.xac_airflow_efs_sg.id]
} */


resource "aws_efs_mount_target" "efs_target" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = element(module.vpc.private_subnets, count.index)
  security_groups = [aws_security_group.xac_airflow_efs_sg.id]
}

resource "aws_security_group" "xac_airflow_efs_sg" {
  name        = "xac_airflow_efs"
  description = "Allows inbound efs traffic from EKS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block, "172.16.0.0/21"]
  }

  # fix from https://github.com/aws-samples/aws-eks-accelerator-for-terraform/commit/e6b364d87221eb481d8e93b08bb9597c1e22bf3e
  #
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [module.vpc.vpc_cidr_block, "172.16.0.0/21"]
  }
}