# 🏛️ Struktur Organizational Unit (OU)

## Tujuan

Membuat struktur OU yang realistis menyerupai organisasi enterprise untuk menyimpan user, group, dan komputer sesuai departemen.

---

## Diagram Struktur OU

```
corp.local (Domain Root)
│
├── IT
│   ├── Users (IT staff)
│   └── Service Accounts
│
├── HR
│   └── Users (HR staff)
│
├── Finance
│   └── Users (Finance staff)
│
├── Servers
│   └── (Computer objects: FILESRV)
│
└── Workstations
    └── (Computer objects: CLIENT01)
```

---

## Membuat OU

Jalankan di **DC1** sebagai `CORP\Administrator`:

```powershell
# OU utama per departemen
New-ADOrganizationalUnit -Name "IT" -Path "DC=corp,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "HR" -Path "DC=corp,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "Finance" -Path "DC=corp,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "Servers" -Path "DC=corp,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "Workstations" -Path "DC=corp,DC=local" -ProtectedFromAccidentalDeletion $false

# Sub-OU di bawah IT untuk service accounts
New-ADOrganizationalUnit -Name "Service Accounts" -Path "OU=IT,DC=corp,DC=local" -ProtectedFromAccidentalDeletion $false
```

---

## Pindahkan Computer Objects

```powershell
# Pindahkan FILESRV ke OU Servers
Get-ADComputer "FILESRV" | Move-ADObject -TargetPath "OU=Servers,DC=corp,DC=local"

# Pindahkan CLIENT01 ke OU Workstations
Get-ADComputer "CLIENT01" | Move-ADObject -TargetPath "OU=Workstations,DC=corp,DC=local"
```

---

## Verifikasi

```powershell
# Lihat semua OU
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName

# Lihat isi OU tertentu
Get-ADObject -Filter * -SearchBase "OU=IT,DC=corp,DC=local" | Select-Object Name, ObjectClass
```
