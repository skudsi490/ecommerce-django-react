docker-compose logs web
docker-compose exec web python manage.py collectstatic --noinput
ls -la /home/ubuntu/ecommerce-django-react/staticfiles/
ls -la /home/ubuntu/ecommerce-django-react/media/images/
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.76.217.10


cd /home/ubuntu/ecommerce-django-react

sudo nano /etc/nginx/sites-available/ecommerce-django-react
sudo vim /etc/nginx/sites-available/ecommerce-django-react


     stage('Verify libcrypt.so.1') {
            steps {
                sh '''
                echo "Verifying libcrypt.so.1..."
                if [ ! -f /usr/lib64/libcrypt.so.1 ]; then
                  echo "libcrypt.so.1 not found, installing libxcrypt-compat..."
                  sudo yum install -y libxcrypt-compat
                else
                  echo "libcrypt.so.1 found."
                fi
                '''
            }
        }