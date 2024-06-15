# E:\DevOps\ecommerce-django-react\backend\Dockerfile

# Use the official Python image from the Docker Hub
FROM python:3.9-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory
WORKDIR /app

# Install dependencies
COPY ../requirements.txt /app/
RUN pip install -r requirements.txt

# Copy the rest of the application code
COPY ./backend /app/backend
COPY ./base /app/base
COPY ./manage.py /app/manage.py
COPY ./backend/__init__.py /app/backend/__init__.py
COPY ./backend/settings.py /app/backend/settings.py
COPY ./backend/wsgi.py /app/backend/wsgi.py
COPY ./backend/urls.py /app/backend/urls.py
COPY ./static /app/static  
COPY ./pytest.ini /app/pytest.ini

# Ensure the backend and base modules are within the Python path
ENV PYTHONPATH /app:/app/backend:/app/base

# Set environment variable for Django settings module
ENV DJANGO_SETTINGS_MODULE=backend.settings

# Set the working directory to the backend directory
WORKDIR /app/backend

# Debug steps to verify paths and settings
RUN ls -la /app/backend
RUN echo $DJANGO_SETTINGS_MODULE
RUN python -c "import os; print(os.environ['DJANGO_SETTINGS_MODULE'])"
RUN python -c "import backend.settings"

# Create the staticfiles directory if it doesn't exist
RUN mkdir -p /app/staticfiles

# Collect static files
RUN python /app/manage.py collectstatic --noinput

# Run the Django application
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "backend.wsgi:application"]
