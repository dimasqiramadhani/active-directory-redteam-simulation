# 🏢 Step 2: Instalasi Primary Domain Controller (DC1)

## Tujuan

Menginstal dan mengkonfigurasi DC1 sebagai Primary Domain Controller dengan Active Directory Domain Services (AD DS) dan DNS Server untuk domain `corp.local`.

---

## 2.1 Membuat VM

### Spesifikasi VM

| Parameter | Nilai |
|-----------|-------|
| Name | DC1 |
| OS | Windows Server 2019 atau 2022 |
| RAM | 2 GB (2048 MB) |
| CPU | 2 vCPU |
| Disk | 40 GB (Dynamic/Thin) |
| Network | Host-Only (vboxnet0 / VMnet2) |

### Instalasi Windows Server

1. Mount ISO Windows Server 2019/2022
2. Boot VM dan mulai instalasi
3. Pilih **Windows Server 2019/2022 Standard (Desktop Experience)** — pilih versi dengan GUI untuk kemudahan konfigurasi
4. Pilih **Custom Install** → pilih disk → Install
5. Setelah instalasi selesai, buat password Administrator

**Catatan:** Kamu bisa menggunakan ISO evaluasi gratis dari Microsoft Evaluation Center (berlaku 180 hari).

---

## 2.2 Konfigurasi IP Static

Buka **PowerShell sebagai Administrator** dan jalankan:

```powershell
# Lihat nama adapter jaringan
Get-NetAdapter

# Konfigurasi IP static (sesuaikan InterfaceAlias dengan nama adapter kamu)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.56.10 -PrefixLength 24

# Set DNS menunjuk ke diri sendiri (127.0.0.1) dan DC2 sebagai fallback
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1, 192.168.56.11
```

Atau melalui GUI:
1. **Control Panel** → **Network and Sharing Center** → klik adapter → **Properties**
2. Pilih **Internet Protocol Version 4 (TCP/IPv4)** → **Properties**
3. Pilih **Use the following IP address:**
   - IP: `192.168.56.10`
   - Subnet: `255.255.255.0`
   - Gateway: (kosongkan)
4. **Use the following DNS server:**
   - Preferred: `127.0.0.1`
   - Alternate: `192.168.56.11`

---

## 2.3 Ubah Hostname

```powershell
Rename-Computer -NewName "DC1" -Restart
```

Tunggu VM restart.

---

## 2.4 Instal Active Directory Domain Services

### Via PowerShell (Rekomendasi)

```powershell
# Instal AD DS dan DNS Server role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-WindowsFeature -Name DNS -IncludeManagementTools
```

### Via Server Manager (GUI)

1. Buka **Server Manager** → **Add Roles and Features**
2. **Role-based installation** → pilih server DC1
3. Centang:
   - ✅ Active Directory Domain Services
   - ✅ DNS Server
4. Klik **Next** → **Install**

---

## 2.5 Promosikan Menjadi Domain Controller

Setelah role terinstal, promosikan DC1 menjadi Domain Controller untuk forest baru.

### Via PowerShell

```powershell
# Promosikan sebagai DC untuk forest baru
Install-ADDSForest `
    -DomainName "corp.local" `
    -DomainNetbiosName "CORP" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDns:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "Lab@dmin2024!" -AsPlainText -Force) `
    -Force:$true
```

### Via Server Manager (GUI)

1. Setelah instalasi role, klik notifikasi ⚠️ di Server Manager
2. Klik **Promote this server to a domain controller**
3. Pilih **Add a new forest**
4. Root domain name: `corp.local`
5. **Domain Controller Options:**
   - Forest functional level: Windows Server 2016
   - Domain functional level: Windows Server 2016
   - ✅ DNS Server
   - ✅ Global Catalog
   - DSRM Password: `Lab@dmin2024!` (ini password recovery, simpan baik-baik)
6. Klik **Next** sampai selesai → **Install**
7. Server akan restart otomatis

---

## 2.6 Verifikasi Instalasi

Setelah restart, login sebagai `CORP\Administrator`:

```powershell
# Verifikasi domain
Get-ADDomain

# Verifikasi DC
Get-ADDomainController

# Verifikasi DNS zone
Get-DnsServerZone

# Verifikasi SRV record
nslookup -type=SRV _ldap._tcp.corp.local

# Cek service AD DS berjalan
Get-Service NTDS, DNS, Netlogon, KDC
```

Pastikan semua service dalam status **Running**.

---

## 2.7 Konfigurasi DNS Tambahan

### Buat Reverse Lookup Zone

```powershell
Add-DnsServerPrimaryZone -NetworkID "192.168.56.0/24" -ReplicationScope "Forest"
```

### Buat PTR Record untuk DC1

```powershell
Add-DnsServerResourceRecordPtr -ZoneName "56.168.192.in-addr.arpa" -Name "10" -PtrDomainName "dc1.corp.local"
```

---

## Troubleshooting

### Gagal promosi ke DC

- Pastikan DNS menunjuk ke `127.0.0.1` SEBELUM promosi
- Pastikan hostname sudah diubah dan VM sudah restart
- Cek event log: `Get-EventLog -LogName System -Newest 20`

### DNS tidak resolve corp.local

- Pastikan DNS Server service berjalan: `Get-Service DNS`
- Cek zone: `Get-DnsServerZone`
- Restart DNS service: `Restart-Service DNS`

### Tidak bisa login setelah promosi

- Gunakan format: `CORP\Administrator` atau `Administrator@corp.local`
- Password sama dengan password Administrator yang kamu set saat instalasi Windows
