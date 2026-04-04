# 👤 Konfigurasi User

## Tujuan

Membuat user account realistis di domain `corp.local` yang mensimulasikan karyawan enterprise dengan berbagai level akses dan beberapa kelemahan yang disengaja.

---

## Daftar User

| Username | Nama Lengkap | Departemen | Password | Catatan |
|----------|-------------|------------|----------|---------|
| j.doe | John Doe | IT | Welcome2024! | IT staff, local admin di CLIENT01 |
| s.admin | Sarah Admin | IT | P@ssw0rd123 | Domain Admin |
| helpdesk | Help Desk | IT | Helpdesk2024! | IT Support, local admin di beberapa mesin |
| m.dev | Mike Developer | IT | Developer2024! | Developer |
| a.intern | Alex Intern | IT | Summer2024! | Intern, password lemah |
| l.jones | Lisa Jones | HR | HRpass2024! | HR Manager |
| r.smith | Rachel Smith | HR | Welcome2024! | HR Staff, password reuse |
| d.wilson | David Wilson | Finance | Finance2024! | Finance Manager |
| k.brown | Karen Brown | Finance | Welcome2024! | Finance Staff, password reuse |
| svc_backup | Backup Service | IT (Service) | Backup2024! | Kerberoastable service account |
| svc_sql | SQL Service | IT (Service) | SQLService2024! | Kerberoastable service account |
| svc_web | Web Service | IT (Service) | WebApp2024! | Service account, AS-REP Roasting target |

---

## Membuat User

Jalankan di **DC1** sebagai `CORP\Administrator`:

```powershell
# ---- IT Department ----
New-ADUser -Name "John Doe" -SamAccountName "j.doe" -UserPrincipalName "j.doe@corp.local" `
    -Path "OU=IT,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "Welcome2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "John" -Surname "Doe" -Description "IT Staff"

New-ADUser -Name "Sarah Admin" -SamAccountName "s.admin" -UserPrincipalName "s.admin@corp.local" `
    -Path "OU=IT,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "Sarah" -Surname "Admin" -Description "System Administrator"

New-ADUser -Name "Help Desk" -SamAccountName "helpdesk" -UserPrincipalName "helpdesk@corp.local" `
    -Path "OU=IT,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "Helpdesk2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "Help" -Surname "Desk" -Description "IT Support"

New-ADUser -Name "Mike Developer" -SamAccountName "m.dev" -UserPrincipalName "m.dev@corp.local" `
    -Path "OU=IT,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "Developer2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "Mike" -Surname "Developer" -Description "Developer"

New-ADUser -Name "Alex Intern" -SamAccountName "a.intern" -UserPrincipalName "a.intern@corp.local" `
    -Path "OU=IT,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "Summer2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "Alex" -Surname "Intern" -Description "IT Intern"

# ---- HR Department ----
New-ADUser -Name "Lisa Jones" -SamAccountName "l.jones" -UserPrincipalName "l.jones@corp.local" `
    -Path "OU=HR,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "HRpass2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "Lisa" -Surname "Jones" -Description "HR Manager"

New-ADUser -Name "Rachel Smith" -SamAccountName "r.smith" -UserPrincipalName "r.smith@corp.local" `
    -Path "OU=HR,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "Welcome2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "Rachel" -Surname "Smith" -Description "HR Staff"

# ---- Finance Department ----
New-ADUser -Name "David Wilson" -SamAccountName "d.wilson" -UserPrincipalName "d.wilson@corp.local" `
    -Path "OU=Finance,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "Finance2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "David" -Surname "Wilson" -Description "Finance Manager"

New-ADUser -Name "Karen Brown" -SamAccountName "k.brown" -UserPrincipalName "k.brown@corp.local" `
    -Path "OU=Finance,DC=corp,DC=local" -AccountPassword (ConvertTo-SecureString "Welcome2024!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
    -GivenName "Karen" -Surname "Brown" -Description "Finance Staff"
```

---

## Kelemahan yang Disengaja (Untuk Latihan)

| Kelemahan | User yang Terdampak | Teknik Serangan |
|-----------|---------------------|-----------------|
| Password lemah/predictable | a.intern (`Summer2024!`) | Password Spraying, Brute Force |
| Password reuse (`Welcome2024!`) | j.doe, r.smith, k.brown | Password Spraying |
| Domain Admin dengan password lemah | s.admin (`P@ssw0rd123`) | Credential Access → Domain Takeover |
| Password tidak pernah expire | Semua user | Mengurangi rotasi password |

---

## Verifikasi

```powershell
# Lihat semua user di domain
Get-ADUser -Filter * -Properties Description | Select-Object Name, SamAccountName, Description, Enabled

# Lihat user per OU
Get-ADUser -Filter * -SearchBase "OU=IT,DC=corp,DC=local" | Select-Object Name, SamAccountName
Get-ADUser -Filter * -SearchBase "OU=HR,DC=corp,DC=local" | Select-Object Name, SamAccountName
Get-ADUser -Filter * -SearchBase "OU=Finance,DC=corp,DC=local" | Select-Object Name, SamAccountName
```
