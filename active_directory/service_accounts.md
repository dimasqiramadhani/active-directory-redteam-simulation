# ⚙️ Konfigurasi Service Account

## Tujuan

Membuat service account yang mensimulasikan layanan enterprise (backup, database, web) dengan SPN (Service Principal Name) yang terdaftar, menjadikannya target Kerberoasting.

---

## Daftar Service Account

| Username   | SPN                              | Password        | Misconfiguration                 |
|------------|----------------------------------|-----------------|----------------------------------|
| svc_backup | CIFS/filesrv.corp.local          | Backup2024!     | Kerberoastable, password lemah   |
| svc_sql    | MSSQLSvc/filesrv.corp.local:1433 | SQLService2024! | Kerberoastable                   |
| svc_web    | HTTP/filesrv.corp.local          | WebApp2024!     | AS-REP Roasting + Kerberoastable |

---

## Membuat Service Account

Jalankan di **DC1**:

```powershell
# ---- svc_backup ----
New-ADUser -Name "Backup Service" -SamAccountName "svc_backup" `
    -UserPrincipalName "svc_backup@corp.local" `
    -Path "OU=Service Accounts,OU=IT,DC=corp,DC=local" `
    -AccountPassword (ConvertTo-SecureString "Backup2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -Description "Backup Service Account" -ServicePrincipalNames @("CIFS/filesrv.corp.local")

# ---- svc_sql ----
New-ADUser -Name "SQL Service" -SamAccountName "svc_sql" `
    -UserPrincipalName "svc_sql@corp.local" `
    -Path "OU=Service Accounts,OU=IT,DC=corp,DC=local" `
    -AccountPassword (ConvertTo-SecureString "SQLService2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -Description "SQL Service Account" -ServicePrincipalNames @("MSSQLSvc/filesrv.corp.local:1433")

# ---- svc_web ----
New-ADUser -Name "Web Service" -SamAccountName "svc_web" `
    -UserPrincipalName "svc_web@corp.local" `
    -Path "OU=Service Accounts,OU=IT,DC=corp,DC=local" `
    -AccountPassword (ConvertTo-SecureString "WebApp2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -Description "Web Application Service Account" -ServicePrincipalNames @("HTTP/filesrv.corp.local")

# ---- Konfigurasi AS-REP Roasting untuk svc_web ----
# Disable Kerberos pre-authentication (menjadikan target AS-REP Roasting)
Set-ADAccountControl -Identity "svc_web" -DoesNotRequirePreAuth $true
```

---

## Mengapa Service Account Rentan?

### Kerberoasting

Ketika service account memiliki SPN terdaftar, siapa pun yang memiliki akun domain valid bisa meminta TGS (Ticket Granting Service) untuk SPN tersebut. TGS ini dienkripsi menggunakan password hash service account. Jika password lemah, hash bisa di-crack secara offline.

**Relevansi:** MITRE ATT&CK T1558.003

### AS-REP Roasting

Jika Kerberos pre-authentication dinonaktifkan pada akun (`DoesNotRequirePreAuth`), attacker bisa meminta AS-REP dari KDC tanpa perlu password. Respons AS-REP berisi data yang dienkripsi dengan password hash user, yang bisa di-crack secara offline.

**Relevansi:** MITRE ATT&CK T1558.004

---

## Verifikasi

```powershell
# Lihat semua service accounts
Get-ADUser -Filter * -SearchBase "OU=Service Accounts,OU=IT,DC=corp,DC=local" -Properties ServicePrincipalNames, DoesNotRequirePreAuth | `
    Select-Object Name, SamAccountName, ServicePrincipalNames, DoesNotRequirePreAuth

# Cari user dengan SPN (potential Kerberoast targets)
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalNames | `
    Select-Object Name, ServicePrincipalNames

# Cari user tanpa pre-auth (AS-REP Roast targets)
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} | Select-Object Name
```
