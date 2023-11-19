#!/bin/bash

# Adapted from https://github.com/fluxcd/flux2-kustomize-helm-example/blob/main/scripts/validate.sh

# Prerequisites
# - kustomize

set -o errexit

function render_overlays {
  suppress_output="$1"
  # Mirror kustomize-controller build options.
  kustomize_flags=("--load-restrictor=LoadRestrictionsNone")
  # Filter top-level overlays to reduce duplicated generation.
  overlays_pattern="*/overlays/*"
  kustomize_config="kustomization.yaml"

  find . -type f -path "$overlays_pattern/$kustomize_config" -print0 | while IFS= read -r -d $'\0' file;
    do
      directory="${file/%$kustomize_config}"
      output="${directory}/.render.yaml"
      if [ ! -z "$suppress_output" ]; then
        output=/dev/null
      fi
      echo "  > ${directory}"
      kustomize build "${directory}" "${kustomize_flags[@]}" > "${output}"
      if [[ ${PIPESTATUS[0]} != 0 ]]; then
        exit 1
      fi
  done
}

function validate_overlays {
  echo "> INFO - Validating kustomize overlays"
  render_overlays supress
}

validate_overlays
