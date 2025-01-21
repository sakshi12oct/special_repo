#####################################################
# User Access
#####################################################

# Administrator Access
resource "aws_eks_access_entry" "Admin" {
  for_each      = var.arn_administrators
  cluster_name  = module.eks.cluster_name
  principal_arn = each.key
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "Admin" {
  for_each     = aws_eks_access_entry.Admin
  cluster_name = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.Admin[each.key].principal_arn

  access_scope {
    type = "cluster"
  }
}

#########################################################
# EKS Services Access
#########################################################

# IAM Policy that allows the CSI driver service account to make calls to related services such as EC2 on your behalf.
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.41.0"

  create_role                   = true
  role_name                     = "AwsEKSEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

#########################################################
# GitHub Access
#########################################################

# Referencing an existing OIDC provider for GitHub Actions
data "aws_iam_openid_connect_provider" "GitHub_Actions" {
  arn = "arn:aws:iam::438465169137:oidc-provider/token.actions.githubusercontent.com"
}

# Role to provide access to EKS Cluster, Trust policy included
resource "aws_iam_role" "github_oidc_development" {
  name = "eks_github_oidc-${module.eks.cluster_name}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Principal" : {
          "Federated" : data.aws_iam_openid_connect_provider.GitHub_Actions.arn
        },
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:aud" : [
              "sts.amazonaws.com"
            ]
          },
          "StringLike" : {
            "token.actions.githubusercontent.com:sub" : "repo:sakshi12oct/devops-final-project:*"
          }
        }
      }
    ]
  })
}

# Provide edit access to the EKS Cluster
resource "aws_iam_policy" "EKS_Access" {
  name        = "EKS_policy-1"
  description = "Permission to access EKSCluster"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EKSAccess",
        "Effect" : "Allow",
        "Action" : [
          "eks:DescribeCluster"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AssumeRole",
        "Effect" : "Allow",
        "Action" : "sts:AssumeRole",
        "Resource" : "*"
      }
    ]
  })
}

# Associate EKS Access policy with the role
resource "aws_iam_role_policy_attachment" "Github_OIDC" {
  role       = aws_iam_role.github_oidc_development.name
  policy_arn = aws_iam_policy.EKS_Access.arn
}

# Access Entries to EKS Cluster associate it with AWS Role
resource "aws_eks_access_entry" "GithubActions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_oidc_development.arn
}

# Access Entries to EKS Cluster --> Kubernetes RBAC
resource "aws_eks_access_policy_association" "GitHubActions" {
  cluster_name = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
  principal_arn = aws_eks_access_entry.GithubActions.principal_arn

  access_scope {
    type       = "namespace"
    namespaces = ["development"]
  }
}
