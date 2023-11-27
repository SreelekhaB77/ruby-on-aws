#!/bin/bash
set -e

# Check for a server.pid file and remove it if it exists
# This file sometimes causes issues when starting the container
if [ -f tmp/pids/server.pid ]; then
  echo "Removing server.pid"
  rm tmp/pids/server.pid
fi

# Run database migrations
echo "Running database migrations..."
bundle exec rails db:migrate

# Then exec the container's main process (what's set as CMD in the Dockerfile)
exec "$@"
