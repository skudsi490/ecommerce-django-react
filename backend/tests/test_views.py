import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth.models import User

@pytest.mark.django_db
def test_api_create_user():
    client = APIClient()
    response = client.post(reverse('user-list'), {
        'username': 'testuser',
        'email': 'test@example.com',
        'password': 'testpassword'
    })
    assert response.status_code == 201

# Ensure that 'user-list' is defined in your URLs, e.g., in urls.py:
# from django.urls import path
# from .views import UserListView
# urlpatterns = [
#     path('api/users/', UserListView.as_view(), name='user-list'),
# ]
