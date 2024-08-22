#!/bin/bash

# تابع برای نمایش منوی اصلی
show_menu() {
    echo "============================================"
    echo " Welcome to the Tunnel Configuration Script "
    echo "============================================"
    echo "Please select an option:"
    echo "1. Add a new tunnel"
    echo "2. Edit an existing tunnel"
    echo "3. Install iptables and forward a port"
    echo "4. Exit"
}

# تابع برای افزودن تونل جدید و ذخیره اطلاعات شبکه
add_tunnel() {
    echo "Adding a new tunnel..."

    # دریافت نام شبکه از کاربر
    read -p "Enter the network name: " network_name

    # دریافت دامنه‌ها از کاربر
    read -p "Enter the domain for the Iran server: " iran_domain
    read -p "Enter the domain for the Abroad server: " abroad_domain

    # پرسش از کاربر برای تعیین نوع سرور محلی (ایران یا خارج)
    read -p "Is this server based in Iran or Abroad? (1 for Iran, 2 for Abroad): " server_location
    if [[ "$server_location" == "1" ]]; then
        # تنظیم سرور محلی به عنوان ایران
        local_ipv6="ad11::1/64"
        remote_ipv6="ad11::2/64"
        local_domain="$iran_domain"
        remote_domain="$abroad_domain"
        echo "Configuring Local IPv6 as: $local_ipv6 (Iran)"
        echo "Configuring Remote IPv6 as: $remote_ipv6 (Abroad)"
    elif [[ "$server_location" == "2" ]]; then
        # تنظیم سرور محلی به عنوان خارج
        local_ipv6="ad11::2/64"
        remote_ipv6="ad11::1/64"
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

    # ذخیره اطلاعات شبکه در فایل محیطی
    echo "NETWORK_NAME=$network_name" > /etc/tunnel_env
    echo "LOCAL_DOMAIN=$local_domain" >> /etc/tunnel_env
    echo "REMOTE_DOMAIN=$remote_domain" >> /etc/tunnel_env
    echo "LOCAL_IPV6=$local_ipv6" >> /etc/tunnel_env
    echo "REMOTE_IPV6=$remote_ipv6" >> /etc/tunnel_env
    echo "LOCAL_IPV4=$local_ipv4" >> /etc/tunnel_env
    echo "REMOTE_IPV4=$remote_ipv4" >> /etc/tunnel_env

    # دریافت IPها از دامنه‌ها
    remote_ip=$(dig +short "$remote_domain")
    local_ip=$(dig +short "$local_domain")

    if [[ -z "$remote_ip" || -z "$local_ip" ]]; then
        echo "Error: Could not resolve one or both domain names to IP addresses."
        exit 1
    fi

    echo "REMOTE_IP=$remote_ip" >> /etc/tunnel_env
    echo "LOCAL_IP=$local_ip" >> /etc/tunnel_env

    # تنظیم تونل 6to4 و GRE
    echo "Setting up tunnels for network: $network_name"
    ip link delete ${network_name}_6To4 2>/dev/null
    ip link delete ${network_name}_GRE 2>/dev/null

    # ایجاد تونل 6to4
    ip tunnel add ${network_name}_6To4 mode sit remote "$remote_ip" local "$local_ip"
    ip -6 addr add "$local_ipv6" dev ${network_name}_6To4
    ip link set ${network_name}_6To4 up
    echo "6to4 tunnel setup completed for $network_name."

    # ایجاد تونل GRE
    ip -6 tunnel add ${network_name}_GRE mode ip6gre remote "$remote_ipv6" local "$local_ipv6"
    ip addr add "$local_ipv4"/30 dev ${network_name}_GRE
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

# تابع برای ویرایش تونل موجود
edit_tunnel() {
    echo "Editing an existing tunnel..."

    # دریافت نام شبکه با اعتبارسنجی
    while true; do
        read -p "Enter the name of the tunnel you want to edit: " network_name
        if [[ "$network_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            echo "Invalid network name. Please enter a valid network name."
        fi
    done

    # بررسی اینکه آیا شبکه با این نام وجود دارد یا خیر
    if ! ip link show | grep -q "$network_name"; then
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

# تابع برای نصب iptables و فوروارد پورت
install_iptables_and_forward_port() {
    echo "Installing iptables and forwarding a port..."

    # نصب iptables
    sudo apt-get update
    sudo apt-get install -y iptables ip6tables

    # دریافت اطلاعات فوروارد پورت
    while true; do
        read -p "Enter the port you want to forward: " port
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Invalid port number. Please enter a valid port number."
        fi
    done

    while true; do
        read -p "Enter the IPv6 address of the tunnel: " ipv6_address
        if [[ "$ipv6_address" =~ ^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}$ ]]; then
            break
        else
            echo "Invalid IPv6 address. Please enter a valid IPv6 address."
        fi
    done

    # اجرای دستور iptables برای فوروارد پورت
    sudo ip6tables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "[$ipv6_address]:$port"
    sudo ip6tables -t nat -A POSTROUTING -j MASQUERADE

    echo "Port $port has been forwarded to $ipv6_address."
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
            install_iptables_and_forward_port
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
