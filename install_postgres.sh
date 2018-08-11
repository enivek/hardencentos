sudo yum update
sudo yum install postgresql-server postgresql-contrib

sudo postgresql-setup initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
