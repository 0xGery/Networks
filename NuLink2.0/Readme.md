# NuLink Setup Instructions

```bash
# Install and Configure Geth
wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz
tar -xvzf geth-linux-amd64-1.10.23-d901d853.tar.gz
cd geth-linux-amd64-1.10.23-d901d853/
./geth account new --keystore ./keystore

# Install Docker
sudo apt-get update && sudo apt-get install ca-certificates curl gnupg -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
docker pull nulink/nulink:latest

# Set Up NuLink Directory
mkdir -p /root/nulink
cp /root/geth-linux-amd64-1.10.23-d901d853/keystore/* /root/nulink
chmod -R 777 /root/nulink

# System Updates and Python Environment
sudo apt-get clean
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install python3-pip -y
pip install virtualenv
virtualenv /root/nulink-venv
source /root/nulink-venv/bin/activate

# Install NuLink
wget https://download.nulink.org/release/core/nulink-0.5.0-py3-none-any.whl
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
pip install nulink-0.5.0-py3-none-any.whl
source /root/nulink-venv/bin/activate

# Set Environment Variables
export NULINK_KEYSTORE_PASSWORD=<YOUR_NULINK_STORAGE_PASSWORD>
export NULINK_OPERATOR_ETH_PASSWORD=<YOUR_WORKER_ACCOUNT_PASSWORD>

# Finalize Installation
python -c "import nulink"
