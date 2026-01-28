# namespace
resource "kubernetes_namespace_v1" "openssh" {
  metadata {
    name = "openssh"
  }
}


# configmap for sshd
resource "kubernetes_config_map_v1" "openssh" {
  metadata {
    namespace = kubernetes_namespace_v1.openssh.metadata[0].name
    name      = "openssh"
  }

  data = {
    "ssh-ca.pem"      = "${vault_ssh_secret_backend_ca.ssh.public_key}"
    "sshd_certs.conf" = "${file("${path.module}/files/sshd_certs.conf")}"
  }
}


# deployment for pods with openssh
resource "kubernetes_deployment_v1" "openssh" {
  metadata {
    namespace = kubernetes_namespace_v1.openssh.metadata[0].name
    name      = "openssh"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "openssh"
      }
    }

    template {
      metadata {
        labels = {
          app = "openssh"
        }
      }

      spec {
        container {
          name  = "openssh"
          image = "linuxserver/openssh-server:10.2_p1-r0-ls213"

          env {
            name  = "USER_NAME"
            value = keycloak_user.alice.username
          }

          volume_mount {
            name       = "config"
            mount_path = "/config/sshd/sshd_config.d/sshd_certs.conf"
            sub_path   = "sshd_certs.conf"
            read_only  = true
          }

          volume_mount {
            name       = "config"
            mount_path = "/config/ssh-ca.pem"
            sub_path   = "ssh-ca.pem"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.openssh.metadata[0].name
          }
        }
      }
    }
  }
}


# NodePort service
resource "kubernetes_service_v1" "openssh" {
  metadata {
    namespace = kubernetes_namespace_v1.openssh.metadata[0].name
    name      = "openssh"
  }

  spec {
    selector = {
      app = "openssh"
    }

    type = "NodePort"

    port {
      port        = 2222
      target_port = 2222
      node_port   = 32222
    }
  }
}


# ssh key-pair
resource "tls_private_key" "alice" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "alice_rsa" {
  content  = tls_private_key.alice.private_key_openssh
  filename = "${path.module}/../alice_rsa"
}

resource "local_sensitive_file" "alice_rsa_pub" {
  content  = tls_private_key.alice.public_key_openssh
  filename = "${path.module}/../alice_rsa.pub"
}
