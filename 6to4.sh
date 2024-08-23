#!/bin/bash

# مسیر پوشه‌ای که اطلاعات تونل‌ها را ذخیره می‌کند
TUNNEL_DIR="/etc/tunnel_configs"

# اطمینان از اینکه پوشه وجود دارد
mkdir -p "$TUNNEL_DIR"

# تابع برای نمایش منوی اصلی
show_menu() {
    echo "============================================"
    echo " Welcome to the Tunnel Configuration Script "
    echo "============================================"
    echo "Please select an option:"
    echo "1. Add a new tunnel"
    echo "2. Edit an existing tunnel"
    echo "3. Install 3x-ui"
    echo "4. Exit"
}

# تابع برای افزودن یا به‌روزرسانی یک مقدار در فایل
update_env_file() {
    local tunnel_file=$1
    local key=$2
    local value=$3

    # اگر کلید موجود است، مقدار آن را به‌روزرسانی کن، در غیر این صورت کلید را اضافه کن
    if grep -q "^$key=" "$tunnel_file"; then
        # به‌روزرسانی خط با مقدار جدید
        sed -i "s/^$key=.*/$key=$value/" "$tunnel_file"
    else
        # اضافه کردن کلید جدید
        echo "$key=$value" >> "$tunnel_file"
    fi
}

# تابع برای افزودن تونل جدید و ذخیره اطلاعات شبکه
add_tunnel() {
    echo "Adding a new tunnel..."

    # دریافت نام شبکه از کاربر
    read -p "Enter the network name: " network_name
    TUNNEL_FILE="$TUNNEL_DIR/${network_name}_env"

    # دریافت دامنه‌ها از کاربر
    read -p "Enter the domain for the Iran server: " iran_domain
    read -p "Enter the domain for the Abroad server: " abroad_domain

    # پرسش از کاربر برای تعیین نوع سرور محلی (ایران یا خارج)
    read -p "Is this server based in Iran or Abroad? (1 for Iran, 2 for Abroad): " server_location
    if [[ "$server_location" == "1" ]]; then
        server_location="Iran"
        local_ipv6="ad11::1"
        remote_ipv6="ad11::2"
        local_domain="$iran_domain"
        remote_domain="$abroad_domain"
        echo "Configuring Local IPv6 as: $local_ipv6 (Iran)"
        echo "Configuring Remote IPv6 as: $remote_ipv6 (Abroad)"
    elif [[ "$server_location" == "2" ]]; then
        server_location="Abroad"
        local_ipv6="ad11::2"
        remote_ipv6="ad11::1"
        local_domain="$abroad_domain"
        remote_domain="$iran_domain"
        echo "Configuring Local IPv6 as: $local_ipv6 (Abroad)"
        echo "Configuring Remote IPv6 as: $remote_ipv6 (Iran)"
    else
        echo "Invalid selection. Please enter 1 for Iran or 2 for Abroad."
        exit 1
    fi

    # تولید آدرس‌های IPv4 به صورت رندوم
    local_ipv4="172.18.20.1"
    remote_ipv4="172.18.20.2"
    echo "Generated Local IPv4: $local_ipv4"
    echo "Generated Remote IPv4: $remote_ipv4"

    # به‌روزرسانی یا اضافه کردن اطلاعات جدید به فایل تونل
    update_env_file "$TUNNEL_FILE" "NETWORK_NAME" "$network_name"
    update_env_file "$TUNNEL_FILE" "LOCAL_DOMAIN" "$local_domain"
    update_env_file "$TUNNEL_FILE" "REMOTE_DOMAIN" "$remote_domain"
    update_env_file "$TUNNEL_FILE" "LOCAL_IPV6" "$local_ipv6"
    update_env_file "$TUNNEL_FILE" "REMOTE_IPV6" "$remote_ipv6"
    update_env_file "$TUNNEL_FILE" "LOCAL_IPV4" "$local_ipv4"
    update_env_file "$TUNNEL_FILE" "REMOTE_IPV4" "$remote_ipv4"
    update_env_file "$TUNNEL_FILE" "SERVER_LOCATION" "$server_location"

    # دریافت IPها از دامنه‌ها
    remote_ip=$(dig +short "$remote_domain")
    local_ip=$(dig +short "$local_domain")

    if [[ -z "$remote_ip" || -z "$local_ip" ]]; then
        echo "Error: Could not resolve one or both domain names to IP addresses."
        exit 1
    fi

    update_env_file "$TUNNEL_FILE" "REMOTE_IP" "$remote_ip"
    update_env_file "$TUNNEL_FILE" "LOCAL_IP" "$local_ip"

    # تنظیم تونل 6to4 و GRE
    echo "Setting up tunnels for network: $network_name"
    ip link delete ${network_name}_6To4 2>/dev/null
    ip link delete ${network_name}_GRE 2>/dev/null

    # ایجاد تونل 6to4
    ip tunnel add ${network_name}_6To4 mode sit remote $remote_ip local $local_ip
    ip -6 addr add $local_ipv6/64 dev ${network_name}_6To4
    ip link set ${network_name}_6To4 up
    echo "6to4 tunnel setup completed for $network_name."

    # ایجاد تونل GRE
    ip -6 tunnel add ${network_name}_GRE mode ip6gre remote $remote_ipv6 local $local_ipv6
    ip addr add $local_ipv4/30 dev ${network_name}_GRE
    ip link set ${network_name}_GRE up
    echo "GRE tunnel setup completed for $network_name."

    # بررسی اینکه آیا تونل‌ها با موفقیت اضافه شده‌اند
    if ip link show ${network_name}_6To4 && ip link show ${network_name}_GRE; then
        echo "Tunnel has been successfully added to the network."
    else
        echo "Error: Unable to set up the tunnel."
        exit 1
    fi
}

# تابع برای نصب 3x-ui
install_3xui() {
    echo "Downloading and installing 3x-ui..."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

# تابع برای ویرایش تونل موجود
edit_tunnel() {
    echo "Editing an existing tunnel..."

    # دریافت نام شبکه با اعتبارسنجی
    while true; do
        read -p "Enter the name of the tunnel you want to edit: " network_name
        TUNNEL_FILE="$TUNNEL_DIR/${network_name}_env"
        if [[ "$network_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            echo "Invalid network name. Please enter a valid network name."
        fi
    done

    # بررسی اینکه آیا فایل تونل با این نام وجود دارد یا خیر
    if [[ ! -f "$TUNNEL_FILE" ]]; then
        echo "The network '$network_name' does not exist. Exiting."
        return
    fi

    # حذف تونل‌های موجود با این نام
    ip link delete ${network_name}_6To4 2>/dev/null
    ip link delete ${network_name}_GRE 2>/dev/null
    echo "Previous network '$network_name' has been deleted."

    # فراخوانی تابع add_tunnel برای ایجاد تونل جدید با اطلاعات جدید
    add_tunnel
}

# نمایش منوی اصلی و اجرای انتخاب کاربر
while true; do
    show_menu
    read -p "Please enter your choice (1-4): " choice

    case $choice in
        1)
            add_tunnel
            ;;
        2)
            edit_tunnel
            ;;
        3)
            install_3xui
            ;;
        4)
            echo "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter a number between 1 and 4."
            ;;
    esac
done
