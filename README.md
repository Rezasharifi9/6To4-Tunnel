
# Tunnel Configuration Script

This repository contains two bash scripts to help you configure and manage IPv6 and IPv4 tunnels using SIT (IPv6-in-IPv4) and GRE (Generic Routing Encapsulation) modes. The scripts allow for both manual and automated input for IP addresses, and provide functionality for auto-updating tunnels based on domain name changes.

## Features:
- Add a new tunnel with automatic or manual IPv6 and IPv4 address generation.
- Configure tunnels based on domain names for both local (Iran) and remote (Abroad) servers.
- Auto-update tunnels upon system reboot with updated IP addresses.
- Auto-generate random IPv4 addresses within a specified range.
- Save and persist all tunnel configurations for future updates.

### Download and Execute

First, download the script using `curl` or `wget`:

```bash
curl -O https://raw.githubusercontent.com/Rezasharifi9/6To4-Tunnel/main/6to4.sh
chmod +x 6to4.sh
sudo ./6to4.sh
```

2. **Download the Update Script**

   Download the `update_tunnel.sh` script for automatic tunnel updates:

   ```bash
   curl -O https://raw.githubusercontent.com/Rezasharifi9/6To4-Tunnel/main/update.sh
   ```

3. **Set Up Crontab for Automatic Updates**

   Schedule the `update.sh` to run periodically by adding it to your `crontab`:

   ```bash
   crontab -e
   ```

   Add the following line to run the update script every hour:

   ```bash
   @reboot /root/update.sh
   ```

---

That's it! Your tunnels will be set up and automatically updated.