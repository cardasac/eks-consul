resource "helm_release" "hashicorp" {
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  namespace  = kubernetes_namespace_v1.consul.id
  values = [
    "${file("values.yaml")}"
  ]
}

resource "kubernetes_namespace_v1" "consul" {
  metadata {
    annotations = {
      name = "consul"
    }

    name = "consul"
  }
}