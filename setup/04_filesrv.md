# 📁 Step 4: Instalasi Member Server (FILESRV)

## Prasyarat

Sebelum setup FILESRV, pastikan di DC1 sudah dijalankan **secara berurutan**:

1. ✅ `active_directory/ou_structure.md` — Buat OU
2. ✅ Step 2.10 — Turunkan password policy
3. ✅ `active_directory/users.md` — Buat semua user
4. ✅ `active_directory/groups.md` — Buat group + assign member
5. ✅ `active_directory/service_accounts.md` — Buat service account + SPN

**Jika group belum dibuat, pembuatan SMB share akan gagal** dengan error `No mapping between account names and security IDs`.

---

## Tujuan

Menginstal FILESRV sebagai domain member server dengan peran File Server, service accounts, dan misconfigured permissions untuk latihan privilege escalation.

---

## 4.1 Membuat VM / Menyiapkan Server

| Parameter | Nilai                                     |
|-----------|-------------------------------------------|
| Name      | FILESRV                                   |
| OS        | Windows Server 2019/2022                  |
| RAM       | 2 GB                                      |
| CPU       | 2 vCPU                                    |
| Disk      | 40 GB                                     |
| Adapter 1 | PUBLIC — IP dari ISP/cloud (untuk RDP)    |
| Adapter 2 | INTERNAL — private network (untuk domain) |

---

## 4.2 (Opsional) Sysprep untuk VM Clone

```powershell
C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown
```

**Lewati jika instal dari ISO.**

---

## 4.3 Identifikasi dan Rename Adapter

```powershell
Get-NetAdapter | Select-Object Name, InterfaceIndex, Status, MacAddress

Rename-NetAdapter -Name "Ethernet" -NewName "PUBLIC"
Rename-NetAdapter -Name "Ethernet 2" -NewName "INTERNAL"
```

---

## 4.4 Konfigurasi IP Static — Dual Adapter

### Adapter PUBLIC

```powershell
New-NetIPAddress -InterfaceAlias "PUBLIC" `
    -IPAddress <IP_PUBLIC_FILESRV> `
    -PrefixLength 24 `
    -DefaultGateway <GATEWAY_PUBLIC>
```

### Adapter INTERNAL

```powershell
New-NetIPAddress -InterfaceAlias "INTERNAL" `
    -IPAddress 192.168.56.20 `
    -PrefixLength 24
# JANGAN set gateway
```

### DNS Client — Menunjuk ke Kedua DC

```powershell
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10, 192.168.56.11
Set-DnsClientServerAddress -InterfaceAlias "PUBLIC" -ServerAddresses 192.168.56.10, 192.168.56.11
```

---

## 4.5 Matikan DNS Registration di Adapter PUBLIC

```powershell
Set-DnsClient -InterfaceAlias "PUBLIC" -RegisterThisConnectionsAddress $false
```

---

## 4.6 Set Binding Order

```powershell
Set-NetIPInterface -InterfaceAlias "INTERNAL" -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias "PUBLIC" -InterfaceMetric 50
```

---

## 4.7 Ubah Hostname

```powershell
Rename-Computer -NewName "FILESRV" -Restart
```

---

## 4.8 Verifikasi Konektivitas ke DC

**Jangan lanjut sebelum semua ini berhasil:**

```powershell
ping 192.168.56.10
nslookup corp.local
nslookup dc1.corp.local
```

---

## 4.9 Join Domain

```powershell
Add-Computer -DomainName "corp.local" -Credential (Get-Credential) -Restart
```

Credential: `CORP\Administrator`.

---

## 4.10 Bersihkan DNS Record yang Salah

Setelah join domain, cek di **DC1** — DNS Manager → Forward Lookup Zones → corp.local:
- Cari A record `filesrv` → jika menunjuk ke IP public, **hapus**
- Sisakan hanya `192.168.56.20`

Di FILESRV:

```powershell
ipconfig /flushdns
ipconfig /registerdns
```

Verifikasi:

```powershell
nslookup filesrv.corp.local
# Harus: 192.168.56.20
```

---

## 4.11 Instal File Server Role

Login sebagai `CORP\Administrator`:

```powershell
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
```

---

## 4.12 Buat Shared Folders

```powershell
# Buat folder
New-Item -Path "C:\Shares\Public" -ItemType Directory -Force
New-Item -Path "C:\Shares\Finance" -ItemType Directory -Force
New-Item -Path "C:\Shares\IT" -ItemType Directory -Force
New-Item -Path "C:\Shares\HR" -ItemType Directory -Force
New-Item -Path "C:\Shares\Backup" -ItemType Directory -Force

