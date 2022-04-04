apt-get update -y
apt-get install -y python3 python3-pip
python3 -m pip install --upgrade pip wheel
apt-get install -y python3-venv
apt update -y
apt install -y docker.io
systemctl start docker
systemctl enable docker
sudo gpasswd -a ubuntu docker
newgrp docker
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
cd /home/ubuntu
git clone https://github.com/mateo2181/data_analytics_football_2
cd data_analytics_football_2
mkdir -p logs
echo -e "AIRFLOW_UID=$(id -u)" > .env
echo "GCP_PROJECT_ID=${PROJECT}" >> .env
echo "GCP_GCS_BUCKET=${BUCKET}" >> .env
echo "GCP_BIGQUERY_DATASET=${BG_DATASET}" >> .env
echo "GCP_BIGQUERY_DATASET_DBT_DEV=${BG_DATASET_DBT}" >> .env
echo "GCP_BIGQUERY_DATASET_DBT_PROD=${BG_DATASET_PROD}" >> .env
docker-compose up -d
# IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip`