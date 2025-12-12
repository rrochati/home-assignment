resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda"

  create_namespace = true

  set {
	name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
	value = module.keda_irsa.iam_role_arn
  }

  set {
    name  = "irsa.enabled"
    value = "true"
  }

  set {
    name  = "irsa.roleArn"
    value = module.keda_irsa.iam_role_arn
  }

  values = [
	yamlencode({
	  serviceAccount = {
	    operator = {
	      annotations = {
	        "eks.amazonaws.com/role-arn" = module.keda_irsa.iam_role_arn
	      }
	    }
	  }
	  podIdentity = {
	    aws = {
	      irsa = {
	        enabled = true
	      }
	    }
	  }
	})
  ]

  # Wait for cluster and IRSA to be ready
  depends_on = [
	module.eks,
	module.keda_irsa
  ]

  # Add timeout to handle slow cluster startup
  timeout = 300
}