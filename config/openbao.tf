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
  bound_claims = {
    email_verified = "true"
  }

  user_claim   = "sub"
  groups_claim = keycloak_openid_client_scope.groups.name

  claim_mappings = {
    email = "email"
  }

  allowed_redirect_uris = keycloak_openid_client.openbao.valid_redirect_uris
  verbose_oidc_logging  = true
}
