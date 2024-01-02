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

# Cleaning up package cache and updating repositories
sudo apt-get clean
sleep 2
sudo apt-get update || { echo "Failed to update repositories"; exit 1; }

# Fixing any broken packages
sleep 2
sudo apt-get -f install || { echo "Failed to fix broken packages"; exit 1; }

# Reconfiguring packages
sleep 2
sudo dpkg --configure -a || { echo "Failed to reconfigure packages"; exit 1; }

# Installing necessary packages
sleep 2
sudo apt install -y python3-pip ca-certificates curl gnupg || { echo "Failed to install required packages"; exit 1; }

# Update pip to the latest version
pip install --upgrade pip

# Install Rust compiler (needed for nucypher-core)
sudo apt install -y cargo || { echo "Failed to install Rust compiler"; exit 1; }

# Ensure the Rust compiler is in the PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Installing and setting up Geth
sleep 2
GETH_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz"
GETH_DIR="/root/geth-linux-amd64-1.10.23-d901d853"
wget -qO- $GETH_URL | tar xvz -C /root || { echo "Failed to download and extract Geth"; exit 1; }
cd $GETH_DIR || { echo "Failed to navigate to Geth directory"; exit 1; }

# Prompting user for Geth account password manually
echo "Please manually enter a new password for the Geth account when prompted."

# Running Geth account creation command
./geth account new --keystore ./keystore

# Checking if keystore directory is created
if [ ! -d "./keystore" ]; then
    echo "Keystore directory not found, account creation failed."
    exit 1
fi

# Extracting the public address and path of the secret key file
KEYSTORE_FILE=$(ls ./keystore/)
if [ -z "$KEYSTORE_FILE" ]; then
    echo "No keystore file found, account creation failed."
    exit 1
fi
PUBLIC_ADDRESS=$(echo $KEYSTORE_FILE | grep -o -E "[0-9a-fA-F]{40}")
SECRET_KEY_PATH="/root/geth-linux-amd64-1.10.23-d901d853/keystore/$KEYSTORE_FILE"
if [ -z "$PUBLIC_ADDRESS" ] || [ ! -f "$SECRET_KEY_PATH" ]; then
    echo "Failed to extract public address or secret key path from keystore file."
    exit 1
fi

echo "Public address of the new account: 0x$PUBLIC_ADDRESS"
echo "Path of the secret key file: $SECRET_KEY_PATH"

# Docker Installation
sleep 2
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update || { echo "Failed to update repositories for Docker installation"; exit 1; }
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo "Failed to install Docker"; exit 1; }

# Docker Pull
sleep 2
docker pull nulink/nulink:latest || { echo "Failed to pull nulink/nulink:latest"; exit 1; }

# NuLink Setup
sleep 2
NULINK_DIR="/root/nulink"
mkdir -p $NULINK_DIR
cp "$GETH_DIR/keystore"/* "$NULINK_DIR" || { echo "Failed to copy keystore files"; exit 1; }
chmod -R 777 $NULINK_DIR
virtualenv $NULINK_DIR-venv
source $NULINK_DIR-venv/bin/activate
wget -O nulink-0.5.0-py3-none-any.whl https://download.nulink.org/release/core/nulink-0.5.0-py3-none-any.whl || { echo "Failed to download nulink-0.5.0-py3-none-any.whl"; exit 1; }
pip install nulink-0.5.0-py3-none-any.whl || { echo "Failed to install nulink-0.5.0-py3-none-any.whl"; exit 1; }
source $NULINK_DIR-venv/bin/activate

# Environment Variables
sleep 2
export NULINK_KEYSTORE_PASSWORD=$(prompt_for_password "Enter NuLink keystore password (min 8 characters): ")
export NULINK_OPERATOR_ETH_PASSWORD=$(prompt_for_password "Enter worker account password (min 8 characters): ")

# Function to ask for funding confirmation
ask_for_funding_confirmation() {
    while true; do
        read -p "Please fund your 0x$PUBLIC_ADDRESS with testBNB, have you funded it? (Y/N): " response
        case $response in
            [Yy]* ) break;;
            [Nn]* ) echo "Waiting for funding. Please fund your account.";;
            * ) echo "Please answer Y (yes) or N (no).";;
        esac
    done
}

# Asking user for funding confirmation
sleep 2
ask_for_funding_confirmation

# Running Docker container with NuLink configuration for initialization
docker run -it --rm \
-p 9151:9151 \
-v $NULINK_DIR:/code \
-v $NULINK_DIR:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD \
nulink/nulink nulink ursula init \
--signer "keystore://$SECRET_KEY_PATH" \
--eth-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--network horus \
--payment-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--payment-network bsc_testnet \
--operator-address "0x$PUBLIC_ADDRESS" \
--max-gas-price 10000000000 || { echo "Failed to run Docker container for initialization"; exit 1; }

# Running Docker container 'ursula' in detached mode
sleep 2
docker run --restart on-failure -d \
--name ursula \
-p 9151:9151 \
-v $NULINK_DIR:/code \
-v $NULINK_DIR:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD \
-e NULINK_OPERATOR_ETH_PASSWORD \
nulink/nulink nulink ursula run --no-block-until-ready || { echo "Failed to run Docker container 'ursula'"; exit 1; }
