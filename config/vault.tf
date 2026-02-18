# oidc auth
resource "vault_jwt_auth_backend" "oidc" {
  depends_on = [keycloak_openid_client.vault]
  type       = "oidc"
  path       = "oidc"

  oidc_client_id     = keycloak_openid_client.vault.client_id
  oidc_client_secret = keycloak_openid_client.vault.client_secret
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

  bound_audiences = [keycloak_openid_client.vault.client_id]

  user_claim   = "sub"
  groups_claim = keycloak_openid_client_scope.groups.name

  claim_mappings = {
    email              = "email"
    preferred_username = "ssh-user"
  }

  allowed_redirect_uris = keycloak_openid_client.vault.valid_redirect_uris
  verbose_oidc_logging  = true
}


# db secrets engine
resource "vault_mount" "db" {
  type = "database"
  path = "database"

  default_lease_ttl_seconds = 300
  max_lease_ttl_seconds     = 900
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

data "kubernetes_secret_v1" "pg_superuser" {
  metadata {
    namespace = "postgres"
    name = "postgres-cluster-superuser" 
  }
}

resource "vault_database_secret_backend_connection" "pg" {
  depends_on = [ data.kubernetes_secret_v1.pg_superuser ]

  backend = vault_mount.db.path
  name    = "postgres"

  postgresql {
    username       = data.kubernetes_secret_v1.pg_superuser.data.username
    password       = data.kubernetes_secret_v1.pg_superuser.data.password
    connection_url = "postgres://{{username}}:{{password}}@${data.kubernetes_secret_v1.pg_superuser.data.host}.postgres.svc.cluster.local:${data.kubernetes_secret_v1.pg_superuser.data.port}/postgres"
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
    path "database/roles/${vault_database_secret_backend_role.pg_admin.name}" { 
      capabilities = ["list"]
    }

    path "${vault_mount.db.path}/creds/${vault_database_secret_backend_role.pg_admin.name}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "pg_user" {
  name   = "pg-user"
  policy = <<-EOT
    path "${vault_mount.db.path}/roles/${vault_database_secret_backend_role.pg_user.name}" { 
      capabilities = ["list"]
    }

    path "${vault_mount.db.path}/creds/${vault_database_secret_backend_role.pg_user.name}" {
      capabilities = ["read"]
    }
  EOT
}


# ssh secrets engine
resource "vault_mount" "ssh" {
  path = "ssh"
  type = "ssh"

  default_lease_ttl_seconds = 300
  max_lease_ttl_seconds     = 900
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
    path "${vault_mount.ssh.path}/roles" { 
      capabilities = ["list"]
    }

    path "${vault_mount.ssh.path}/sign/${vault_ssh_secret_backend_role.default.name}" {
      capabilities = ["create", "update"]
    }
  EOT
}


# kv secrets engine
resource "vault_mount" "static" {
  path = "static"
  type = "kv"
}

resource "vault_kv_secret" "db_creds" {
  path = "${vault_mount.static.path}/db-creds"
  data_json = jsonencode(
    {
      user     = "postgres"
      password = "postgres"
    }
  )
}

resource "vault_kv_secret" "ssh_creds" {
  path = "${vault_mount.static.path}/ssh-creds"
  data_json = jsonencode(
    {
      user     = "${keycloak_user.alice.username}"
      password = "${keycloak_user.alice.initial_password[0].value}"
    }
  )
}

resource "vault_policy" "static_secrets" {
  name   = "static-secrets"
  policy = <<-EOT
    path "${vault_mount.static.path}/*" {
      capabilities = ["read", "list"]
    }
  EOT
}


# external groups with alias
resource "vault_identity_group" "team_a" {
  name = keycloak_group.team_a.name
  type = "external"
  policies = [
    vault_policy.pg_admin.name,
    vault_policy.ssh_user.name,
    vault_policy.static_secrets.name
  ]
}

resource "vault_identity_group_alias" "team_a_oidc" {
  name           = keycloak_group.team_a.name
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.team_a.id
}

resource "vault_identity_group" "team_b" {
  name = keycloak_group.team_b.name
  type = "external"
  policies = [
    vault_policy.pg_user.name,
    vault_policy.static_secrets.name
  ]
}

resource "vault_identity_group_alias" "team_b_oidc" {
  name           = keycloak_group.team_b.name
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.team_b.id
}


# audit device
resource "vault_audit" "test" {
  type = "file"

  options = {
    file_path = "/vault/logs/audit.log"
  }
}
