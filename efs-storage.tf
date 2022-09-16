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

resource "helm_release" "efs_csi_driver" {
  count      = var.enable_efs ? 1 : 0
  name       = "aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  # this is app version 1.3.7
  version   = "2.2.5"
  namespace = "kube-system"

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.eu-central-1.amazonaws.com/eks/aws-efs-csi-driver"
  }
  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.efs_csi_driver[0].metadata[0].name
  }

}

# add efs file system with mount points

resource "aws_efs_file_system" "efs" {
  count            = var.enable_efs ? 1 : 0
  creation_token   = "efs-staging"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
}

resource "aws_efs_mount_target" "efs-mt" {
  file_system_id  = aws_efs_file_system.efs[0].id
  security_groups = [aws_security_group.efs[0].id]
  for_each        = var.enable_efs ? toset(var.private_subnets) : toset([])
  subnet_id       = each.key
}


resource "aws_security_group" "efs" {
  count       = var.enable_efs ? 1 : 0
  name        = "efs-sg"
  description = "Allows inbound EFS traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

}

resource "aws_security_group_rule" "example" {
  count                    = var.enable_efs ? 1 : 0
  description              = "Allow outbound EFS traffic"
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.efs[0].id
  security_group_id        = module.eks.node_security_group_id
}