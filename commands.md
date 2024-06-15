Run the Services:

To start your services, use the following command:

docker-compose up -d

To run the end-to-end tests, use the following command:

docker-compose -f docker-compose.e2e.yml up --abort-on-container-exit


ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@35.157.114.78

Having logs for the SSH :
ssh -vvv -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.70.222.92

ping 3.70.222.92

Check Resources:
terraform state list

check status of Jenkins :
sudo systemctl status jenkins

Get the Jinkins Admin Password:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

Check status of Docker :
sudo systemctl status docker


Check status of SSH:
sudo systemctl status sshd

 reboot your system:
sudo reboot

Doing Apply without writing "yes":
terraform apply -auto-approve

Destroying one instance only :
terraform destroy -target="aws_instance.jenkins" -auto-approve


.\env\Scripts\activate  


python manage.py runserver   
npm start


git add Jenkinsfile
git commit -m "Update Jenkinsfile"
git push origin main
