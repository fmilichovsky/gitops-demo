#!/bin/bash

# Adapted from https://github.com/fluxcd/flux2-kustomize-helm-example/blob/main/scripts/validate.sh

# Prerequisites
# - kustomize

set -o errexit

function kustomize_build {
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
  kustomize_build supress
}

function render_overlays {
  echo "> INFO - Rendering kustomize overlays"
  kustomize_build
}

# Parse command-line options.
while getopts ":r" opt; do
  case $opt in
    r)
      render=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Default behavior is to validate overlays.
if [ "$render" = true ]; then
  render_overlays
else
  validate_overlays
fi
