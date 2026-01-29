# oidc auth
resource "vault_jwt_auth_backend" "oidc" {
  depends_on = [keycloak_openid_client.openbao]
  type       = "oidc"
  path       = "oidc"

  oidc_client_id     = keycloak_openid_client.openbao.client_id
  oidc_client_secret = keycloak_openid_client.openbao.client_secret
  oidc_discovery_url = "http://localhost:8080/realms/demo"
  bound_issuer       = "http://localhost:8080/realms/demo"

  default_role = "default"

  tune {
    listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "default" {
  backend = vault_jwt_auth_backend.oidc.path

  role_name      = "default"
  token_policies = ["default"]

  bound_audiences = [keycloak_openid_client.openbao.client_id]

  user_claim   = "sub"
  groups_claim = keycloak_openid_client_scope.groups.name

  claim_mappings = {
    email              = "email"
    preferred_username = "ssh-user"
  }

  allowed_redirect_uris = keycloak_openid_client.openbao.valid_redirect_uris
  verbose_oidc_logging  = true
}


# db secrets engine
resource "vault_mount" "db" {
  type = "database"
  path = "database"
}

resource "vault_database_secret_backend_role" "pg_user" {
  backend = vault_mount.db.path
  name    = "pg-user"
  db_name = "postgres"
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT pg_read_all_data TO \"{{name}}\";",
    "GRANT pg_write_all_data TO \"{{name}}\";"
  ]
}

resource "vault_database_secret_backend_role" "pg_admin" {
  backend = vault_mount.db.path
  name    = "pg-admin"
  db_name = "postgres"
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL ON SCHEMA public TO \"{{name}}\";"
  ]
}

resource "vault_database_secret_backend_connection" "pg" {
  backend = vault_mount.db.path
  name    = "postgres"

  postgresql {
    username       = "postgres"
    password       = "postgres"
    connection_url = "postgres://{{username}}:{{password}}@postgres.postgres.svc.cluster.local:5432/postgres"
  }

  verify_connection = true
  allowed_roles = [
    vault_database_secret_backend_role.pg_user.name,
    vault_database_secret_backend_role.pg_admin.name
  ]
}

resource "vault_policy" "pg_admin" {
  name   = "pg-admin"
  policy = <<-EOT
    path "${vault_mount.db.path}/creds/${vault_database_secret_backend_role.pg_admin.name}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "pg_user" {
  name   = "pg-user"
  policy = <<-EOT
    path "${vault_mount.db.path}/creds/${vault_database_secret_backend_role.pg_user.name}" {
      capabilities = ["read"]
    }
  EOT
}


# ssh secrets engine
resource "vault_mount" "ssh" {
  path = "ssh"
  type = "ssh"
}

resource "vault_ssh_secret_backend_ca" "ssh" {
  backend              = vault_mount.ssh.path
  generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "default" {
  backend = vault_mount.ssh.path
  name    = "default"

  key_type                = "ca"
  allow_user_certificates = true

  default_user_template = true
  default_user          = "{{ identity.entity.aliases.${vault_jwt_auth_backend.oidc.accessor}.metadata.ssh-user }}"

  allowed_users_template = true
  allowed_users          = "{{ identity.entity.aliases.${vault_jwt_auth_backend.oidc.accessor}.metadata.ssh-user }}"

  allowed_extensions = "permit-pty,permit-user-rc"
  default_extensions = {
    "permit-pty"     = ""
    "permit-user-rc" = ""
  }
}

resource "vault_policy" "ssh_user" {
  name   = "ssh-user"
  policy = <<-EOT
    path "${vault_mount.ssh.path}/sign/${vault_ssh_secret_backend_role.default.name}" {
      capabilities = ["create","update"]
    }
  EOT
}
