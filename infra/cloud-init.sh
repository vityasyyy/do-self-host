#!/bin/bash
# Update and install python for Ansible
apt-get update
apt-get install -y python3 ufw

ufw allow OpenSSH
ufw enable
