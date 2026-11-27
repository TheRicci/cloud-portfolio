#!/usr/bin/env bash
# Lists anything this project may have left in the cloud. Exits 1 if anything remains.
# Usage: audit-leftovers.sh aws|azure   (REGION must be set for aws)
set -uo pipefail
CLOUD="${1:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

leftovers=0
report() {
  if [[ -n "${2//[[:space:]]/}" ]]; then
    log "LEFTOVER $1: $2"
    leftovers=1
  fi
}

case "$CLOUD" in
  aws)
    : "${REGION:?set REGION}"
    f="Name=tag:project,Values=hardening-lab"
    report instances "$(aws ec2 describe-instances --region "$REGION" --filters "$f" \
      Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].InstanceId' --output text)"
    report volumes "$(aws ec2 describe-volumes --region "$REGION" --filters "$f" \
      --query 'Volumes[].VolumeId' --output text)"
    report addresses "$(aws ec2 describe-addresses --region "$REGION" --filters "$f" \
      --query 'Addresses[].PublicIp' --output text)"
    report key-pairs "$(aws ec2 describe-key-pairs --region "$REGION" --filters "$f" \
      --query 'KeyPairs[].KeyName' --output text)"
    report security-groups "$(aws ec2 describe-security-groups --region "$REGION" --filters "$f" \
      --query 'SecurityGroups[].GroupId' --output text)"
    report internet-gateways "$(aws ec2 describe-internet-gateways --region "$REGION" --filters "$f" \
      --query 'InternetGateways[].InternetGatewayId' --output text)"
    report vpcs "$(aws ec2 describe-vpcs --region "$REGION" --filters "$f" \
      --query 'Vpcs[].VpcId' --output text)"
    ;;
  azure)
    if [[ "$(az group exists --name rg-hardening-lab)" == "true" ]]; then
      report resource-group "rg-hardening-lab"
    fi
    report tagged-resources "$(az resource list --tag project=hardening-lab --query '[].id' -o tsv)"
    ;;
  *)
    die "usage: $0 aws|azure"
    ;;
esac

if (( leftovers )); then
  log "AUDIT FAILED: the resources above keep costing money until deleted."
  exit 1
fi
log "Audit clean: nothing tagged project=hardening-lab remains."
