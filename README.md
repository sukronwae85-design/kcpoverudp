Untuk auto install script dari GitHub Anda, gunakan perintah ini:
🚀 AUTO INSTALL COMMAND
bash

# Method 1: Direct download & execute
wget -O install.sh https://raw.githubusercontent.com/sukronwae85-design/kcpoverudp/main/install.sh && chmod +x install.sh && sudo ./install.sh

📥 ALTERNATIVE COMMANDS:
Method 2: Using curl
bash

curl -o install.sh https://raw.githubusercontent.com/sukronwae85-design/kcpoverudp/main/install.sh && chmod +x install.sh && sudo ./install.sh

Method 3: One-liner langsung execute
bash

bash <(curl -s https://raw.githubusercontent.com/sukronwae85-design/kcpoverudp/main/install.sh)

Method 4: Dengan git clone (jika repo private)
bash

git clone https://github.com/sukronwae85-design/kcpoverudp.git
cd kcpoverudp
chmod +x install.sh
sudo ./install.sh

⚠️ PERHATIAN SEBELUM INSTALL:

Pastikan file Anda sudah di-upload dengan struktur yang benar:
Struktur GitHub yang diperlukan:
text

kcpoverudp/
├── install.sh          (File utama)
├── README.md           (Optional)
└── config/             (Optional - jika ada file tambahan)

🔧 UPDATE SCRIPT ANDA UNTUK FIX BUGS:

Saya lihat script Anda ada beberapa yang perlu diperbaiki:
Perbaikan di akhir file:
bash

# Ganti ini:
main "$@"      file di atas sudah saya upload si github saya ini https://github.com/sukronwae85-design/kcpoverudp/upload  bagaimana perintah untuk auto instal di vps ubuntu nya ya

# Menjadi ini:
main "$@"

Atau buat file baru dengan fix berikut:
bash

#!/bin/bash
# ... [script lengkap Anda] ...

# Main Installation
main() {
    show_banner
    install_dependencies
    setup_timezone
    setup_ssh
    setup_kcptun
    setup_firewall
    create_user_management
    setup_bandwidth_monitor
    setup_auto_backup
    setup_login_control
    final_setup
    show_usage
}

# Run main function
main "$@"

📋 LANGKAH-LANGKAH INSTALL:

   Login ke VPS Ubuntu Anda

   Jalankan perintah install:
    bash

wget -O install.sh https://raw.githubusercontent.com/sukronwae85-design/kcpoverudp/main/install.sh && chmod +x install.sh && sudo ./install.sh

Tunggu hingga proses selesai

Setelah install, gunakan commands:
bash

ssh-manager          # Kelola user
bw-monitor           # Monitor bandwidth
generate-client-config # Config untuk client

🛠 TROUBLESHOOTING:
Jika error "404 Not Found":

    Pastikan file sudah di-upload ke branch main

  Pastikan nama file install.sh tepat

  Cek URL di browser: https://raw.githubusercontent.com/sukronwae85-design/kcpoverudp/main/install.sh

Jika error permission denied:
bash

chmod +x install.sh
sudo ./install.sh

Jika repo private:
bash

# Ganti dengan raw link yang benar dari GitHub

✅ TEST SETELAH INSTALL:
bash

# Cek service berjalan
systemctl status kcptun
systemctl status ssh

# Test port UDP
nc -u localhost 4000

# Generate client config
generate-client-config

🎯 FITUR YANG AKAN TERINSTALL:

   ✅ KCP over UDP di port 4000

   ✅ User management (ssh-manager)

  ✅ Bandwidth monitoring (bw-monitor)

   ✅ Auto backup system

   ✅ Login control & security

  ✅ Firewall configuration

Jalankan perintah di atas dan script akan auto install lengkap! 🚀
