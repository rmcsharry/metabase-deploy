#!/usr/bin/env bash
# .profile.d/ssh-setup.sh

# For EasyPeasy so we can copy prod db to heroku securely
# This file grabs the RSA keys from heroku settings (env vars) and writes them to files 
# so they can be used by a Heroku scheduled worker to ssh to prod

mkdir -p ${HOME}/.ssh
chmod 700 ${HOME}/.ssh

echo "Checking if private key exist..."
if [ "$HEROKU_PUBLIC_KEY" ]; then
    # Copy public key env variable into a file
    echo "${HEROKU_PUBLIC_KEY}" > ${HOME}/.ssh/id_rsa.pub
    chmod 644 ${HOME}/.ssh/id_rsa.pub
    echo "HEROKU_PUBLIC_KEY successfully written to file"
else
  echo "HEROKU_PUBLIC_KEY not found in Heroku settings"
fi

if [ "$HEROKU_PRVATE_KEY" ]; then
    # Copy private key env variable into a file
    echo "${HEROKU_PRIVATE_KEY}" > ${HOME}/.ssh/id_rsa
    chmod 600 ${HOME}/.ssh/id_rsa
    echo "HEROKU_PRVATE_KEY successfully written to file"
else
  echo "HEROKU_PRVATE_KEY not found in Heroku settings"
fi

# Auto add the host to known_hosts
# This is to avoid the authenticity of host question that otherwise will halt ssh since it will raise a warning
# This step is maybe not necessary since you can call ssh with the flag '-o StrictHostKeyChecking=no' but it is best
# to KNOW the host we are connecting to...after all that is what known_hosts file is for!
# Ex:
# The authenticity of host '[hostname] ([IP address])' can't be established.
# RSA key fingerprint is [fingerprint].
# Are you sure you want to continue connecting (yes/no)?

# This is the IP of the EasyPeasy production database server
ssh-keyscan 85.159.211.37 >> ${HOME}/.ssh/known_hosts
