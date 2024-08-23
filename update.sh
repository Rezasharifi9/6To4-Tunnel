#!/bin/bash

# بارگذاری اطلاعات شبکه از فایل محیطی
source /etc/tunnel_env

# دریافت IPهای جدید از دام```bash
# دریافت IPهای جدید از دامنه‌ها
remote_ip=$(dig +short "$REMOTE_DOMAIN")
local_ip=$(dig +short "$LOCAL_DOMAIN")

# بررسی اینکه آیا IP ها دریافت شده‌اند
if [[ -z "$remote_ip" || -z "$local_ip" ]]; then
    echo "Error: Could not resolve one or both domain names to IP addresses."
    exit 1
fi

# به‌روزرسانی فایل محیطی با IPهای جدید
echo "REMOTE_IP=$remote_ip" > /etc/tunnel_env
echo "LOCAL_IP=$local_ip" >> /etc/tunnel_env

# حذف تونل‌های قدیمی
ip link delete ${NETWORK_NAME}_6To4 2>/dev/null
ip link delete ${NETWORK_NAME}_GRE 2>/dev/null

# تنظیم تونل‌های جدید با IPهای به‌روزرسانی شده
ip tunnel add ${NETWORK_NAME}_6To4 mode sit remote "$remote_ip" local "$local_ip"
ip -6 addr add "$LOCAL_IPV6" dev ${NETWORK_NAME}_6To4
ip link set ${NETWORK_NAME}_6To4 up

ip -6 tunnel add ${NETWORK_NAME}_GRE mode ip6gre remote "$REMOTE_IPV6" local "$LOCAL_IPV6"
ip addr add "$LOCAL_IPV4"/30 dev ${NETWORK_NAME}_GRE
ip link set ${NETWORK_NAME}_GRE up

echo "Tunnels updated with new IPs: $remote_ip (remote) and $local_ip (local)."
