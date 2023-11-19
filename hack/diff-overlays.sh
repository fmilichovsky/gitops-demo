#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <overlay-1> <overlay-2>"
    exit 1
fi

first_overlay="$1"
second_overlay="$2"

temp_file_first=$(mktemp)
temp_file_second=$(mktemp)

# Fail on any kustomization build failures.
set -e
kustomize build "$first_overlay" > "$temp_file_first"
kustomize build "$second_overlay" > "$temp_file_second"
set +e

diff --unified "$temp_file_first" "$temp_file_second"

rm -f "$temp_file_first" "$temp_file_second"
