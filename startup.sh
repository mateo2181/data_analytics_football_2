apt-get update -y
apt-get install -y python3 python3-pip
python3 -m pip install --upgrade pip wheel
apt-get install -y python3-venv
apt update -y
apt install -y docker.io
systemctl start docker
systemctl enable docker
sudo gpasswd -a $USER docker
newgrp docker
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
cd ~ && git clone https://github.com/mateo2181/data_analytics_football_2
cd data_analytics_football_2
mkdir -p logs
echo -e "AIRFLOW_UID=$(id -u)" > .env
echo ${var.project} >> .env
docker-compose up -d
# python3 -m venv prefect-env
# source prefect-env/bin/activate
# cd prefect && python3 -m pip install .
# IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip`
# mkdir ~/.prefect
# cat <<EOF >>~/.prefect/config.toml
# [server]
  
#   [server.ui]
    
    # graphql_url = "http://$IP:4200/graphql"
# EOF
# prefect server start