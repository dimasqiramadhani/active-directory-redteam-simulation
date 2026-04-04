# 🌐 Step 1: Konfigurasi Jaringan Virtual

## Tujuan

Membuat jaringan virtual terisolasi (Host-Only Network) di hypervisor agar semua VM dapat berkomunikasi satu sama lain tanpa akses ke internet atau jaringan luar.

---

## VirtualBox

### 1.1 Buat Host-Only Network

1. Buka **VirtualBox** → menu **File** → **Host Network Manager** (atau **Tools → Network**)
2. Klik **Create** untuk membuat adapter baru
3. Konfigurasi adapter:
   - **Name:** `vboxnet0` (biasanya otomatis)
   - **IPv4 Address:** `192.168.56.1`
   - **IPv4 Network Mask:** `255.255.255.0`
4. Tab **DHCP Server** → **Uncheck** "Enable Server" (DHCP harus dimatikan karena kita pakai static IP)
5. Klik **Apply**

### 1.2 Assign Network ke Setiap VM

Untuk setiap VM yang akan dibuat:

1. Klik kanan pada VM → **Settings** → **Network**
2. **Adapter 1:**
   - **Enable Network Adapter:** ✅
   - **Attached to:** `Host-only Adapter`
   - **Name:** `vboxnet0`
   - **Adapter Type:** `Intel PRO/1000 MT Desktop` (default)
   - **Promiscuous Mode:** `Allow All` (penting untuk Responder dan sniffing)
3. Klik **OK**

### 1.3 (Opsional) Adapter Kedua untuk Internet Sementara

Saat instalasi awal, kamu mungkin butuh internet untuk download update atau tool. Tambahkan adapter kedua **sementara**:

1. **Adapter 2:**
   - **Attached to:** `NAT`
   - Gunakan untuk download, lalu **disable** setelah selesai

**PENTING:** Setelah semua instalasi selesai, pastikan hanya Adapter 1 (Host-Only) yang aktif. Matikan NAT adapter agar lab benar-benar terisolasi.

---

## VMware Workstation

### 1.1 Buat Custom Virtual Network

1. Buka **VMware Workstation** → menu **Edit** → **Virtual Network Editor**
2. Klik **Change Settings** (butuh hak admin)
3. Klik **Add Network** → pilih **VMnet2** (atau nomor lain yang tersedia)
4. Konfigurasi:
   - **Type:** `Host-only`
   - **Subnet IP:** `192.168.56.0`
   - **Subnet mask:** `255.255.255.0`
5. **Uncheck** "Use local DHCP service to distribute IP addresses"
6. Klik **Apply** → **OK**

### 1.2 Assign Network ke Setiap VM

Untuk setiap VM:

1. Klik kanan pada VM → **Settings** → **Network Adapter**
2. Pilih **Custom: Specific virtual network**
3. Pilih **VMnet2** (atau network yang baru dibuat)
4. Klik **OK**

---

## Verifikasi Jaringan

Setelah semua VM terinstal dan dikonfigurasi IP static:

### Dari setiap VM Windows, jalankan:

```powershell
# Cek konfigurasi IP
ipconfig /all

# Ping ke DC1
ping 192.168.56.10

# Ping ke semua host
ping 192.168.56.11
ping 192.168.56.20
ping 192.168.56.30
ping 192.168.56.40
```

### Dari Kali Linux:

```bash
# Cek konfigurasi IP
ip addr show

# Ping ke semua host
ping -c 3 192.168.56.10
ping -c 3 192.168.56.11
ping -c 3 192.168.56.20
ping -c 3 192.168.56.30
```

---

## Troubleshooting

### VM tidak bisa ping satu sama lain

1. Pastikan semua VM menggunakan adapter jaringan yang sama (vboxnet0 / VMnet2)
2. Cek apakah IP sudah dikonfigurasi static dengan benar
3. Cek Windows Firewall — untuk sementara, bisa disable atau buat rule untuk allow ICMP:

```powershell
# Jalankan di PowerShell (sebagai Administrator) di setiap VM Windows
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Action Allow
```

### Kali tidak bisa ping VM Windows

Windows Firewall secara default memblok ICMP (ping). Buka firewall rule:

```powershell
# Di setiap VM Windows
netsh advfirewall firewall add rule name="Allow Ping" protocol=icmpv4 dir=in action=allow
```

### Network adapter tidak muncul di VM

1. Pastikan VM sudah dimatikan saat mengubah network settings
2. Coba ubah adapter type ke `Intel PRO/1000 MT Desktop`
3. Re-install VirtualBox Guest Additions (untuk VirtualBox)
