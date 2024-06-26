#!/bin/sh

echo "Starting entrypoint script..."

# Wait for PostgreSQL to be ready
while ! nc -z $POSTGRES_HOST 5432; do
  echo "Waiting for PostgreSQL..."
  sleep 1
done

echo "Applying database migrations..."
# Apply database migrations
python manage.py makemigrations
python manage.py migrate

echo "Checking for data_dump.json..."
# Load data into PostgreSQL
if [ -f /tmp/data_dump.json ]; then
  echo "Loading data into PostgreSQL"
  python manage.py loaddata /tmp/data_dump.json
else
  echo "data_dump.json not found."
fi

echo "Setting permissions for staticfiles directory..."
# Ensure permissions for staticfiles directory
mkdir -p /app/staticfiles
chmod -R 755 /app/staticfiles

echo "Collecting static files..."
# Collect static files
python manage.py collectstatic --noinput
if [ $? -ne 0 ]; then
  echo "Failed to collect static files"
  exit 1
fi

echo "Creating log directory for Gunicorn if it doesn't exist..."
# Create log directory for Gunicorn if it doesn't exist
mkdir -p /var/log/gunicorn
chmod -R 755 /var/log/gunicorn

# Force DEBUG=0 to ensure Gunicorn is used
export DEBUG=0

# Start the appropriate server based on the DEBUG environment variable
if [ "$DEBUG" = "1" ]; then
  echo "Starting Django development server"
  python manage.py runserver 0.0.0.0:8000
else
  echo "Starting Gunicorn server"
  gunicorn backend.wsgi:application --bind 0.0.0.0:8000 --log-level debug --access-logfile /var/log/gunicorn/access.log --error-logfile /var/log/gunicorn/error.log --workers 3 --worker-class gthread --threads 4 --reload
fi
