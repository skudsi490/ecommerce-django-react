# E:\DevOps\ecommerce-django-react\backend\Dockerfile

FROM python:3.9-slim

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

# Adjust the COPY paths based on the Jenkins build context
COPY ../requirements.txt /app/
RUN pip install -r requirements.txt

COPY ./backend /app/backend
COPY ./base /app/base
COPY ./manage.py /app/manage.py
COPY ./backend/__init__.py /app/backend/__init__.py
COPY ./backend/settings.py /app/backend/settings.py
COPY ./backend/wsgi.py /app/backend/wsgi.py
COPY ./backend/urls.py /app/backend/urls.py
COPY ./static /app/static
COPY ./media /app/media
COPY ./pytest.ini /app/pytest.ini
COPY ./backend/entrypoint.sh /app/entrypoint.sh
COPY ./base/migrations /app/base/migrations

# Copy the frontend build files
COPY ./frontend/build /app/frontend/build

RUN apt-get update && apt-get install -y netcat-openbsd procps curl net-tools

RUN chmod +x /app/entrypoint.sh

WORKDIR /app

RUN mkdir -p /app/staticfiles /var/log/gunicorn
RUN chmod -R 755 /var/log/gunicorn

ENTRYPOINT ["sh", "/app/entrypoint.sh"]
