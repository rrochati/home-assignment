resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda"
  version    = "2.12.1"

  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.keda_irsa.iam_role_arn
  }

  values = [
    yamlencode({
      podIdentity = {
        aws = {
          irsa = {
            enabled = true
          }
        }
      }
    })
  ]

  depends_on = [module.eks]
}