# 🔓 Misconfiguration: Weak Permissions & Credentials

## Gambaran Umum

Dokumen ini mencakup semua intentional misconfiguration terkait permission, password policy, dan exposed credentials yang diterapkan di lab.

---

## 1. Password Lemah dan Password Reuse

### Konfigurasi

Beberapa user menggunakan password yang sama (`Welcome2024!`): j.doe, r.smith, k.brown.

Beberapa user menggunakan password predictable: a.intern (`Summer2024!`), s.admin (`P@ssw0rd123`).

### Mengapa Ini Penting untuk Latihan

- **Password Spraying** (T1110.003) — mencoba satu password umum ke banyak akun sekaligus, menghindari account lockout
- **Credential Reuse** — satu credential yang berhasil bisa dicoba di mesin lain
- Dalam dunia nyata, password reuse adalah salah satu kelemahan paling umum

### Setup Password Policy yang Lemah (di DC1)

```powershell
# Set password policy yang lemah untuk lab
Set-ADDefaultDomainPasswordPolicy -Identity "corp.local" `
    -MinPasswordLength 7 `
    -PasswordHistoryCount 0 `
    -ComplexityEnabled $false `
    -MaxPasswordAge "180.00:00:00" `
    -LockoutThreshold 0
```

**Catatan:** `LockoutThreshold 0` berarti tidak ada account lockout — ini memungkinkan brute force tanpa batas untuk latihan.

---

## 2. Exposed SMB Shares

### Konfigurasi

Share `Public` di FILESRV dibuka dengan `FullAccess` ke `Everyone`. Share `IT` berisi script dengan password hardcoded.

### Mengapa Ini Penting

- **T1135** — Network Share Discovery: attacker bisa menemukan share yang terbuka
- **T1552.001** — Unsecured Credentials in Files: password yang tersimpan di script
- Dalam dunia nyata, share yang terlalu terbuka sering ditemukan saat assessment

---

## 3. Stored Credentials in Scripts

### Konfigurasi (sudah diterapkan di Step 4)

File `C:\Shares\IT\deploy_script.bat` berisi password plaintext svc_backup. File `C:\Shares\IT\db_config.txt` berisi password svc_sql.

### Mengapa Ini Penting

- **T1552.001** — credential exposure di file share yang accessible
- Attacker yang mendapat akses ke share IT langsung mendapat service account credentials
- Dalam dunia nyata, script deployment dan config file sering mengandung password

---

## 4. LLMNR dan NBT-NS Enabled

### Konfigurasi

Secara default, LLMNR dan NBT-NS sudah aktif di Windows. Tidak perlu konfigurasi tambahan.

### Mengapa Ini Penting

- **T1557.001** — LLMNR/NBT-NS Poisoning: ketika DNS resolution gagal, Windows fallback ke LLMNR/NBT-NS yang bisa di-poison oleh attacker di jaringan yang sama
- Attacker bisa menangkap NTLMv2 hash dari client yang salah ketik nama server
- Tool: Responder

### Cara Menguji

```bash
# Dari Kali, jalankan Responder
sudo responder -I eth0 -dwv

# Dari CLIENT01, coba akses share yang tidak ada:
# \\typoserver\share
# Responder akan menangkap NTLMv2 hash
```

---

## 5. Overprivileged Accounts

### Konfigurasi

- `helpdesk` ditambahkan ke group **Server Operators** — bisa manage services di Domain Controller
- `helpdesk` ditambahkan sebagai **local admin** di CLIENT01
- `j.doe` ditambahkan sebagai **local admin** di CLIENT01

### Mengapa Ini Penting

- **T1078.002** — Valid Accounts: Domain Accounts yang overprivileged
- Helpdesk seharusnya tidak perlu Server Operators privilege
- Akses local admin memungkinkan credential dumping
- Attack path: compromise helpdesk → credential dump di CLIENT01 → cari credential lain → escalate ke Domain Admin

---

## 6. ACL Misconfiguration

### Konfigurasi

Berikan user biasa kemampuan untuk mereset password user lain:

```powershell
# Di DC1 — berikan helpdesk hak GenericAll pada OU HR
# Ini berarti helpdesk bisa reset password semua user HR

$acl = Get-Acl "AD:OU=HR,DC=corp,DC=local"
$helpdesk = Get-ADUser "helpdesk"
$sid = New-Object System.Security.Principal.SecurityIdentifier($helpdesk.SID)
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $sid,
    "GenericAll",
    "Allow",
    [System.DirectoryServices.ActiveDirectorySecurityInheritance]"All"
)
$acl.AddAccessRule($ace)
Set-Acl "AD:OU=HR,DC=corp,DC=local" $acl
```

### Mengapa Ini Penting

- **T1222.001** — File and Directory Permissions Modification
- BloodHound bisa mendeteksi ACL misconfiguration ini sebagai attack path
- Helpdesk bisa reset password HR user → login sebagai HR manager → akses data sensitif

---

## Ringkasan Misconfiguration

| # | Misconfiguration | MITRE ATT&CK | Risiko |
|---|-----------------|---------------|--------|
| 1 | Password lemah/reuse | T1110.003 | Password spraying berhasil |
| 2 | No account lockout | T1110 | Brute force tanpa batas |
| 3 | Exposed SMB shares | T1135, T1552.001 | Credential theft dari file |
| 4 | Credentials in scripts | T1552.001 | Akses service account |
| 5 | LLMNR enabled | T1557.001 | Hash capture via poisoning |
| 6 | Overprivileged accounts | T1078.002 | Privilege escalation |
| 7 | ACL misconfiguration | T1222.001 | Unauthorized password reset |
