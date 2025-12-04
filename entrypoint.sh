#!/bin/sh
# entrypoint.sh

# Run migrations
echo "Running migrations..."
python manage.py migrate --noinput

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput --clear

# Execute passed CMD (Gunicorn)
echo "Starting server..."
exec "$@"
