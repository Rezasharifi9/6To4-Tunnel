
# Tunnel Configuration Script

This repository contains two bash scripts to help you configure and manage IPv6 and IPv4 tunnels using SIT (IPv6-in-IPv4) and GRE (Generic Routing Encapsulation) modes. The scripts allow for both manual and automated input for IP addresses, and provide functionality for auto-updating tunnels based on domain name changes.

## Features:
- Add a new tunnel with automatic or manual IPv6 and IPv4 address generation.
- Configure tunnels based on domain names for both local (Iran) and remote (Abroad) servers.
- Auto-update tunnels upon system reboot with updated IP addresses.
- Auto-generate random IPv4 addresses within a specified range.
- Save and persist all tunnel configurations for future updates.

## Script Details

### `add_tunnel.sh`
This script is used to create a new tunnel configuration or edit an existing one. It prompts the user for various inputs such as domains, IP addresses, and network names.

#### Usage:
1. **Add a new tunnel:** Choose to add a new tunnel with manual or automatically generated IPv6 addresses.
2. **Automatic IPv6 generation:** The script will generate random IPv6 addresses if chosen.
3. **Random IPv4 generation:** The IPv4 addresses will be automatically generated in the range `172.18.20.X`, where `X` is a random number between 1 and 254.
4. **Save all configurations:** The domain names, IPv6, IPv4 addresses, and network name are saved in the `/etc/tunnel_env` file for later use by the update script.

#### How to Run:
```bash
sudo bash add_tunnel.sh
```

#### Input Prompts:
- **Domains:** The script will ask for the remote and local domain names.
- **IPv6 Address:** You can choose to either manually enter the IPv6 addresses or let the script generate them for you.
- **IPv4 Address:** Automatically generated within the `172.18.20.0/24` subnet.

### `update_tunnel.sh`
This script is used to update tunnel configurations based on new IP addresses resolved from the stored domain names. It checks for changes in the resolved IP addresses and updates the tunnel settings accordingly. The script is intended to be run automatically after each system reboot to ensure that tunnels are always using the latest IP addresses.

#### How it Works:
1. **Reads configuration from `/etc/tunnel_env`:** All stored configuration details are read from this file, including domain names, IPv6, IPv4 addresses, and network name.
2. **Resolves IP addresses from domain names:** The script uses `dig` to resolve the latest IP addresses for the remote and local domains.
3. **Compares the new IPs:** If the IPs have changed, it updates the tunnel configuration accordingly.

#### How to Set Up for Auto-Execution:
You can set up this script to run automatically after every system reboot by adding it to `cron`.

#### Setup Cron for Auto-Execution:
1. Open the cron editor:
   ```bash
   sudo crontab -e
   ```

2. Add the following line to execute the script at reboot:
   ```
   @reboot /path/to/update_tunnel.sh
   ```

#### How to Run Manually:
```bash
sudo bash update_tunnel.sh
```

## Example Workflow

1. **Run `add_tunnel.sh`:**  
   Configure your tunnel by providing domain names, selecting whether to enter IPv6 addresses manually, and allowing the script to generate random IPv4 addresses. All information will be stored for future use.

2. **Run `update_tunnel.sh`:**  
   After reboot or whenever necessary, this script will reconfigure the tunnel based on the most recent IP addresses resolved from the stored domain names.

## Files

- `add_tunnel.sh`: Script to create or edit tunnels.
- `update_tunnel.sh`: Script to update tunnels based on domain name IP changes.
- `/etc/tunnel_env`: File storing all tunnel configuration data.

## Requirements
- **Operating System:** Linux-based OS (Ubuntu, Debian, CentOS, etc.)
- **Tools Required:** `ip`, `dig`, `openssl`
- **Permissions:** Root or sudo privileges.

### Download and Execute

First, download the script using `curl` or `wget`:

```bash
curl -O https://raw.githubusercontent.com/Rezasharifi9/6To4-Tunnel/main/6to4.sh
chmod +x 6to4.sh
sudo ./6to4.sh


