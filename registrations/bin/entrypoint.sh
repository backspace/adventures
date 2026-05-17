#!/bin/sh
set -e

echo "Running migrations..."
/app/bin/registrations eval "Registrations.Release.migrate()"

echo "Starting server..."
exec /app/bin/registrations start
