import os
import json
import django
from django.core.management import call_command

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "backend.settings")  # Replace 'ecommerce' with your project name
django.setup()

with open('data_dump.json', 'w', encoding='utf-8') as f:
    call_command('dumpdata', '--natural-primary', '--natural-foreign', '--exclude=contenttypes', '--exclude=auth.Permission', stdout=f)
