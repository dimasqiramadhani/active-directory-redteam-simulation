# 💻 Step 5: Instalasi Windows Client (CLIENT01)

## Tujuan

Menginstal CLIENT01 sebagai workstation karyawan yang tergabung ke domain `corp.local`. Mesin ini mensimulasikan komputer kerja sehari-hari yang menjadi target awal serangan red team.

---

## 5.1 Membuat VM

| Parameter | Nilai |
|-----------|-------|
| Name | CLIENT01 |
| OS | Windows 10 Pro / Windows 11 Pro |
| RAM | 2 GB |
| CPU | 2 vCPU |
| Disk | 40 GB |
| Network | Host-Only (vboxnet0 / VMnet2) |

**Catatan:** Harus versi **Pro** atau **Enterprise** — versi Home tidak bisa join domain.

---

## 5.2 Konfigurasi IP Static

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.56.30 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.56.10, 192.168.56.11
```

---

## 5.3 Ubah Hostname

```powershell
Rename-Computer -NewName "CLIENT01" -Restart
```

---

## 5.4 Join Domain

```powershell
nslookup corp.local
Add-Computer -DomainName "corp.local" -Credential (Get-Credential) -Restart
```

---

## 5.5 Konfigurasi untuk Simulasi Serangan

Setelah join domain, login sebagai `CORP\Administrator` dan lakukan konfigurasi berikut:

### Aktifkan RDP

```powershell
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Tambahkan domain users ke Remote Desktop Users
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "CORP\Domain Users"
```

### Aktifkan WinRM

```powershell
Enable-PSRemoting -Force
winrm quickconfig -q
```

### Disable Windows Defender (untuk lab saja)

```powershell
# Disable real-time protection (agar tool red team tidak di-block)
Set-MpPreference -DisableRealtimeMonitoring $true

# Disable via Group Policy (lebih permanen)
# gpedit.msc → Computer Configuration → Administrative Templates
# → Windows Components → Microsoft Defender Antivirus
# → Turn off Microsoft Defender Antivirus → Enabled
```

### Simulasi Aktivitas User

Buat beberapa file yang mensimulasikan aktivitas user biasa:

```powershell
# Login sebagai user biasa (contoh: j.doe) dan buat file di desktop
# Kembali ke Administrator dulu untuk setup

$userProfile = "C:\Users\Public\Documents"

@"
Browser Passwords Export
========================
Gmail: j.doe@gmail.com / PersonalPass123
Corporate Portal: j.doe / Welcome2024!
"@ | Out-File "$userProfile\passwords_backup.txt"

@"
Meeting Notes - Q4 Review
=========================
VPN credentials shared by IT:
Server: vpn.corp.local
Username: j.doe
Password: CorpVPN2024!
"@ | Out-File "$userProfile\meeting_notes.txt"
```

### Tambahkan Local Admin untuk Simulasi

```powershell
# Tambahkan user helpdesk sebagai local admin (intentional misconfiguration)
Add-LocalGroupMember -Group "Administrators" -Member "CORP\helpdesk"
```

---

## 5.6 Verifikasi

```powershell
# Cek domain membership
(Get-WmiObject Win32_ComputerSystem).Domain

# Cek bisa akses share
net view \\FILESRV

# Cek konektivitas ke DC
nltest /dsgetdc:corp.local

# Cek local admins
Get-LocalGroupMember -Group "Administrators"
```

---

## Troubleshooting

### Gagal join domain

- Pastikan DNS menunjuk ke `192.168.56.10`
- Pastikan Windows versi Pro/Enterprise (bukan Home)
- Cek apakah bisa ping DC1: `ping 192.168.56.10`

### Login domain user gagal

- Pastikan DC1 running dan accessible
- Cek `nltest /dsgetdc:corp.local` — harus return DC1 atau DC2
- Cek waktu/timezone — Kerberos sensitif terhadap perbedaan waktu (max 5 menit)
