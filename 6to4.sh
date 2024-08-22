#!/bin/bash

# تابع برای نمایش Intro
show_intro() {
    echo "============================================"
    echo " Welcome to the Tunnel Configuration Script "
    echo "============================================"
    echo "Please select an option:"
    echo "1. Add a new tunnel"
    echo "2. Edit an existing tunnel"
    echo "3. Install iptables and forward a port"
    echo "4. Exit"
}

# تابع برای اعتبارسنجی نام شبکه
validate_network_name() {
    local network_name="$1"
    if [[ "$network_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; then
        return 0
    else
        echo "Invalid network name. Please enter a valid network name (letters, numbers, hyphens, and no spaces)."
        return 1
    fi
}

# تابع برای اعتبارسنجی آدرس IPv6
validate_ipv6() {
    local ipv6="$1"
    if [[ "$ipv6" =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ ]]; then
        return 0
    else
        echo "Invalid IPv6 address. Please enter a valid IPv6 address."
        return 1
    fi
}

# تابع برای اعتبارسنجی دامنه
validate_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        echo "Invalid domain. Please enter a valid domain."
        return 1
    fi
}

# تابع برای افزودن تونل جدید
add_tunnel() {
    echo "Adding a new tunnel..."
    
    # دریافت نام شبکه با اعتبارسنجی
    while true; do
        read -p "Enter network name: " network_name
        if validate_network_name "$network_name"; then
            break
        fi
    done
    
    # بررسی اینکه آیا شبکه با این نام از قبل وجود دارد یا خیر
    if ip link show | grep -q "$network_name"; then
        echo "Warning: The network '$network_name' already exists."
        read -p "If you continue, this network will be deleted and replaced with a new configuration. Do you want to continue? (yes/no): " confirm_replace

        if [[ "$confirm_replace" == "yes" ]]; then
            # حذف شبکه‌های قبلی با این نام
            ip link delete ${network_name}_6To4 2>/dev/null
            ip link delete ${network_name}_GRE 2>/dev/null
            echo "Previous network '$network_name' has been deleted."

            # حذف تنظیمات مرتبط از /etc/rc.local
            if [[ -f /etc/rc.local ]]; then
                echo "Cleaning up /etc/rc.local..."
                sed -i "/# Adding and configuring 6to4 tunnel for $network_name/,/# End of $network_name tunnel configuration/d" /etc/rc.local
            fi
        else
            echo "Operation aborted."
            return
        fi
    fi
    
    # تعیین نوع سرور (ایران یا خارج)
    while true; do
        read -p "Is this server in Iran (1) or Abroad (2)? " server_location

        if [[ "$server_location" -eq 1 ]]; then
            local_ipv6_suffix="::1"
            remote_ipv6_suffix="::2"
            break
        elif [[ "$server_location" -eq 2 ]]; then
            local_ipv6_suffix="::2"
            remote_ipv6_suffix="::1"
            break
        else
            echo "Invalid input! Please enter 1 for Iran or 2 for Abroad."
        fi
    done

    # دریافت دامنه‌های Remote با اعتبارسنجی
    while true; do
        if [[ "$server_location" -eq 1 ]]; then
            read -p "Enter the domain of the foreign server (Remote IP for 6to4 tunnel): " remote_domain
            if validate_domain "$remote_domain"; then
                break
            fi
        elif [[ "$server_location" -eq 2 ]]; then
            read -p "Enter the domain of the Iranian server (Remote IP for 6to4 tunnel): " remote_domain
            if validate_domain "$remote_domain"; then
                break
            fi
        fi
    done

    # دریافت دامنه‌های Local با اعتبارسنجی
    while true; do
        if [[ "$server_location" -eq 1 ]]; then
            read -p "Enter the domain of the Iranian server (Local IP for 6to4 tunnel): " local_domain
            if validate_domain "$local_domain"; then
                break
            fi
        elif [[ "$server_location" -eq 2 ]]; then
            read -p "Enter the domain of the foreign server (Local IP for 6to4 tunnel): " local_domain
            if validate_domain "$local_domain"; then
                break
            fi
        fi
    done

    # سوال از کاربر: آیا می‌خواهید آدرس‌های IPv6 را خودتان وارد کنید؟
    read -p "Do you want to manually enter the IPv6 addresses? (yes/no): " manual_ipv6

    if [[ "$manual_ipv6" == "yes" ]]; then
        # دریافت آدرس‌های IPv6 از کاربر
        while true; do
            read -p "Enter the IPv6 address for the Iranian server: " local_ipv6_6to4
            if validate_ipv6 "$local_ipv6_6to4"; then
                break
            fi
        done

        while true; do
            read -p "Enter the IPv6 address for the foreign server: " remote_ipv6_gre
            if validate_ipv6 "$remote_ipv6_gre"; then
                break
            fi
        done
    else
        # استفاده از آدرس‌های ثابت IPv6
        local_ipv6_6to4="2001:db8:ad11::1"
        remote_ipv6_gre="2001:db8:ad11::2"
        echo "Using default IPv6 addresses: $local_ipv6_6to4 for Iran and $remote_ipv6_gre for abroad."
    fi

    # اضافه کردن دستورات دامنه و ترجمه به IP به /etc/rc.local
    if [[ -f /etc/rc.local ]]; then
        echo "Found existing /etc/rc.local file. Appending tunnel configuration."
    else
        echo "No /etc/rc.local found. Creating new /etc/rc.local file."
        echo "#!/bin/bash" > /etc/rc.local
        echo "" >> /etc/rc.local
    fi

    # اضافه کردن دستورات ترجمه دامنه به IP و تونل به انتهای فایل /etc/rc.local
    {
        echo "# Adding and configuring 6to4 tunnel for $network_name"
        echo "remote_ip=\$(dig +short $remote_domain)"
        echo "local_ip=\$(dig +short $local_domain)"
        echo "ip tunnel add ${network_name}_6To4 mode sit remote \$remote_ip local \$local_ip"
        echo "ip -6 addr add ${local_ipv6_6to4}/64 dev ${network_name}_6To4"
        echo "ip link set ${network_name}_6To4 mtu 1480"
        echo "ip link set ${network_name}_6To4 up"
        echo ""
        echo "# Configuring GRE6 or IPIPv6 tunnel for $network_name"
        echo "ip -6 tunnel add ${network_name}_GRE mode ip6gre remote ${remote_ipv6_gre} local ${local_ipv6_6to4}"
        echo "ip addr add 172.20.1.$((RANDOM % 254 + 1))/30 dev ${network_name}_GRE"
        echo "ip link set ${network_name}_GRE mtu 1436"
        echo "ip link set ${network_name}_GRE up"
        echo ""
        echo "# End of $network_name tunnel configuration"
    } >> /etc/rc.local

    # بررسی وجود exit 0 در /etc/rc.local و افزودن آن در صورت عدم وجود
    if ! grep -q "exit 0" /etc/rc.local; then
        echo "exit 0" >> /etc/rc.local
    fi

    # دادن مجوز اجرایی به فایل /etc/rc.local
```bash
    chmod +x /etc/rc.local

    # چاپ آدرس‌های IPv6 تنظیم‌شده برای کاربر
    echo "IPv6 address for Iranian server: $local_ipv6_6to4"
    echo "IPv6 address for foreign server: $remote_ipv6_gre"

    echo "The tunnels have been configured and saved in /etc/rc.local for persistence after reboot."
}

# تابع برای ویرایش تونل موجود
edit_tunnel() {
    echo "Editing an existing tunnel..."
    
    # دریافت نام شبکه با اعتبارسنجی
    while true; do
        read -p "Enter the name of the tunnel you want to edit: " network_name
        if validate_network_name "$network_name"; then
            break
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

# نمایش منوی اصلی و اجرای انتخاب کاربر
while true; do
    show_intro
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
