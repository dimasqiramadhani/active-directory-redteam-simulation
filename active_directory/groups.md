# 👥 Konfigurasi Group

## Daftar Group

| Nama Group | Tipe | Member | Tujuan |
|-----------|------|--------|--------|
| Domain Admins | Built-in | Administrator, s.admin | Full control atas domain |
| IT Support | Security | helpdesk, j.doe, m.dev | Akses tool IT, local admin di workstation |
| HR Users | Security | l.jones, r.smith | Akses share HR |
| Finance Users | Security | d.wilson, k.brown | Akses share Finance |
| Remote Access | Security | helpdesk, j.doe, m.dev | Akses RDP dan WinRM |

---

## Membuat Group dan Assign Member

Jalankan di **DC1**:

```powershell
# Buat security groups
New-ADGroup -Name "IT Support" -GroupScope Global -GroupCategory Security `
    -Path "OU=IT,DC=corp,DC=local" -Description "IT Support Team"

New-ADGroup -Name "HR Users" -GroupScope Global -GroupCategory Security `
    -Path "OU=HR,DC=corp,DC=local" -Description "HR Department Users"

New-ADGroup -Name "Finance Users" -GroupScope Global -GroupCategory Security `
    -Path "OU=Finance,DC=corp,DC=local" -Description "Finance Department Users"

New-ADGroup -Name "Remote Access" -GroupScope Global -GroupCategory Security `
    -Path "OU=IT,DC=corp,DC=local" -Description "Users with Remote Desktop Access"

# ---- Assign Members ----

# Domain Admins (tambahkan s.admin)
Add-ADGroupMember -Identity "Domain Admins" -Members "s.admin"

# IT Support
Add-ADGroupMember -Identity "IT Support" -Members "helpdesk", "j.doe", "m.dev"

# HR Users
Add-ADGroupMember -Identity "HR Users" -Members "l.jones", "r.smith"

# Finance Users
Add-ADGroupMember -Identity "Finance Users" -Members "d.wilson", "k.brown"

# Remote Access
Add-ADGroupMember -Identity "Remote Access" -Members "helpdesk", "j.doe", "m.dev"

# --- Intentional Misconfiguration ---
# Tambahkan helpdesk ke Server Operators (overprivileged)
Add-ADGroupMember -Identity "Server Operators" -Members "helpdesk"
```

---

## Misconfiguration Group Membership

| Misconfiguration | Detail | Risiko |
|-----------------|--------|--------|
| helpdesk di Server Operators | Bisa manage services di DC | Privilege escalation ke DA |
| s.admin di Domain Admins | DA dengan password lemah | Lateral movement → domain takeover |
| j.doe di IT Support | Juga local admin di CLIENT01 | Credential theft dari workstation |

---

## Verifikasi

```powershell
# Lihat semua group custom
Get-ADGroup -Filter * -SearchBase "DC=corp,DC=local" | Where-Object {$_.Name -notlike "Domain*" -and $_.Name -notlike "Enterprise*"} | Select-Object Name

# Lihat member per group
Get-ADGroupMember -Identity "IT Support" | Select-Object Name
Get-ADGroupMember -Identity "Domain Admins" | Select-Object Name
Get-ADGroupMember -Identity "Server Operators" | Select-Object Name
```
