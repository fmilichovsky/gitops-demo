#!/usr/bin/env bash

# Adapted from https://github.com/fluxcd/flux2-kustomize-helm-example/blob/main/scripts/validate.sh

# Prerequisites
# - kustomize

set -o errexit

function validate_overlays {
  # Mirror kustomize-controller build options.
  kustomize_flags=("--load-restrictor=LoadRestrictionsNone")
  # Filter top-level overlays to reduce duplicated generation.
  overlays_pattern="*/overlays/*"
  kustomize_config="kustomization.yaml"

  echo "> INFO - Validating kustomize overlays"
  find . -type f -path "$overlays_pattern/$kustomize_config" -print0 | while IFS= read -r -d $'\0' file;
    do
      echo "  > Validating kustomization ${file/%$kustomize_config}"
      kustomize build "${file/%$kustomize_config}" "${kustomize_flags[@]}" > /dev/null
      if [[ ${PIPESTATUS[0]} != 0 ]]; then
        exit 1
      fi
  done
}

validate_overlays
