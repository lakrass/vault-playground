terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.6.0"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
  }
}

provider "vault" {
  address            = "http://localhost:8200"
  token              = "root"
  add_address_to_env = true
}

provider "keycloak" {
  url       = "http://localhost:8080"
  realm     = "master"
  client_id = "admin-cli"
  username  = "admin"
  password  = "admin"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "tls" {
}

provider "local" {

}
