Run the Services:

To start your services, use the following command:

docker-compose up -d

To run the end-to-end tests, use the following command:

docker-compose -f docker-compose.e2e.yml up --abort-on-container-exit


ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.70.222.92

Having logs for the SSH :
ssh -vvv -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.70.222.92

ping 3.70.222.92

Check Resources:
terraform state list

check status of Jenkins :
sudo systemctl status jenkins

Check status of SSH:
sudo systemctl status sshd