# Buat SMB shares
New-SmbShare -Name "Public" -Path "C:\Shares\Public" -FullAccess "Everyone"
New-SmbShare -Name "Finance" -Path "C:\Shares\Finance" -FullAccess "CORP\Finance Users"
New-SmbShare -Name "IT" -Path "C:\Shares\IT" -FullAccess "CORP\IT Support"
New-SmbShare -Name "HR" -Path "C:\Shares\HR" -FullAccess "CORP\HR Users"
New-SmbShare -Name "Backup" -Path "C:\Shares\Backup" -FullAccess "CORP\Domain Admins"
```

**Jika error `No mapping between account names and security IDs`:** Group belum dibuat di AD. Kembali ke DC1 dan jalankan `active_directory/groups.md`.

---

## 4.13 Buat File untuk Simulasi

```powershell
@"
# Deploy Script - INTERNAL USE ONLY
# Service Account: svc_backup
# Password: Backup2024!
net use \\filesrv\backup /user:CORP\svc_backup Backup2024!
"@ | Out-File "C:\Shares\IT\deploy_script.bat"

@"
[Database Connection]
Server=FILESRV
Database=InventoryDB
User=svc_sql
Password=SQLService2024!
"@ | Out-File "C:\Shares\IT\db_config.txt"

@"
Employee Onboarding Credentials
================================
New Employee Default Password: Welcome2024!
WiFi Password: CorpWiFi2024
VPN Access: vpn.corp.local
"@ | Out-File "C:\Shares\HR\onboarding_guide.txt"

@"
Q4 Budget Allocation - CONFIDENTIAL
Department budgets and salary ranges enclosed.
"@ | Out-File "C:\Shares\Finance\q4_budget.xlsx"

@"
Welcome to CORP File Server
============================
Public share untuk file yang bisa diakses semua karyawan.
IT Support Contact: helpdesk@corp.local
"@ | Out-File "C:\Shares\Public\README.txt"
```

---

## 4.14 Konfigurasi Firewall

```powershell
# Allow SMB
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"

# Allow WinRM
Enable-PSRemoting -Force
winrm quickconfig -q

# Allow RDP
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

Cek firewall profile adapter INTERNAL:

```powershell
Get-NetConnectionProfile | Select-Object InterfaceAlias, NetworkCategory
```

Jika INTERNAL terdeteksi sebagai `Public` (bukan `DomainAuthenticated`):

```powershell
Set-NetConnectionProfile -InterfaceAlias "INTERNAL" -NetworkCategory Private
```

---

## 4.15 Verifikasi

```powershell
(Get-WmiObject Win32_ComputerSystem).Domain   # Harus: corp.local
nslookup filesrv.corp.local                    # Harus: 192.168.56.20
Get-SmbShare                                   # Harus tampil semua shares
```

---

## Troubleshooting

### Error "No mapping between account names and security IDs"

Group belum ada di AD. Kembali ke DC1, jalankan `groups.md`.

### Gagal join domain

- Cek DNS: `nslookup corp.local`
- Cek konektivitas: `ping 192.168.56.10`
- Pastikan credential `CORP\Administrator` benar

### Share tidak bisa diakses dari mesin lain

- Cek firewall: `Get-NetFirewallRule | Where-Object {$_.DisplayGroup -like "*File*"}`
- Pastikan akses via IP internal, bukan IP public
- Cek permission: `Get-SmbShareAccess -Name "Public"`
