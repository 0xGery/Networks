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

# Finalize Installation
python -c "import nulink"

# Set Environment Variables
export NULINK_KEYSTORE_PASSWORD=<YOUR_NULINK_STORAGE_PASSWORD>
export NULINK_OPERATOR_ETH_PASSWORD=<YOUR_WORKER_ACCOUNT_PASSWORD>

### fund your address with testbnb
# Initialize Node Configuration.
docker run -it --rm \
-p 9151:9151 \
-v /root/nulink:/code \
-v /root/nulink:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD \
nulink/nulink nulink ursula init \
--signer <ETH KEYSTORE URI> \
--eth-provider <NULINK PROVIDER URI>  \
--network <NULINK NETWORK NAME> \
--payment-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--payment-network bsc_testnet \
--operator-address <WORKER ADDRESS> \
--max-gas-price 10000000000

### as example:
docker run -it --rm \
-p 9151:9151 \
-v /root/nulink:/code \
-v /root/nulink:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD \
nulink/nulink nulink ursula init \
--signer keystore:///code/UTC--2024-01-03T09-38-01.936840855Z--cae23d00f1552606fd57e231620382bd12bcc7be \
--eth-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--network horus \
--payment-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--payment-network bsc_testnet \
--operator-address 0xCae23d00F1552606fd57e231620382bd12BcC7be \
--max-gas-price 10000000000

# Run Node
docker run --restart on-failure -d \
--name ursula \
-p 9151:9151 \
-v /root/nulink:/code \
-v /root/nulink:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD \
-e NULINK_OPERATOR_ETH_PASSWORD \
nulink/nulink nulink ursula run --no-block-until-ready
