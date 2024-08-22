#!/bin/bash

# تابع برای اعتبارسنجی آدرس IPv6
validate_ipv6() {
    local ipv6="$1"
    if [[ "$ipv6" =~ ^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}(/[0-9]{1,3})?$ ]]; then
        return 0
    else
        echo "Invalid IPv6 address. Please enter a valid IPv6 address."
        return 1
    fi
}

# تابع برای افزودن تونل جدید و تنظیم روی سیستم
add_tunnel() {
    echo "Adding a new tunnel..."

    # دریافت نام شبکه با اعتبارسنجی
    while true; do
        read -p "Enter network name: " network_name
        if [[ "$network_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            echo "Invalid network name. Please enter a valid network name."
        fi
    done

    # بررسی و حذف تونل‌های قدیمی با همین نام
    if ip link show | grep -q "$network_name"; then
        ip link delete "${network_name}_6To4" 2>/dev/null
        ip link delete "${network_name}_GRE" 2>/dev/null
    fi

    # دریافت آدرس‌های IPv6 از کاربر
    while true; do
        read -p "Enter the IPv6 address for the Iranian server (with /64 suffix): " local_ipv6_6to4
        if validate_ipv6 "$local_ipv6_6to4"; then
            break
        fi
    done

    while true; do
        read -p "Enter the IPv6 address for the foreign server (with /64 suffix): " remote_ipv6_gre
        if validate_ipv6 "$remote_ipv6_gre"; then
            break
        fi
    done

    # تنظیم تونل 6to4 روی شبکه سیستم
    echo "Creating 6to4 tunnel..."
    ip tunnel add ${network_name}_6To4 mode sit remote "$remote_ipv6_gre" local "$local_ipv6_6to4"
    ip -6 addr add "$local_ipv6_6to4" dev "${network_name}_6To4"
    ip link set "${network_name}_6To4" up

    # تنظیم تونل GRE روی شبکه سیستم
    echo "Creating GRE tunnel..."
    ip -6 tunnel add ${network_name}_GRE mode ip6gre remote "$remote_ipv6_gre" local "$local_ipv6_6to4"
    ip addr add 172.20.1.$((RANDOM % 254 + 1))/30 dev "${network_name}_GRE"
    ip link set "${network_name}_GRE" up

    # اضافه کردن تنظیمات به rc.local
    if [[ -f /etc/rc.local ]]; then
        echo "Found existing /etc/rc.local file. Appending tunnel configuration."
    else
        echo "No /etc/rc.local found. Creating new /etc/rc.local file."
        echo "#!/bin/bash" > /etc/rc.local
        echo "" >> /etc/rc.local
    fi

    {
        echo "# Adding and configuring 6to4 tunnel for $network_name"
        echo "ip tunnel add ${network_name}_6To4 mode sit remote $remote_ipv6_gre local $local_ipv6_6to4"
        echo "ip -6 addr add $local_ipv6_6to4 dev ${network_name}_6To4"
        echo "ip link set ${network_name}_6To4 up"
        echo ""
        echo "# Configuring GRE6 or IPIPv6 tunnel for $network_name"
        echo "ip -6 tunnel add ${network_name}_GRE mode ip6gre remote $remote_ipv6_gre local $local_ipv6_6to4"
        echo "ip addr add 172.20.1.$((RANDOM % 254 + 1))/30 dev ${network_name}_GRE"
        echo "ip link set ${network_name}_GRE up"
        echo "# End of $network_name tunnel configuration"
    } >> /etc/rc.local

    # بررسی وجود exit 0 در /etc/rc.local و افزودن آن در صورت عدم وجود
    if ! grep -q "exit 0" /etc/rc.local; then
        echo "exit 0" >> /etc/rc.local
    fi

    # دادن مجوز اجرایی به فایل /etc/rc.local
    chmod +x /etc/rc.local

    # چاپ آدرس‌های IPv6 تنظیم‌شده برای کاربر
    echo "IPv6 address for Iranian server: $local_ipv6_6to4"
    echo "IPv6 address for foreign server: $remote_ipv6_gre"

    echo "The tunnels have been configured and saved in /etc/rc.local for persistence after reboot."
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
        if validate_ipv6 "$ipv6_address"; then
            break
        fi
    done
    
    # اجرای دستور iptables برای فوروارد پورت
    sudo ip6tables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "[$ipv6_address]:$port"
    sudo ip6tables -t nat -A POSTROUTING -j MASQUERADE
    
    echo "Port $port has been forwarded to $ipv6_address."
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

    # حذف تنظیمات مرتبط از /etc/rc.local
    if [[ -f /etc/rc.local ]]; then
        echo "Cleaning up /etc/rc.local..."
        sed -i "/# Adding and configuring 6to4 tunnel for $network_name/,/# End of $network_name tunnel configuration/d" /etc/rc.local
    fi

    # فراخوانی تابع add_tunnel برای ایجاد تونل جدید با اطلاعات جدید
    add_tunnel
}

# نمایش منوی اصلی و اجرای انتخاب کاربر
while true; do
    echo "============================================"
    echo " Welcome to the Tunnel Configuration Script "
    echo "============================================"
    echo "Please select an option:"
    echo "1. Add a new tunnel"
    echo "2. Edit an existing tunnel"
    echo "3. Install iptables and forward a port"
    echo "4. Exit"
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
