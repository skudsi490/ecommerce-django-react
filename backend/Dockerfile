FROM python:3.9-slim


ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1


WORKDIR /app


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
COPY ./pytest.ini /app/pytest.ini


ENV PYTHONPATH /app:/app/backend:/app/base


ENV DJANGO_SETTINGS_MODULE=backend.settings


WORKDIR /app


RUN ls -la /app/backend
RUN echo $DJANGO_SETTINGS_MODULE
RUN python -c "import os; print(os.environ['DJANGO_SETTINGS_MODULE'])"
RUN python -c "import backend.settings"


RUN mkdir -p /app/staticfiles


RUN python manage.py collectstatic --noinput


CMD ["gunicorn", "--bind", "0.0.0.0:8000", "backend.wsgi:application"]
