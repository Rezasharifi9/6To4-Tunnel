#!/bin/bash

# تابع برای تولید آدرس IPv6 منحصر به فرد بر اساس ترکیب نام دامنه‌های مبدا و مقصد
generate_unique_ipv6() {
    local domain_combination="$1$2"
    local hash=$(echo -n "$domain_combination" | md5sum | cut -c1-4)  # بخش اول هش برای آدرس
    echo "ad$hash"  # تولید پیشوند آدرس با استفاده از هش
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

# دریافت نام شبکه با اعتبارسنجی
while true; do
    read -p "Enter network name: " network_name
    if validate_network_name "$network_name"; then
        break
    fi
done

# تعیین نوع سرور (ایران یا خارج)
while true; do
    read -p "Is this server in Iran (1) or Kharej (2)? " server_location

    if [[ "$server_location" -eq 1 ]]; then
        local_ipv6_suffix="::1"
        remote_ipv6_suffix="::2"
        break
    elif [[ "$server_location" -eq 2 ]]; then
        local_ipv6_suffix="::2"
        remote_ipv6_suffix="::1"
        break
    else
        echo "Invalid input! Please enter 1 for Iran or 2 for Kharej."
    fi
done

# دریافت دامنه‌های Remote با اعتبارسنجی
while true; do
    if [[ "$server_location" -eq 1 ]]; then
        read -p "Enter the domain of the Kharej server (Remote IP for 6to4 tunnel): " remote_domain
        if validate_domain "$remote_domain"; then
            break
        fi
    elif [[ "$server_location" -eq 2 ]]; then
        read -p "Enter the domain of the Iran server (Remote IP for 6to4 tunnel): " remote_domain
        if validate_domain "$remote_domain"; then
            break
        fi
    fi
done

# دریافت دامنه‌های Local با اعتبارسنجی
while true; do
    if [[ "$server_location" -eq 1 ]]; then
        read -p "Enter the domain of the Iran server (Local IP for 6to4 tunnel): " local_domain
        if validate_domain "$local_domain"; then
            break
        fi
    elif [[ "$server_location" -eq 2 ]]; then
        read -p "Enter the domain of the Kharej server (Local IP for 6to4 tunnel): " local_domain
        if validate_domain "$local_domain"; then
            break
        fi
    fi
done

# تولید آدرس‌های IPv6 منحصر به فرد بر اساس ترکیب دامنه‌های مبدا و مقصد
local_ipv6_6to4=$(generate_unique_ipv6 "$local_domain" "$remote_domain$local_ipv6_suffix")
remote_ipv6_gre=$(generate_unique_ipv6 "$remote_domain" "$local_domain$remote_ipv6_suffix")

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
    echo "remote_ipv6_gre=\$(dig +short $remote_domain)"
    echo "local_ipv6_6to4=\$(dig +short $local_domain)"
    echo "ip -6 tunnel add ${network_name}_GRE mode ip6gre remote \$remote_ipv6_gre local \$local_ipv6_6to4"
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
chmod +x /etc/rc.local

echo "The tunnels have been configured and saved in /etc/rc.local for persistence after reboot."
