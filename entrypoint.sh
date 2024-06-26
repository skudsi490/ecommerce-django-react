#!/bin/sh

# Wait for PostgreSQL to be ready
while ! nc -z $POSTGRES_HOST 5432; do
  echo "Waiting for PostgreSQL..."
  sleep 1
done

# Apply database migrations
python manage.py migrate

# Load data into PostgreSQL
if [ -f /tmp/data_dump.json ]; then
  echo "Loading data into PostgreSQL"
  python manage.py loaddata /tmp/data_dump.json
fi

# Collect static files
python manage.py collectstatic --noinput

# Create log directory for Gunicorn if it doesn't exist
mkdir -p /var/log/gunicorn
chmod -R 755 /var/log/gunicorn

# Start the appropriate server based on the DEBUG environment variable
if [ "$DEBUG" = "1" ]; then
  echo "Starting Django development server"
  python manage.py runserver 0.0.0.0:8000
else
  echo "Starting Gunicorn server"
  gunicorn backend.wsgi:application --bind 0.0.0.0:8000 --log-level debug --access-logfile /var/log/gunicorn/access.log --error-logfile /var/log/gunicorn/error.log
fi
