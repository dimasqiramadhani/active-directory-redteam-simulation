# 💻 Step 5: Instalasi Windows Client (CLIENT01)

## Prasyarat

Pastikan di DC1 sudah dijalankan:
- ✅ OU, users, groups, service accounts sudah dibuat
- ✅ FILESRV sudah join domain dan shares sudah dibuat

---

## Tujuan

Menginstal CLIENT01 sebagai workstation karyawan yang tergabung ke domain `corp.local`. Mesin ini mensimulasikan komputer kerja yang menjadi target awal serangan red team.

---

## 5.1 Membuat VM / Menyiapkan Server

| Parameter | Nilai |
|-----------|-------|
| Name | CLIENT01 |
| OS | Windows 10/11 **Pro** atau **Enterprise** (Home tidak bisa join domain) |
| RAM | 2 GB |
| CPU | 2 vCPU |
| Disk | 40 GB |
| Adapter 1 | PUBLIC — IP public (untuk RDP) |
| Adapter 2 | INTERNAL — private network (untuk domain) |

---

## 5.2 (Opsional) Sysprep untuk VM Clone

```powershell
C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown
```

**Lewati jika instal dari ISO.**

---

## 5.3 Identifikasi dan Rename Adapter

```powershell
Get-NetAdapter | Select-Object Name, InterfaceIndex, Status, MacAddress

Rename-NetAdapter -Name "Ethernet" -NewName "PUBLIC"
Rename-NetAdapter -Name "Ethernet 2" -NewName "INTERNAL"
```

---

## 5.4 Konfigurasi IP Static — Dual Adapter

### Adapter PUBLIC

```powershell
New-NetIPAddress -InterfaceAlias "PUBLIC" `
    -IPAddress <IP_PUBLIC_CLIENT01> `
    -PrefixLength 24 `
    -DefaultGateway <GATEWAY_PUBLIC>
```

### Adapter INTERNAL

```powershell
New-NetIPAddress -InterfaceAlias "INTERNAL" `
    -IPAddress 192.168.56.30 `
    -PrefixLength 24
# JANGAN set gateway
```

### DNS Client

```powershell
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10, 192.168.56.11
Set-DnsClientServerAddress -InterfaceAlias "PUBLIC" -ServerAddresses 192.168.56.10, 192.168.56.11
```

---

## 5.5 Matikan DNS Registration di Adapter PUBLIC

```powershell
Set-DnsClient -InterfaceAlias "PUBLIC" -RegisterThisConnectionsAddress $false
```

---

## 5.6 Set Binding Order

```powershell
Set-NetIPInterface -InterfaceAlias "INTERNAL" -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias "PUBLIC" -InterfaceMetric 50
```

---

## 5.7 Ubah Hostname

```powershell
Rename-Computer -NewName "CLIENT01" -Restart
```

---

## 5.8 Verifikasi Konektivitas dan Join Domain

```powershell
ping 192.168.56.10
nslookup corp.local

Add-Computer -DomainName "corp.local" -Credential (Get-Credential) -Restart
```

---

## 5.9 Bersihkan DNS Record yang Salah

Di **DC1** — DNS Manager → Forward Lookup Zones → corp.local:
- Cari A record `client01` → hapus jika menunjuk ke IP public
- Sisakan hanya `192.168.56.30`

Di CLIENT01:

```powershell
ipconfig /flushdns
ipconfig /registerdns
nslookup client01.corp.local   # Harus: 192.168.56.30
```

---

## 5.10 Konfigurasi untuk Simulasi Serangan

Login sebagai `CORP\Administrator`:

### Aktifkan RDP

```powershell
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "CORP\Domain Users"
```

### Aktifkan WinRM

```powershell
Enable-PSRemoting -Force
winrm quickconfig -q
```

### Disable Windows Defender (untuk lab saja)

```powershell
Set-MpPreference -DisableRealtimeMonitoring $true
```

### Tambahkan Local Admin (Intentional Misconfiguration)

```powershell
# helpdesk sebagai local admin — overprivileged
Add-LocalGroupMember -Group "Administrators" -Member "CORP\helpdesk"
```

### Simulasi File Sensitif

```powershell
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

---

## 5.11 Verifikasi

```powershell
(Get-WmiObject Win32_ComputerSystem).Domain    # Harus: corp.local
nslookup client01.corp.local                    # Harus: 192.168.56.30
nltest /dsgetdc:corp.local                      # Harus return DC1 atau DC2
Get-LocalGroupMember -Group "Administrators"    # Harus ada CORP\helpdesk
```

---

## Troubleshooting

### Gagal join domain

- Pastikan DNS menunjuk ke `192.168.56.10`
- Pastikan Windows versi **Pro/Enterprise** (bukan Home)
- Cek `nslookup corp.local`

### Login domain user gagal

- Cek DC accessible: `nltest /dsgetdc:corp.local`
- Kerberos sensitif terhadap waktu — pastikan perbedaan waktu < 5 menit antara CLIENT01 dan DC

### Add-LocalGroupMember error "Principal not found"

- User belum dibuat di AD. Kembali ke DC1, jalankan `users.md`
