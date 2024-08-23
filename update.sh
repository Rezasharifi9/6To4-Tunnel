#!/bin/bash

# فایل ذخیره اطلاعات شبکه
TUNNEL_FILE="/etc/tunnel_env"

# تابع برای اعتبارسنجی وجود فایل ذخیره اطلاعات
validate_tunnel_file() {
    if [[ ! -f "$TUNNEL_FILE" ]]; then
        echo "Tunnel information not found. Please configure the tunnel first."
        exit 1
    fi
}

# تابع برای آپدیت تونل
update_tunnel() {
    validate_tunnel_file

    # دریافت اطلاعات قبلی از فایل
    source "$TUNNEL_FILE"

    # استفاده از اطلاعات ذخیره شده برای تصمیم‌گیری
    if [[ "$SERVER_LOCATION" == "Iran" ]]; then
        echo "This server is in Iran. Configuring based on that."
        local_ipv6="$LOCAL_IPV6"
        remote_ipv6="$REMOTE_IPV6"
        remote_domain="$REMOTE_DOMAIN"
    elif [[ "$SERVER_LOCATION" == "Abroad" ]]; then
        echo "This server is Abroad. Configuring based on that."
        local_ipv6="$REMOTE_IPV6"
        remote_ipv6="$LOCAL_IPV6"
        remote_domain="$LOCAL_DOMAIN"
    else
        echo "Invalid server location information."
        exit 1
    fi

    # به‌روزرسانی تونل با اطلاعات جدید
    remote_ip=$(dig +short "$remote_domain")

    if [[ -z "$remote_ip" ]]; then
        echo "Error: Could not resolve the domain name to an IP address."
        exit 1
    fi

    echo "Updating tunnel with new settings..."

    ip link delete ${NETWORK_NAME}_6To4 2>/dev/null
    ip link delete ${NETWORK_NAME}_GRE 2>/dev/null

    # ایجاد تونل 6to4
    ip tunnel add ${NETWORK_NAME}_6To4 mode sit remote $remote_ip local $local_ip
    ip -6 addr add $local_ipv6/64 dev ${NETWORK_NAME}_6To4
    ip link set ${NETWORK_NAME}_6To4 up

    # ایجاد تونل GRE
    ip -6 tunnel add ${NETWORK_NAME}_GRE mode ip6gre remote $remote_ipv6 local $local_ipv6
    ip addr add $LOCAL_IPV4/30 dev ${NETWORK_NAME}_GRE
    ip link set ${NETWORK_NAME}_GRE up

    echo "Tunnel has been successfully updated."
}

update_tunnel
