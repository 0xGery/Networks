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

#!/bin/bash

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
NULINK_KEYSTORE_PASSWORD=$(prompt_for_password "Enter NuLink keystore password (min 8 characters): ")
NULINK_OPERATOR_ETH_PASSWORD=$(prompt_for_password "Enter worker account password (min 8 characters): ")

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
# ... [Additional script initialization, if any]

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
sudo apt install -y python3-pip ca-certificates curl gnupg expect || { echo "Failed to install required packages"; exit 1; }
pip install virtualenv || { echo "Failed to install virtualenv"; exit 1; }

# Installing and setting up Geth
sleep 2
GETH_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz"
GETH_DIR="/root/geth-linux-amd64-1.10.23-d901d853"
wget -qO- $GETH_URL | tar xvz -C /root || { echo "Failed to download and extract Geth"; exit 1; }
cd $GETH_DIR || { echo "Failed to navigate to Geth directory"; exit 1; }

# Prompting user for Geth account password manually and creating a new account
./geth account new --keystore ./keystore

# Automatically retrieve the path of the newly created keystore file
KEYSTORE_FILE=$(ls keystore/ | head -n 1)

# Check if keystore file exists
if [ -z "$KEYSTORE_FILE" ]; then
    echo "Keystore file not found, account creation failed."
    exit 1
fi

# Change permissions of the keystore file
chmod 644 keystore/$KEYSTORE_FILE

# ... [Rest of the script including Docker commands]

# Docker commands with updated volume binding and using stored passwords
docker run -it --rm \
-p 9151:9151 \
-v $PWD/keystore:/root/keystore \
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
-v $PWD/keystore:/root/keystore \
-v $NULINK_DIR:/code \
-v $NULINK_DIR:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD=$NULINK_KEYSTORE_PASSWORD \
-e NULINK_OPERATOR_ETH_PASSWORD=$NULINK_OPERATOR_ETH_PASSWORD \
nulink/nulink nulink ursula run --no-block-until-ready || { echo "Failed to run Docker container 'ursula'"; exit 1; }

sleep 2
docker logs -f ursula
