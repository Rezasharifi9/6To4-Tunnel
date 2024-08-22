# Network Tunnel Setup Script

This repository contains a bash script to configure network tunnels (6to4 and GRE6/IPIPv6) on a Linux system. The script is designed to work with dynamic user inputs, validating network names and domains, and handling the creation or replacement of existing tunnels.

## Features

- Configures a 6to4 tunnel and GRE6/IPIPv6 tunnel.
- Validates network name and domain inputs.
- Checks if a network with the given name already exists and replaces it if necessary.
- Stores tunnel configuration in `/etc/rc.local` for persistence across reboots.
- Automatically generates IPv4 and IPv6 addresses.

## Usage

To use this script, you can download and execute it directly from GitHub.

### Download and Execute

First, download the script using `curl` or `wget`:

```bash
curl -O https://raw.githubusercontent.com/Rezasharifi9/6To4-Tunnel/main/6to4.sh
chmod +x 6to4.sh
sudo ./6to4.sh


