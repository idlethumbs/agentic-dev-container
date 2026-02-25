#!/bin/bash
# Start Cloud SQL Proxy if REPO_BACKEND=sql

if [ "$REPO_BACKEND" = "sql" ] && [ -n "$INSTANCE_CONNECTION_NAME" ]; then
  # Check if already running
  if ! pgrep -f "cloud-sql-proxy" > /dev/null; then
    echo "Starting Cloud SQL Proxy for $INSTANCE_CONNECTION_NAME..."
    nohup cloud-sql-proxy "$INSTANCE_CONNECTION_NAME" --port 5432 > /tmp/cloud-sql-proxy.log 2>&1 &
    sleep 2
    if pgrep -f "cloud-sql-proxy" > /dev/null; then
      echo "Cloud SQL Proxy started successfully"
    else
      echo "Failed to start Cloud SQL Proxy. Check /tmp/cloud-sql-proxy.log"
    fi
  else
    echo "Cloud SQL Proxy already running"
  fi
else
  echo "REPO_BACKEND=$REPO_BACKEND - Cloud SQL Proxy not needed"
fi
