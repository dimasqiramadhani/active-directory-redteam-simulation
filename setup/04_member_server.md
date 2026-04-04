# 📁 Step 4: Instalasi Member Server (FILESRV)

## Tujuan

Menginstal FILESRV sebagai domain member server dengan peran File Server, service accounts, dan misconfigured permissions untuk latihan privilege escalation.

---

## 4.1 Membuat VM

| Parameter | Nilai |
|-----------|-------|
| Name | FILESRV |
| OS | Windows Server 2019/2022 |
| RAM | 2 GB |
| CPU | 2 vCPU |
| Disk | 40 GB |
| Network | Host-Only (vboxnet0 / VMnet2) |

---

## 4.2 Konfigurasi IP Static

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.56.20 -PrefixLength 24

# DNS HARUS menunjuk ke DC1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.56.10, 192.168.56.11
```

---

## 4.3 Ubah Hostname

```powershell
Rename-Computer -NewName "FILESRV" -Restart
```

---

## 4.4 Join Domain

```powershell
# Verifikasi DNS resolve domain
nslookup corp.local

# Join domain
Add-Computer -DomainName "corp.local" -Credential (Get-Credential) -Restart
```

Masukkan credential `CORP\Administrator` saat diminta.

---

## 4.5 Instal File Server Role

Setelah restart dan login sebagai `CORP\Administrator`:

```powershell
# Instal File Server role
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
```

---

## 4.6 Buat Shared Folders

Buat beberapa shared folder untuk simulasi enterprise:

```powershell
# Buat folder struktur
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

---

## 4.7 Buat File untuk Simulasi

Buat file yang berisi informasi sensitif (sengaja untuk latihan):

```powershell
# Script deployment yang berisi password (intentional misconfiguration)
@"
# Deploy Script - INTERNAL USE ONLY
# Server: FILESRV
# Service Account: svc_backup
# Password: Backup2024!
# Last updated: 2024-01-15

net use \\filesrv\backup /user:CORP\svc_backup Backup2024!
"@ | Out-File "C:\Shares\IT\deploy_script.bat"

# File konfigurasi dengan credentials
@"
[Database Connection]
Server=FILESRV
Database=InventoryDB
User=svc_sql
Password=SQLService2024!
"@ | Out-File "C:\Shares\IT\db_config.txt"

# Dokumen HR
@"
Employee Onboarding Credentials
================================
New Employee Default Password: Welcome2024!
WiFi Password: CorpWiFi2024
VPN Access: vpn.corp.local
"@ | Out-File "C:\Shares\HR\onboarding_guide.txt"

# File budget Finance
@"
Q4 Budget Allocation - CONFIDENTIAL
Department budgets and salary ranges enclosed.
"@ | Out-File "C:\Shares\Finance\q4_budget.xlsx"

# File readme di Public share
@"
Welcome to CORP File Server
============================
Public share untuk file yang bisa diakses semua karyawan.
Untuk akses share departemen, hubungi IT Support.

IT Support Contact: helpdesk@corp.local
"@ | Out-File "C:\Shares\Public\README.txt"
```

---

## 4.8 Konfigurasi Firewall

Buka port yang diperlukan untuk simulasi serangan:

```powershell
# Allow SMB
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"

# Allow WinRM (untuk Evil-WinRM)
Enable-PSRemoting -Force
winrm quickconfig -q

# Allow RDP
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

---

## 4.9 Verifikasi

```powershell
# Cek domain membership
(Get-WmiObject Win32_ComputerSystem).Domain

# Cek shares yang tersedia
Get-SmbShare

# Test akses dari mesin lain
# Di DC1 atau CLIENT01:
net view \\FILESRV
dir \\FILESRV\Public
```

---

## Troubleshooting

### Gagal join domain

- Pastikan DNS menunjuk ke DC1 (`192.168.56.10`)
- Cek `nslookup corp.local` dari FILESRV
- Pastikan akun Administrator domain yang digunakan benar

### Share tidak bisa diakses

- Cek firewall: `Get-NetFirewallRule | Where-Object {$_.DisplayGroup -like "*File*"}`
- Pastikan SMB service berjalan: `Get-Service LanmanServer`
- Cek permission: `Get-SmbShareAccess -Name "Public"`
