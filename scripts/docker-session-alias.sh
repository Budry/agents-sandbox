#!/usr/bin/env bash

docker() {
  if [ "${1:-}" = "push" ]; then
    shift
    command docker-push-session.sh "$@"
    return $?
  fi
  if [ "${1:-}" = "pull" ]; then
    shift
    command docker-pull-session.sh "$@"
    return $?
  fi
  command docker "$@"
}
