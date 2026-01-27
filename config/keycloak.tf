# realm
resource "keycloak_realm" "demo" {
  realm   = "demo"
  enabled = true
}


# group "team-a"
resource "keycloak_group" "team_a" {
  realm_id = keycloak_realm.demo.id
  name     = "team-a"
}


# group "team-b"
resource "keycloak_group" "team_b" {
  realm_id = keycloak_realm.demo.id
  name     = "team-b"
}


# user "alice" with group "team-a"
resource "keycloak_user" "alice" {
  realm_id = keycloak_realm.demo.id

  username = "alice"
  enabled  = true

  first_name     = "Alice"
  last_name      = "Example"
  email          = "alice@example.dev"
  email_verified = true

  initial_password {
    value = "alice"
  }
}

resource "keycloak_user_groups" "alice" {
  realm_id  = keycloak_realm.demo.id
  user_id   = keycloak_user.alice.id
  group_ids = [keycloak_group.team_a.id]
}


# user "bob" with group "team-b"
resource "keycloak_user" "bob" {
  realm_id = keycloak_realm.demo.id

  username = "bob"
  enabled  = true

  first_name     = "Bob"
  last_name      = "Example"
  email          = "bob@example.dev"
  email_verified = true

  initial_password {
    value = "bob"
  }
}

resource "keycloak_user_groups" "bob" {
  realm_id  = keycloak_realm.demo.id
  user_id   = keycloak_user.bob.id
  group_ids = [keycloak_group.team_b.id]
}


# scope "groups" with Keycloak groups as content
resource "keycloak_openid_client_scope" "groups" {
  realm_id    = keycloak_realm.demo.id
  name        = "groups"
  description = "List of assigned Keycloak groups"
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups_mapper" {
  realm_id        = keycloak_realm.demo.id
  client_scope_id = keycloak_openid_client_scope.groups.id

  name       = "groups"
  claim_name = "groups"

  full_path           = true
  add_to_access_token = true
  add_to_id_token     = false
}


# openid client for OpenBao with custom scopes assigned
resource "keycloak_openid_client" "openbao" {
  realm_id = keycloak_realm.demo.id

  client_id = "openbao"
  enabled   = true

  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true

  root_url = "http://localhost:8200"
  base_url = "http://localhost:8200"
  valid_redirect_uris = [
    "http://localhost:8200/ui/vault/auth/oidc/oidc/callback",
    "http://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
    "http://127.0.0.1:8250/oidc/callback"
  ]
  web_origins = [
    "http://localhost:8200",
    "http://127.0.0.1:8200"
  ]
  admin_url = "http://localhost:8200/ui/vault/auth/oidc/oidc/callback"
}

resource "keycloak_openid_client_default_scopes" "openbao_scope_default" {
  realm_id  = keycloak_realm.demo.id
  client_id = keycloak_openid_client.openbao.id

  default_scopes = [
    keycloak_openid_client_scope.groups.name,
    "email",
    "profile"
  ]
}


