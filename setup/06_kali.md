# 🐉 Step 6: Setup Kali Linux (Mesin Penyerang)

## Tujuan

Mengkonfigurasi Kali Linux sebagai mesin penyerang dengan dua adapter:
- **eth0** — IP public untuk akses SSH dan internet
- **eth1** — IP private (192.168.56.40) untuk menyerang target lab

---

## 6.1 Membuat VM / Menyiapkan Server

| Parameter | Nilai |
|-----------|-------|
| Name | KALI |
| OS | Kali Linux (latest) |
| RAM | 2 GB (4 GB jika tersedia) |
| CPU | 2 vCPU |
| Disk | 30 GB |
| eth0 | PUBLIC — IP dari ISP/cloud (untuk SSH, internet) |
| eth1 | INTERNAL — Host-Only / private network (untuk lab) |

**Rekomendasi:** Download pre-built VM dari [kali.org/get-kali](https://www.kali.org/get-kali/).

---

## 6.2 Identifikasi Adapter

```bash
ip link show
# atau
ifconfig
```

Biasanya:
- `eth0` = adapter pertama (sudah ada IP public)
- `eth1` = adapter kedua (belum ada IP — ini yang perlu dikonfigurasi)

---

## 6.3 Konfigurasi IP Static di eth1 (Internal)

### Set IP Langsung (Berlaku Sampai Reboot)

```bash
sudo ip addr add 192.168.56.40/24 dev eth1
sudo ip link set eth1 up
```

### Buat Permanen

```bash
sudo nano /etc/network/interfaces
```

Tambahkan di bagian bawah:

```
auto eth1
iface eth1 inet static
    address 192.168.56.40
    netmask 255.255.255.0
    dns-nameservers 192.168.56.10 192.168.56.11
```

**JANGAN tambahkan gateway di eth1** — gateway hanya di eth0 (public).

Simpan (`Ctrl+O`, `Enter`, `Ctrl+X`), lalu aktifkan:

```bash
sudo ifup eth1
```

Alternatif jika menggunakan NetworkManager:

```bash
sudo nmcli con add type ethernet con-name "INTERNAL" ifname eth1 \
    ipv4.addresses 192.168.56.40/24 \
    ipv4.dns "192.168.56.10 192.168.56.11" \
    ipv4.method manual

sudo nmcli con up "INTERNAL"
```

---

## 6.4 Verifikasi Konektivitas

```bash
# Cek IP eth1
ip addr show eth1

# Ping semua target
ping -c 2 192.168.56.10   # DC1
ping -c 2 192.168.56.11   # DC2
ping -c 2 192.168.56.20   # FILESRV
ping -c 2 192.168.56.30   # CLIENT01

# Test DNS
nslookup corp.local 192.168.56.10
nslookup dc1.corp.local 192.168.56.10

# Test port — AD services
nmap -Pn -p 88,135,389,445,5985 192.168.56.10
```

---

## 6.5 Instalasi Tool Red Team

### Update dan Verifikasi Tool Bawaan

```bash
sudo apt update && sudo apt upgrade -y

# Cek tool bawaan
which nmap smbclient ldapsearch responder crackmapexec evil-winrm
```

### Instal Tool Tambahan

```bash
# Impacket
sudo apt install python3-impacket impacket-scripts -y

# CrackMapExec / NetExec
sudo apt install crackmapexec -y
pip3 install netexec

# Evil-WinRM
sudo apt install evil-winrm -y

# Responder
sudo apt install responder -y

# enum4linux
sudo apt install enum4linux enum4linux-ng -y

# BloodHound
sudo apt install bloodhound -y

# kerbrute
sudo apt install kerbrute -y

# ldapdomaindump
pip3 install ldapdomaindump
```

### Setup BloodHound

```bash
sudo neo4j start
# Akses http://localhost:7474 — ganti default password (neo4j/neo4j)
bloodhound
```

### Download Tool Windows (untuk Transfer ke Target)

```bash
mkdir -p ~/tools/windows
cd ~/tools/windows

# SharpHound: https://github.com/BloodHoundAD/SharpHound/releases
# Rubeus: https://github.com/GhostPack/Rubeus (perlu compile)
# Mimikatz: https://github.com/gentilkiwi/mimikatz/releases
```

---

## 6.6 Organisasi Folder Kerja

```bash
mkdir -p ~/redteam/{recon,loot,exploits,notes,tools}
```

| Folder | Isi |
|--------|-----|
| `recon/` | Hasil scanning dan enumerasi |
| `loot/` | Credentials, hashes, data |
| `exploits/` | Script dan payload |
| `notes/` | Catatan dan dokumentasi |
| `tools/` | Tool tambahan |

---

## 6.7 Test Koneksi ke Lab

Quick test untuk memastikan semua siap:

```bash
# Enumerasi SMB — harus menampilkan shares
crackmapexec smb 192.168.56.20 -u "" -p "" --shares

# Test DNS resolution
dig @192.168.56.10 corp.local
dig @192.168.56.10 _ldap._tcp.corp.local SRV

# Test WinRM (setelah user dibuat)
# evil-winrm -i 192.168.56.10 -u Administrator -p '<password>'
```

---

## Ringkasan Konfigurasi Kali

| Konfigurasi | eth0 (PUBLIC) | eth1 (INTERNAL) |
|-------------|---------------|-----------------|
| IP Address | IP dari ISP/cloud | 192.168.56.40 |
| Gateway | ✅ Ya | ❌ Tidak ada |
| DNS | ISP default | 192.168.56.10, 192.168.56.11 |
| Fungsi | SSH, internet, download tool | Menyerang target lab |

---

## Referensi Tool per Fase

| Fase | Tool |
|------|------|
| Reconnaissance | nmap |
| Enumeration | enum4linux, ldapsearch, smbclient, BloodHound, CrackMapExec |
| Credential Access | Responder, kerbrute, Impacket (GetNPUsers, GetUserSPNs), Mimikatz, Rubeus |
| Privilege Escalation | BloodHound, Mimikatz, CrackMapExec |
| Lateral Movement | Impacket (psexec, wmiexec), Evil-WinRM, CrackMapExec |
| Persistence | schtasks, sc.exe, reg.exe, Impacket (ticketer) |

---

## Troubleshooting

### eth1 tidak bisa ping target Windows

- Cek IP: `ip addr show eth1` — harus ada `192.168.56.40/24`
- Pastikan adapter eth1 terhubung ke jaringan internal yang sama
- Windows firewall mungkin blok ICMP — di target Windows:
```powershell
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Action Allow
```

### nslookup gagal dari Kali

- Specify DNS server langsung: `nslookup corp.local 192.168.56.10`
- Cek `/etc/resolv.conf` — pastikan ada `nameserver 192.168.56.10`

### Tool tidak terinstal

```bash
sudo apt update
sudo apt install -f
sudo apt install <nama_tool> -y
```
