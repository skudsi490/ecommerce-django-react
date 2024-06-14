import pytest
from django.contrib.auth.models import User

@pytest.mark.django_db
def test_user_create():
    user = User.objects.create_user('testuser', 'test@example.com', 'testpassword')
    assert user.username == 'testuser'
