resource "kubernetes_manifest" "service_intentions" {
  depends_on = [helm_release.hashicorp]
  #   manifest = yamldecode(file("intentions.yaml"))
  manifest = {
    apiVersion = "consul.hashicorp.com/v1alpha1"
    kind       = "ServiceIntentions"
    metadata = {
      name      = "dashboard-to-counting"
      namespace = "default"
    }
    spec = {
      destination = {
        name = "counting"
      }
      sources = [{
        name   = "dashboard"
        action = "allow"
      }]
    }
  }
}
