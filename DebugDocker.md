docker-compose logs web
docker-compose exec web python manage.py collectstatic --noinput
ls -la /home/ubuntu/ecommerce-django-react/staticfiles/
ls -la /home/ubuntu/ecommerce-django-react/media/images/
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.76.217.10


cd /home/ubuntu/ecommerce-django-react

sudo nano /etc/nginx/sites-available/ecommerce-django-react
sudo vim /etc/nginx/sites-available/ecommerce-django-react
