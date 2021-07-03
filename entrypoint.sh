#!/usr/bin/env bash
set -e

if [[ "$1" = "monit" ]]; then
  monit -I -v -B
else
  "$@"
fi
