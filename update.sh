#!/bin/bash

# مسیر پوشه‌ای که اطلاعات تونل‌ها را ذخیره می‌کند
TUNNEL_DIR="/etc/tunnel_configs"

# تابع برای حذف تونل‌های مشخص شده بر اساس نام شبکه
delete_specific_tunnels() {
    echo "Deleting specified tunnels..."
    for tunnel_file in "$TUNNEL_DIR"/*_env; do
        if [[ -f "$tunnel_file" ]]; then
            # بارگذاری اطلاعات تونل از فایل
            source "$tunnel_file"

            # حذف تونل‌هایی که با نام این شبکه ساخته شده‌اند
            ip link delete ${NETWORK_NAME}_6To4 2>/dev/null
            ip link delete ${NETWORK_NAME}_GRE 2>/dev/null
            echo "Deleted tunnel: $NETWORK_NAME"
        fi
    done
    echo "Specified tunnels have been deleted."
}

# تابع برای به‌روزرسانی تمامی تونل‌های مشخص شده
update_all_tunnels() {
    echo "Updating all specified tunnels..."

    # چک کردن اینکه پوشه‌ی تونل‌ها وجود دارد
    if [[ ! -d "$TUNNEL_DIR" ]]; then
        echo "No tunnel configurations found. Please add tunnels first."
        exit 1
    fi

    # پردازش تمامی فایل‌های موجود در پوشه‌ی تونل‌ها
    for tunnel_file in "$TUNNEL_DIR"/*_env; do
        if [[ -f "$tunnel_file" ]]; then
            # بارگذاری اطلاعات تونل از فایل
            source "$tunnel_file"

            echo "Updating tunnel for network: $NETWORK_NAME"

            # دریافت IPها از دامنه‌ها
            remote_ip=$(dig +short "$REMOTE_DOMAIN")
            local_ip=$(dig +short "$LOCAL_DOMAIN")

            if [[ -z "$remote_ip" || -z "$local_ip" ]]; then
                echo "Error: Could not resolve one or both domain names to IP addresses for $NETWORK_NAME."
                continue
            fi

            echo "Resolved IPs: Local IP = $local_ip, Remote IP = $remote_ip"

            # تنظیم تونل 6to4 و GRE
            echo "Setting up tunnels for network: $NETWORK_NAME"

            # ایجاد تونل 6to4
            ip tunnel add ${NETWORK_NAME}_6To4 mode sit remote $remote_ip local $local_ip
            ip -6 addr add $LOCAL_IPV6/64 dev ${NETWORK_NAME}_6To4
            ip link set ${NETWORK_NAME}_6To4 up
            echo "6to4 tunnel setup completed for $NETWORK_NAME."

            # ایجاد تونل GRE
            ip -6 tunnel add ${NETWORK_NAME}_GRE mode ip6gre remote $REMOTE_IPV6 local $LOCAL_IPV6
            ip addr add $LOCAL_IPV4/30 dev ${NETWORK_NAME}_GRE
            ip link set ${NETWORK_NAME}_GRE up
            echo "GRE tunnel setup completed for $NETWORK_NAME."
        fi
    done

    echo "All specified tunnels have been updated successfully."
}

# اجرای به‌روزرسانی تمامی تونل‌های مشخص شده
delete_specific_tunnels
update_all_tunnels
