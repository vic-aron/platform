#!/usr/bin/env bash
set -euo pipefail

FLUX_SSH_KEY="$HOME/.ssh/id_ed25519_flux"
FLUX_KNOWN_HOSTS="$HOME/.ssh/known_hosts"
SOPS_AGE_KEY="$HOME/.config/sops/age/mgmt.txt"

# Prerequisites
for file in "$FLUX_SSH_KEY" "$FLUX_KNOWN_HOSTS" "$SOPS_AGE_KEY"; do
  [[ -r "$file" ]] || {
    printf 'Missing or unreadable file: %s\n' "$file" >&2
    exit 1
  }
done

# CNI
helm upgrade --install kube-ovn \
  "oci://ghcr.io/kubeovn/charts/kube-ovn-v2" \
  --version "v1.16.17" \
  --namespace "kube-system" \
  --create-namespace \
  --set ovsOvn.disableModulesManagement=true \
  --set ovsOvn.ovsDirectory="/var/lib/openvswitch" \
  --set ovsOvn.ovnDirectory="/var/lib/ovn" \
  --set ovsOvn.ovsIpsecKeysDirectory="/var/lib/ovs_ipsec_keys" \
  --set cni.mountToolingDirectory=false \
  --wait

# Flux Operator
helm upgrade --install flux-operator \
    "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator" \
  --version "0.62.1" \
  --namespace "flux-system" \
  --create-namespace \
  --wait

# Flux SSH
kubectl create secret generic flux-git-auth \
  --namespace "flux-system" \
  --from-file=identity="$FLUX_SSH_KEY" \
  --from-file=known_hosts="$FLUX_KNOWN_HOSTS" \
  --dry-run=client -o yaml |
  kubectl apply -f -

# Flux Age
kubectl create secret generic sops-age \
  --namespace "flux-system" \
  --from-file=age.agekey="$SOPS_AGE_KEY" \
  --dry-run=client -o yaml |
  kubectl apply -f -

kubectl apply -f "flux-instance.yaml"
