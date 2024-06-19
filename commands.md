Run the Services:

To start your services, use the following command:

docker-compose up -d

To run the end-to-end tests, use the following command:

docker-compose -f docker-compose.e2e.yml up --abort-on-container-exit


ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@54.93.212.177

ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@18.197.60.165
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@18.199.94.168
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@18.184.52.5

check if docker and docker compose installed :
docker ps
docker-compose --version

Having logs for the SSH :
ssh -vvv -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.70.222.92

ping 3.70.222.92

Check Resources:
terraform state list

check status of Jenkins :
sudo systemctl status jenkins

Restart Jenkins :
sudo systemctl restart jenkins


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
deactivate

python manage.py runserver   
npm start


git add Jenkinsfile
git commit -m "Update Jenkinsfile v47"
git push origin main


docker build -t skudsi/ecommerce-django-react-frontend:latest -f frontend/Dockerfile .
docker tag skudsi/ecommerce-django-react-frontend:latest index.docker.io/skudsi/ecommerce-django-react-frontend:latest
docker push index.docker.io/skudsi/ecommerce-django-react-frontend:latest

docker build -t skudsi/ecommerce-django-react-backend:latest -f backend/Dockerfile .
docker tag skudsi/ecommerce-django-react-backend:latest index.docker.io/skudsi/ecommerce-django-react-backend:latest
docker push skudsi/ecommerce-django-react-backend:latest


git add .
git commit -m "Update Dockerfiles and requirements 03"
git push origin main



Update Jenkins Configuration
Ensure the Jenkins master is correctly configured to recognize and use the new agent:

Go to Manage Jenkins > Manage Nodes and Clouds:

Add a new node (e.g., docker-agent).
Configure the New Node:

Provide necessary details like the node name, remote root directory, number of executors, and labels (docker).
Launch Method:

Choose the appropriate launch method (e.g., Launch agent via SSH or Launch agent via Java Web Start).


Adding SSH Credentials to Jenkins
Open Jenkins:

Go to your Jenkins instance URL: http://18.195.72.28:8080.
Open Credentials Configuration:

Click on Manage Jenkins from the left-hand side menu.
Select Manage Credentials.
Select Domain:

If you have not set up a specific domain for your credentials, select (global).
Add New Credentials:

Click on Add Credentials (usually on the left-hand side).
In the Kind dropdown, select SSH Username with private key.
Configure SSH Credentials:

Scope: Choose Global to make the credentials available to all jobs.
ID: (Optional) Provide an ID for the credentials for easier reference, e.g., tesi-aws.
Description: Provide a description for the credentials (e.g., SSH key for Jenkins agent).
Username: Enter the SSH username, which is usually ubuntu for AWS EC2 instances.
Private Key: Select Enter directly and paste the contents of your .pem file into the provided text box:
plaintext


Click OK to save the credentials.
Configuring Jenkins Agent
Open Jenkins Nodes Configuration:

Go to Manage Jenkins.
Select Manage Nodes and Clouds.
Click on New Node.
Configure New Node:

Node Name: Enter a name for your agent, e.g., docker-agent.
Type: Select Permanent Agent.
Click OK.
Configure Node Details:

Remote root directory: Enter the directory where Jenkins will store files on the agent, e.g., /home/ubuntu/jenkins.
Labels: Add docker to label the agent (if needed).
Usage: Use this node as much as possible.
Launch method: Select Launch agents via SSH.
Host: Enter the public IP or DNS of the agent, e.g., your-agent-public-ip.
Credentials: Select the SSH credentials you added earlier.
Host Key Verification Strategy: Choose Manually trusted key verification or any other appropriate strategy.
Save and Launch:

Click Save.
Jenkins will attempt to connect to the agent using the provided SSH credentials.


sudo systemctl daemon-reload
sudo systemctl restart jenkins
