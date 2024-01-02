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
sleep 2

echo "Enter worker account password (min 8 characters):"
NULINK_OPERATOR_ETH_PASSWORD=$(prompt_for_password "")
sleep 2

# Installing necessary packages
sudo apt-get update || { echo "Failed to update repositories"; exit 1; }
sleep 2
sudo apt-get install -y python3-pip ca-certificates curl gnupg expect || { echo "Failed to install required packages"; exit 1; }
sleep 2
pip install virtualenv || { echo "Failed to install virtualenv"; exit 1; }
sleep 2

# Installing and setting up Geth
GETH_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz"
GETH_DIR="/root/geth-linux-amd64-1.10.23-d901d853"
wget -qO- $GETH_URL | tar xvz -C /root || { echo "Failed to download and extract Geth"; exit 1; }
sleep 2
cd $GETH_DIR || { echo "Failed to navigate to Geth directory"; exit 1; }

# Creating a new account
./geth account new --keystore ./keystore
sleep 2

# Automatically retrieve the path of the newly created keystore file
KEYSTORE_FILE=$(ls keystore/ | head -n 1)

if [ -z "$KEYSTORE_FILE" ]; then
    echo "Keystore file not found, account creation failed."
    exit 1
fi

chmod 644 keystore/$KEYSTORE_FILE
sleep 2

# Docker Installation
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sleep 2
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
sleep 2
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sleep 2
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sleep 2

# Verifying Docker installation
sudo docker --version || { echo "Failed to install Docker"; exit 1; }
sleep 2

# Setting NuLink directory
NULINK_DIR="/root/nulink"
mkdir -p $NULINK_DIR
cp "$GETH_DIR/keystore"/* "$NULINK_DIR" || { echo "Failed to copy keystore files"; exit 1; }
chmod -R 777 $NULINK_DIR
sleep 2

# Docker commands with updated volume binding and using stored passwords
docker run -it --rm \
-p 9151:9151 \
-v $NULINK_DIR:/code \
-v $NULINK_DIR:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD=$NULINK_KEYSTORE_PASSWORD \
nulink/nulink nulink ursula init \
--signer "keystore:///root/keystore/$KEYSTORE_FILE" \
--eth-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--network horus \
--payment-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--payment-network bsc_testnet \
--operator-address "0x$PUBLIC_ADDRESS" \
--max-gas-price 10000000000 || { echo "Failed to run Docker container for initialization"; exit 1; }

sleep 2

docker run --restart on-failure -d \
--name ursula \
-p 9151:9151 \
-v $NULINK_DIR:/code \
-v $NULINK_DIR:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD=$NULINK_KEYSTORE_PASSWORD \
-e NULINK_OPERATOR_ETH_PASSWORD=$NULINK_OPERATOR_ETH_PASSWORD \
nulink/nulink nulink ursula run --no-block-until-ready || { echo "Failed to run Docker container 'ursula'"; exit 1; }

docker logs -f ursula
