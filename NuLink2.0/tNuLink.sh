#!/bin/bash

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "      ___           ___           ___                         ___           ___           ___     "
echo "     /\  \         /\  \         /\__\                       /\  \         /\  \         /\  \    "
echo "     \:\  \       /::\  \       /:/  /          ___          \:\  \       /::\  \        \:\  \   "
echo "      \:\  \     /:/\:\  \     /:/  /          /\__\          \:\  \     /:/\:\__\        \:\  \  "
echo "  _____\:\  \   /:/  \:\  \   /:/  /  ___     /:/  /      ___  \:\  \   /:/ /:/  /    _____\:\  \ "
echo " /::::::::\__\ /:/__/ \:\__\ /:/__/  /\__\   /:/__/      /\  \  \:\__\ /:/_/:/__/___ /::::::::\__\""
echo " \:\~~\~~\/__/ \:\  \ /:/  / \:\  \ /:/  /  /::\  \      \:\  \ /:/  / \:\/:::::/  / \:\~~\~~\/__/"
echo "  \:\  \        \:\  /:/  /   \:\  /:/  /  /:/\:\  \      \:\  /:/  /   \::/~~/~~~~   \:\  \      "
echo "   \:\  \        \:\/:/  /     \:\/:/  /   \/__\:\  \      \:\/:/  /     \:\~~\        \:\  \     "
echo "    \:\__\        \::/  /       \::/  /         \:\__\      \::/  /       \:\__\        \:\__\    "
echo "     \/__/         \/__/         \/__/           \/__/       \/__/         \/__/         \/__/    "
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# System update and upgrade
sudo dpkg --configure -a
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get -f install

# Installing essential packages
sudo apt install -y python3-pip ca-certificates curl gnupg expect
pip install virtualenv

# Function to prompt for password input with hidden input
prompt_for_password() {
    local password
    local prompt_message=$1
    while true; do
        read -s -p "$prompt_message" password
        echo
        if [ ${#password} -ge 8 ]; then
            echo "Password set."
            break
        else
            echo "Password must be at least 8 characters long. Please try again."
        fi
    done
    echo $password
}

# Prompt for NuLink keystore password and operator password
echo "Enter NuLink keystore password (min 8 characters):"
NULINK_KEYSTORE_PASSWORD=$(prompt_for_password "")

echo "Enter worker account password (min 8 characters):"
NULINK_OPERATOR_ETH_PASSWORD=$(prompt_for_password "")

# Installing and setting up Geth
GETH_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz"
GETH_DIR="/root/geth-linux-amd64-1.10.23-d901d853"
wget -qO- $GETH_URL | tar xvz -C /root
cd $GETH_DIR

# Creating a new account
./geth account new --keystore ./keystore

# Prompting user to enter the public address manually
read -p "Enter the public address of the key (with 0x prefix): " PUBLIC_ADDRESS

# Docker installation
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Verifying Docker installation
docker --version || { echo "Failed to install Docker"; exit 1; }

# Docker commands with stored passwords
docker run -it --rm -p 9151:9151 -v $PWD/keystore:/root/keystore -v $NULINK_DIR:/code -v $NULINK_DIR:/home/circleci/.local/share/nulink -e NULINK_KEYSTORE_PASSWORD=$NULINK_KEYSTORE_PASSWORD nulink/nulink nulink ursula init --signer keystore:///root/keystore/$KEYSTORE_FILE --eth-provider https://data-seed-prebsc-2-s2.binance.org:8545 --network horus --payment-provider https://data-seed-prebsc-2-s2.binance.org:8545 --payment-network bsc_testnet --operator-address $PUBLIC_ADDRESS --max-gas-price 10000000000 || { echo "Failed to run Docker container for initialization"; exit 1; }

docker run --restart on-failure -d --name ursula -p 9151:9151 -v $PWD/keystore:/root/keystore -v $NULINK_DIR:/code -v $NULINK_DIR:/home/circleci/.local/share/nulink -e NULINK_KEYSTORE_PASSWORD=$NULINK_KEYSTORE_PASSWORD -e NULINK_OPERATOR_ETH_PASSWORD=$NULINK_OPERATOR_ETH_PASSWORD nulink/nulink nulink ursula run --no-block-until-ready || { echo "Failed to run Docker container 'ursula'"; exit 1; }

docker logs -f ursula
