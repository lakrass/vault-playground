# Static vs. Dynamic Secrets Demo

## Prerequisites

Have the following tools installed:

- [kind](https://kind.sigs.k8s.io) (creates throw-away K8s clusters in containers)
- [kubectl](https://kubernetes.io/de/docs/tasks/tools/install-kubectl/) (K8s CLI)
- [helm](https://helm.sh) (K8s "package manager")
- [helmfile](https://helmfile.readthedocs.io/en/latest/) (Wrapper for advanced usage of helm)
- [vault](https://developer.hashicorp.com/vault/tutorials/get-started/install-binary) (Vault Binary including CLI)
- [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (Terraform CLI)

You will also need a container runtime for `kind`, like:

- [docker](https://www.docker.com)
- [podman](https://podman.io)

This demo is tested with Podman Desktop on MacOS, but should also run on any other OS with `docker` or `podman`. The container runtime can be run rootless.

### With `nix` and `direnv`

Alternatively, if you are using `nix`, you can just make use of the provided `flake.nix` included in this repo. It can be used with `nix-shell` to get an environment with all required prerequisites. Check out the [docs](https://nixos.wiki/wiki/Development_environment_with_nix-shell) for further information.

When using `direnv` in addition, it will detect the provided `.envrc` file in this repo. You'll need to allow the usage of the porivided env by `direnv allow`.

## Setup the environment

### Install applications

1. Run `kind create cluster --config kind-config.yaml` inside this directory to create a K8s cluster.

2. Run `helmfile init` to ensure all required helm plugins are available and the tool is ready to use.

3. Run `helmfile apply --skip-diff-on-install` inside this directory to install all required dependencies for the environment inside the cluster. Make sure the right cluster context is set.

4. Wait for all containers to become ready, except the Vault container. Check by `watch kubectl get pods -A`.

### Initialize and unseal Vault

1. Run `export VAULT_ADDR="http://localhost:8200"` to set the URL for the `vault` CLI.

2. Run `vault operator init -n 1 -t 1 -format=json > keys.json` to initalize Vault.
   **IMPORTANT: Save the output for later use!**

3. Run `vault operator unseal` and you will be prompted for a unseal key, which you can find in the saved output of the previous command.

4. Run `vault login` and you will be prompted fo a token. Use the root token provided in the saved output.

### Configure Vault

Run all following commands inside the directory `config`.

1. Run `terraform init`.

2. Run `terraform apply -auto-approve`.

Check out https://localhost:8200 and login with the root token from the previous steps, if you want to inspect the configuration from the Vault UI.

## Check the Demos

TBC
