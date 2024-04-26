resource "kubernetes_service_account_v1" "counting_service_account" {
  metadata {
    name      = "counting"
    namespace = "default"
  }
  automount_service_account_token = true
}

resource "kubernetes_service_v1" "counting_service" {
  metadata {
    name      = "counting"
    namespace = "default"
    labels = {
      app = "counting"
    }
  }
  spec {
    selector = {
      app = "counting"
    }
    port {
      port        = 9001
      target_port = 9001
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "counting_deployment" {
  metadata {
    name = "counting"
    labels = {
      app = "counting"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "counting"
      }
    }

    template {
      metadata {
        annotations = {
          "consul.hashicorp.com/connect-inject" = true
        }
        labels = {
          app = "counting"
        }
      }

      spec {
        service_account_name = "counting"
        container {
          image             = "hashicorp/counting-service:0.0.2"
          name              = "counting"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 9001
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}
