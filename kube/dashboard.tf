resource "kubernetes_service_account_v1" "dashboard_service_account" {
  metadata {
    name      = "dashboard"
    namespace = "default"
  }
  automount_service_account_token = true
}

resource "kubernetes_service_v1" "dashboard_service" {
  metadata {
    name      = "dashboard"
    namespace = "default"
    labels = {
      app = "dashboard"
    }
  }
  spec {
    selector = {
      app = "dashboard"
    }
    port {
      port        = 9002
      target_port = 9002
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "dashboard_deployment" {
  metadata {
    name = "dashboard"
    labels = {
      app = "dashboard"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "dashboard"
      }
    }

    template {
      metadata {
        annotations = {
          "consul.hashicorp.com/connect-inject"            = true
          "consul.hashicorp.com/connect-service-upstreams" = "counting:9001"
        }
        labels = {
          app = "dashboard"
        }
      }

      spec {
        service_account_name = "dashboard"
        container {
          image             = "hashicorp/dashboard-service:0.0.4"
          name              = "dashboard"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 9002
          }
          env {
            name  = "COUNTING_SERVICE_URL"
            value = "http://localhost:9001"
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

          liveness_probe {
            http_get {
              path = "/"
              port = 9002
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}
