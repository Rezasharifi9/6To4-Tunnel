#!/bin/bash

# دریافت نام شبکه از کاربر
read -p "Enter network name: " network_name

# بررسی اینکه آیا شبکه با این نام از قبل وجود دارد یا خیر
if ip link show | grep -q "$network_name"; then
    echo "Warning: The network '$network_name' already exists."
    read -p "If you continue, this network will be deleted and replaced with a new configuration. Do you want to continue? (yes/no): " confirm_replace

    if [[ "$confirm_replace" != "yes" ]]; then
        echo "Operation aborted."
        exit 0
    fi

    # حذف شبکه‌های قبلی با این نام
    ip link delete $network_name"_6To4" 2>/dev/null
    ip link delete $network_name"_GRE" 2>/dev/null
    echo "Previous network '$network_name' has been deleted."
fi

# تعیین نوع سرور (ایران یا خارج)
read -p "Is this server in Iran (1) or Abroad (2)? " server_location

# بررسی ورودی کاربر برای تعیین سرور داخلی یا خارجی و پیام مربوطه برای Remote IP و Local IP
if [ "$server_location" -eq 1 ]; then
    local_ipv6_suffix="::1"
    remote_ipv6_suffix="::2"
    read -p "Enter the IP address of the foreign server (Remote IP for 6to4 tunnel): " remote_ip
    read -p "Enter the IP address of the Iranian server (Local IP for 6to4 tunnel): " local_ip
elif [ "$server_location" -eq 2 ]; then
    local_ipv6_suffix="::2"
    remote_ipv6_suffix="::1"
    read -p "Enter the IP address of the Iranian server (Remote IP for 6to4 tunnel): " remote_ip
    read -p "Enter the IP address of the foreign server (Local IP for 6to4 tunnel): " local_ip
else
    echo "Invalid input! Please enter 1 for Iran or 2 for Abroad."
    exit 1
fi

# تابع بررسی آدرس IPv6 در شبکه و تولید آدرس صحیح برای Local IPv6
generate_local_ipv6() {
    base_prefix="ad11"
    while true; do
        local_ipv6="${base_prefix}${local_ipv6_suffix}"
        # بررسی اینکه آیا آدرس در شبکه موجود است
        if ! ip -6 addr | grep -q "$local_ipv6"; then
            echo "$local_ipv6"
            return
        else
            # اگر آدرس وجود دارد، به ad بعدی بروید
            base_prefix="ad$((10 + ${base_prefix:2} + 1))"
        fi
    done
}

# تابع تولید Remote IPv6 مرتبط با Local IPv6
generate_remote_ipv6() {
    local base_prefix=$1
    echo "${base_prefix}${remote_ipv6_suffix}"
}

# تولید Local IPv6 و Remote IPv6
local_ipv6_6to4=$(generate_local_ipv6)
remote_ipv6_gre=$(generate_remote_ipv6 ${local_ipv6_6to4%::*})

# تابع تولید آدرس IPv4 تصادفی در بازه 172.20.1.0/24
generate_ipv4() {
    echo "172.20.1.$((RANDOM % 254 + 1))"
}

# تولید آدرس IPv4 تصادفی برای تونل GRE
local_ipv4_gre=$(generate_ipv4)

# ایجاد تونل 6to4 با نام ورودی از کاربر
tunnel_name_6to4="${network_name}_6To4"
ip tunnel add $tunnel_name_6to4 mode sit remote $remote_ip local $local_ip
ip -6 addr add $local_ipv6_6to4/64 dev $tunnel_name_6to4
ip link set $tunnel_name_6to4 mtu 1480
ip link set $tunnel_name_6to4 up

# ایجاد تونل GRE6 با نام ورودی از کاربر
tunnel_name_gre6="${network_name}_GRE"
ip -6 tunnel add $tunnel_name_gre6 mode ip6gre remote $remote_ipv6_gre local $local_ipv6_6to4
ip addr add $local_ipv4_gre/30 dev $tunnel_name_gre6
ip link set $tunnel_name_gre6 mtu 1436
ip link set $tunnel_name_gre6 up

# بررسی اینکه آیا فایل /etc/rc.local وجود دارد یا خیر
if [ -f /etc/rc.local ]; then
    echo "Found existing /etc/rc.local file. Appending tunnel configuration."
else
    echo "No /etc/rc.local found. Creating new /etc/rc.local file."
    echo "#!/bin/bash" > /etc/rc.local
    echo "" >> /etc/rc.local
fi

# اضافه کردن دستورات تونل به انتهای فایل /etc/rc.local
echo "# Adding and configuring 6to4 tunnel" >> /etc/rc.local
echo "ip tunnel add $tunnel_name_6to4 mode sit remote $remote_ip local $local_ip" >> /etc/rc.local
echo "ip -6 addr add $local_ipv6_6to4/64 dev $tunnel_name_6to4" >> /etc/rc.local
echo "ip link set $tunnel_name_6to4 mtu 1480" >> /etc/rc.local
echo "ip link set $tunnel_name_6to4 up" >> /etc/rc.local
echo "" >> /etc/rc.local

echo "# Configuring GRE6 or IPIPv6 tunnel" >> /etc/rc.local
echo "ip -6 tunnel add $tunnel_name_gre6 mode ip6gre remote $remote_ipv6_gre local $local_ipv6_6to4" >> /etc/rc.local
echo "ip addr add $local_ipv4_gre/30 dev $tunnel_name_gre6" >> /etc/rc.local
echo "ip link set $tunnel_name_gre6 mtu 1436" >> /etc/rc.local
echo "ip link set $tunnel_name_gre6 up" >> /etc/rc.local
echo "" >> /etc/rc.local

# بررسی وجود exit 0 در /etc/rc.local و افزودن آن در صورت عدم وجود
if ! grep -q "exit 0" /etc/rc.local; then
    echo "exit 0" >> /etc/rc.local
fi

# دادن مجوز اجرایی به فایل /etc/rc.local
chmod +x /etc/rc.local

echo "The tunnels have been configured and saved in /etc/rc.local for persistence after reboot."
