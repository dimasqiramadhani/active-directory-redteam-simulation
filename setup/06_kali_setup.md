# 🐉 Step 6: Setup Kali Linux (Mesin Penyerang)

## Tujuan

Mengkonfigurasi Kali Linux sebagai mesin penyerang dan menginstal tool red team yang diperlukan untuk menguji lab Active Directory.

---

## 6.1 Membuat VM

| Parameter | Nilai |
|-----------|-------|
| Name | KALI |
| OS | Kali Linux (latest) |
| RAM | 2 GB (4 GB jika tersedia) |
| CPU | 2 vCPU |
| Disk | 30 GB |
| Network | Host-Only (vboxnet0 / VMnet2) |

**Rekomendasi:** Download pre-built VM image dari [kali.org/get-kali](https://www.kali.org/get-kali/) (tersedia untuk VirtualBox dan VMware).

---

## 6.2 Konfigurasi IP Static

Edit file konfigurasi jaringan:

```bash
sudo nano /etc/network/interfaces
```

Tambahkan/edit:

```
auto eth0
iface eth0 inet static
    address 192.168.56.40
    netmask 255.255.255.0
    dns-nameservers 192.168.56.10 192.168.56.11
```

Restart networking:

```bash
sudo systemctl restart networking
# atau
sudo ifdown eth0 && sudo ifup eth0
```

Alternatif — jika menggunakan NetworkManager:

```bash
# Cek nama interface
ip link show

# Konfigurasi via nmcli
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.56.40/24
sudo nmcli con mod "Wired connection 1" ipv4.dns "192.168.56.10 192.168.56.11"
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con up "Wired connection 1"
```

---

## 6.3 Konfigurasi DNS

Pastikan DNS menunjuk ke DC1:

```bash
# Edit resolv.conf
echo "nameserver 192.168.56.10" | sudo tee /etc/resolv.conf
echo "nameserver 192.168.56.11" | sudo tee -a /etc/resolv.conf
```

Verifikasi:

```bash
nslookup corp.local
dig @192.168.56.10 corp.local
ping -c 3 dc1.corp.local
```

---

## 6.4 Verifikasi Konektivitas

```bash
# Ping semua target
ping -c 2 192.168.56.10   # DC1
ping -c 2 192.168.56.11   # DC2
ping -c 2 192.168.56.20   # FILESRV
ping -c 2 192.168.56.30   # CLIENT01

# Test DNS resolution
nslookup dc1.corp.local
nslookup filesrv.corp.local

# Test port connectivity
nmap -Pn -p 445,389,88,135,5985 192.168.56.10
```

---

## 6.5 Instalasi Tool Red Team

### Tool Bawaan Kali (Biasanya Sudah Terinstal)

```bash
# Update Kali
sudo apt update && sudo apt upgrade -y

# Verifikasi tool bawaan
which nmap
which smbclient
which ldapsearch
which responder
which crackmapexec
which evil-winrm
which impacket-secretsdump
```

### Instal Tool Tambahan

```bash
# Impacket (jika belum terinstal atau mau versi terbaru)
sudo apt install python3-impacket impacket-scripts -y

# CrackMapExec / NetExec
sudo apt install crackmapexec -y
# Atau versi terbaru (NetExec)
pip3 install netexec

# Evil-WinRM
sudo apt install evil-winrm -y

# Responder
sudo apt install responder -y

# enum4linux
sudo apt install enum4linux -y
# Versi modern:
sudo apt install enum4linux-ng -y

# BloodHound
sudo apt install bloodhound -y

# Rubeus dan SharpHound (binary Windows, jalankan di target)
# Download dari GitHub:
mkdir -p ~/tools/windows
cd ~/tools/windows
# SharpHound: https://github.com/BloodHoundAD/SharpHound/releases
# Rubeus: https://github.com/GhostPack/Rubeus (perlu compile)

# Mimikatz (binary Windows)
# Download dari: https://github.com/gentilkiwi/mimikatz/releases
# Simpan di ~/tools/windows/

# kerbrute (brute force Kerberos)
sudo apt install kerbrute -y
# Atau download binary:
# https://github.com/ropnop/kerbrute/releases

# ldapdomaindump
pip3 install ldapdomaindump

# Chisel (untuk tunneling)
# https://github.com/jpillora/chisel/releases
```

### Setup BloodHound

```bash
# Start neo4j database (dibutuhkan BloodHound)
sudo neo4j start

# Akses neo4j browser di: http://localhost:7474
# Default credentials: neo4j / neo4j (ganti saat pertama login)

# Jalankan BloodHound
bloodhound
# Login dengan credential neo4j yang sudah diubah
```

---

## 6.6 Organisasi Folder Kerja

Buat struktur folder yang rapi untuk engagement:

```bash
mkdir -p ~/redteam/{recon,loot,exploits,notes,tools}

# recon/    → hasil scanning dan enumerasi
# loot/     → credentials, hashes, data yang ditemukan
# exploits/ → script dan payload
# notes/    → catatan dan dokumentasi
# tools/    → tool tambahan
```

---

## Referensi Tool

| Tool | Fungsi | Fase Serangan |
|------|--------|---------------|
| **nmap** | Network scanning dan port discovery | Reconnaissance |
| **enum4linux** | Enumerasi SMB, NetBIOS, user, share | Enumeration |
| **ldapsearch** | Enumerasi LDAP (users, groups, OU) | Enumeration |
| **smbclient** | Akses SMB share, download file | Enumeration |
| **Responder** | LLMNR/NBT-NS poisoning, credential capture | Credential Access |
| **CrackMapExec** | Swiss army knife: spraying, exec, enum | Multi-phase |
| **Impacket** | GetNPUsers, GetUserSPNs, secretsdump, psexec, dll. | Multi-phase |
| **kerbrute** | Kerberos user enum dan password spraying | Credential Access |
| **BloodHound** | Visualisasi attack path Active Directory | Analysis |
| **SharpHound** | Collector data AD untuk BloodHound (jalankan di target) | Enumeration |
| **Mimikatz** | Credential dumping (jalankan di target Windows) | Credential Access |
| **Rubeus** | Kerberos attacks (jalankan di target Windows) | Credential Access |
| **Evil-WinRM** | Remote shell via WinRM protocol | Lateral Movement |
