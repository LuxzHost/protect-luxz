#!/bin/bash

# ==============================================
# ULTIMATE SUPER SHIELD - ULTRA SECURE (UPGRADED)
# ==============================================
# Author: Shield Security Team
# ==============================================

# Load config
if [ ! -f ./config.txt ]; then
    echo "❌ config.txt tidak ditemukan!"
    exit 1
fi

source ./config.txt

# 1️⃣ Setup SSH key and disable password
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if ! grep -q "$PUBLIC_KEY" ~/.ssh/authorized_keys; then
    echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
    echo "✅ SSH public key terpasang"
fi
chmod 600 ~/.ssh/authorized_keys

# Disable root password login
sudo passwd -l root
sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload sshd

# 2️⃣ Block metadata cloud
iptables -A OUTPUT -d 169.254.169.254 -j DROP

# 3️⃣ Firewall & rate limit
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 5 -j DROP

# 4️⃣ Protect sensitive files
chmod 600 /etc/shadow /root/.bash_history /var/www/pterodactyl/.env
chown root:root /etc/shadow /root/.bash_history /var/www/pterodactyl/.env

# 5️⃣ Monitor & block suspicious access
inotifywait -m -e open /etc/shadow /root/.bash_history /var/www/pterodactyl/.env | while read path action file; do
    PID=$(lsof $path | awk 'NR>1 {print $2}')
    IP=$(lsof -i -a -p $PID | awk 'NR>1 {print $9}' | cut -d':' -f1)
    echo "⚠️ Percobaan akses mencurigakan: $file dari PID $PID, IP $IP"
    iptables -A INPUT -s $IP -j DROP
    kill -9 $PID
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="⚠️ ALERT! Script jahat terdeteksi dari IP: $IP → diblok!"
done &

# 6️⃣ Background anti-DDOS ringan
while true; do
    sleep 300
    conntrack -F 2>/dev/null
    echo "🛡️ Proteksi DDOS refresh"
done &

# 7️⃣ Fail2Ban install (opsional tapi lebih aman)
if ! command -v fail2ban-server >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y fail2ban
    sudo systemctl enable fail2ban --now
    echo "✅ Fail2Ban aktif"
fi

# 8️⃣ Notification on startup
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ Ultimate Super Shield aktif di VPS $(hostname)! Proteksi full berjalan."

# 9️⃣ Run shield service
echo "🛡️ Ultimate Super Shield aktif! Proteksi berjalan di background."

exit 0
