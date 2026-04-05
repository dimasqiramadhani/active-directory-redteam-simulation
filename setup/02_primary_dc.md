# 🏢 Step 2: Instalasi Primary Domain Controller (DC1)

## Tujuan

Menginstal dan mengkonfigurasi DC1 sebagai Primary Domain Controller dengan Active Directory Domain Services (AD DS) dan DNS Server untuk domain `corp.local`.

Server ini menggunakan **dua network adapter**:
- **Adapter PUBLIC** — IP public untuk akses RDP dari luar
- **Adapter INTERNAL** — IP private untuk AD DS, DNS, dan semua traffic domain

---

## 2.1 Membuat VM / Menyiapkan Server

### Spesifikasi

| Parameter | Nilai |
|-----------|-------|
| Name | DC1 |
| OS | Windows Server 2019 atau 2022 |
| RAM | 2 GB (2048 MB) minimum |
| CPU | 2 vCPU |
| Disk | 40 GB |
| Adapter 1 | PUBLIC — IP dari ISP/cloud provider (untuk RDP) |
| Adapter 2 | INTERNAL — Host-Only / private network (untuk AD) |

### Instalasi Windows Server

1. Mount ISO Windows Server 2019/2022
2. Boot VM dan mulai instalasi
3. Pilih **Windows Server 2019/2022 Standard (Desktop Experience)** — pilih versi dengan GUI untuk kemudahan konfigurasi
4. Pilih **Custom Install** → pilih disk → Install
5. Setelah instalasi selesai, buat password Administrator

**Catatan:** Kamu bisa menggunakan ISO evaluasi gratis dari Microsoft Evaluation Center (berlaku 180 hari).

---

## 2.2 Identifikasi dan Rename Adapter

Buka **PowerShell sebagai Administrator**:

```powershell
# Lihat semua adapter
Get-NetAdapter | Select-Object Name, InterfaceIndex, Status, MacAddress
```

Lakukan sysprep terlebih dahulu jika vm yang digunakan berupa clone dari vm yang sudah ada

```powershell
# (Opsional) lakukan sysprep jika vm yang digunakan berupa clone dari vm yang sudah ada
C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown
```

setelah itu:

- VM akan mati
- saat dinyalakan lagi, Windows akan setup ulang identitas mesin

Rename adapter agar mudah dikenali:

```powershell
# Sesuaikan "Ethernet 1" dan "Ethernet 2" dengan nama adapter asli kamu
Rename-NetAdapter -Name "Ethernet 1" -NewName "PUBLIC"
Rename-NetAdapter -Name "Ethernet 2" -NewName "INTERNAL"
```

Verifikasi:

```powershell
Get-NetAdapter | Select-Object Name, Status
```

---

## 2.3 Konfigurasi IP Static — Dual Adapter

### Adapter PUBLIC (untuk RDP dari luar)

IP public biasanya sudah dikonfigurasi otomatis oleh provider. Jika perlu set manual:

```powershell
New-NetIPAddress -InterfaceAlias "PUBLIC" `
    -IPAddress <IP_PUBLIC_KAMU> `
    -PrefixLength 24 `
    -DefaultGateway <GATEWAY_PUBLIC_KAMU>
```

**PENTING:** Hanya adapter PUBLIC yang boleh punya **default gateway**. Jangan set gateway di adapter INTERNAL.

### Adapter INTERNAL (untuk AD/DNS)

```powershell
# Set IP static untuk jaringan internal AD
New-NetIPAddress -InterfaceAlias "INTERNAL" `
    -IPAddress 192.168.56.10 `
    -PrefixLength 24
# JANGAN set gateway di adapter ini
```

### Konfigurasi DNS Client di Kedua Adapter

```powershell
# INTERNAL — menunjuk ke IP internal sendiri
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10

# PUBLIC — juga menunjuk ke IP internal (JANGAN pakai 8.8.8.8 atau DNS public)
Set-DnsClientServerAddress -InterfaceAlias "PUBLIC" -ServerAddresses 192.168.56.10
```

**Mengapa DNS di kedua adapter menunjuk ke IP internal?** Kalau adapter PUBLIC pakai DNS public, Windows bisa salah mendaftarkan SRV record AD ke adapter yang salah — mesin domain member akan gagal resolve `corp.local`.

---

## 2.4 Matikan DNS Registration di Adapter PUBLIC

Ini **sangat penting** — mencegah IP public terdaftar di DNS record domain:

```powershell
Set-DnsClient -InterfaceAlias "PUBLIC" -RegisterThisConnectionsAddress $false
```

Atau lewat GUI:
1. **Network Connections** → klik kanan **PUBLIC** → **Properties**
2. Pilih **IPv4** → **Properties** → klik **Advanced**
3. Tab **DNS** → **uncheck** "Register this connection's addresses in DNS"

---

## 2.5 Set Binding Order — Prioritaskan Adapter Internal

AD harus mengutamakan adapter INTERNAL untuk semua service:

```powershell
Set-NetIPInterface -InterfaceAlias "INTERNAL" -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias "PUBLIC" -InterfaceMetric 50
```

Atau lewat GUI:
1. **Control Panel** → **Network Connections**
2. Menu **Advanced** → **Advanced Settings**
3. Tab **Adapters and Bindings** → pindahkan **INTERNAL** ke atas **PUBLIC**

Verifikasi:

```powershell
Get-NetIPInterface | Select-Object InterfaceAlias, InterfaceMetric, AddressFamily | Sort-Object InterfaceMetric
```

---

## 2.6 Ubah Hostname

```powershell
Rename-Computer -NewName "DC1" -Restart
```

Tunggu server restart.

---

## 2.7 Instal Active Directory Domain Services

### Via PowerShell (Rekomendasi)

```powershell
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

## 2.8 Promosikan Menjadi Domain Controller

Setelah role terinstal, promosikan DC1 menjadi Domain Controller untuk forest baru.

### Via PowerShell

```powershell
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

## 2.9 Konfigurasi DNS Server — Hanya Listen di IP Internal

Setelah promosi dan restart, login sebagai `CORP\Administrator`. Langkah ini **wajib** untuk mencegah DNS server menjawab query dari internet (open resolver = security risk).

### Via dnscmd (Rekomendasi)

```powershell
dnscmd localhost /ResetListenAddresses 192.168.56.10
Restart-Service DNS
```

Verifikasi:

```powershell
dnscmd /Info /ListenAddresses
Get-DnsServerSetting | Select-Object -ExpandProperty ListeningIPAddress | Select-Object IPAddressToString
```

**Output yang diharapkan:** Hanya `192.168.56.10`. IP public **tidak boleh** muncul.

### Via Registry (Jika dnscmd Gagal)

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters" `
    -Name "ListenAddresses" `
    -Value @("192.168.56.10")
Restart-Service DNS
```

### Via DNS Manager (GUI)

1. Buka **DNS Manager** (`dnsmgmt.msc`)
2. Klik kanan nama server **DC1** → **Properties**
3. Tab **Interfaces**
4. Pilih **Only the following IP addresses**
5. **Centang** hanya `192.168.56.10`
6. **Uncheck** IP public dan semua IPv6
7. Klik **OK**

---

## 2.10 Verifikasi Instalasi

```powershell
# Verifikasi domain
Get-ADDomain

# Verifikasi DC
Get-ADDomainController

# Verifikasi DNS zone
Get-DnsServerZone

# Cek A record — harus 192.168.56.10, BUKAN IP public
nslookup dc1.corp.local

# Verifikasi SRV record AD
nslookup -type=SRV _ldap._tcp.corp.local

# Cek service AD DS berjalan
Get-Service NTDS, DNS, Netlogon, KDC

# Pastikan DNS TIDAK bisa diakses dari IP public
# (dari mesin luar, jalankan: nslookup corp.local <IP_PUBLIC> → harus timeout/gagal)
```

Pastikan:
- Semua service dalam status **Running**
- A record `dc1.corp.local` menunjuk ke `192.168.56.10`
- SRV record `_ldap._tcp.corp.local` menunjuk ke `dc1.corp.local` di `192.168.56.10`

---

## 2.11 Bersihkan DNS Record yang Salah (Jika Ada)

Setelah promosi, kadang AD otomatis mendaftarkan IP public ke DNS zone. Cek dan hapus manual:

1. Buka **DNS Manager** (`dnsmgmt.msc`)
2. Navigasi ke **Forward Lookup Zones** → **corp.local**
3. Cari A record untuk `dc1` — jika ada entry yang menunjuk ke IP public, **hapus**
4. Sisakan hanya record yang menunjuk ke `192.168.56.10`

Lalu force re-register:

```powershell
ipconfig /flushdns
ipconfig /registerdns
```

---

## 2.12 Konfigurasi DNS Tambahan

### Buat Reverse Lookup Zone

```powershell
Add-DnsServerPrimaryZone -NetworkID "192.168.56.0/24" -ReplicationScope "Forest"
```

### Buat PTR Record untuk DC1

```powershell
Add-DnsServerResourceRecordPtr -ZoneName "56.168.192.in-addr.arpa" -Name "10" -PtrDomainName "dc1.corp.local"
```

---

## Ringkasan Konfigurasi Dual-Adapter

| Konfigurasi | Adapter PUBLIC | Adapter INTERNAL |
|-------------|---------------|-----------------|
| IP Address | IP dari ISP/cloud | 192.168.56.10 |
| Default Gateway | ✅ Ya (gateway ISP) | ❌ Tidak ada |
| DNS Client | 192.168.56.10 | 192.168.56.10 |
| DNS Registration | ❌ Dimatikan | ✅ Aktif |
| Interface Metric | 50 (rendah) | 10 (tinggi/prioritas) |
| DNS Server Listen | ❌ Tidak | ✅ Ya |
| Fungsi | RDP dari luar | AD DS, DNS, domain traffic |

---

## Troubleshooting

### Gagal promosi ke DC

- Pastikan DNS client menunjuk ke `192.168.56.10` SEBELUM promosi
- Pastikan hostname sudah diubah dan VM sudah restart
- Cek event log: `Get-EventLog -LogName System -Newest 20`

### DNS tidak resolve corp.local

- Pastikan DNS Server service berjalan: `Get-Service DNS`
- Cek zone: `Get-DnsServerZone`
- Restart DNS service: `Restart-Service DNS`

### nslookup timeout sebelum resolve

- Ini biasanya karena DNS client mencoba IPv6 (`::1`) dulu. Fix:
```powershell
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10
```

### A record dc1 menunjuk ke IP public

- Buka DNS Manager → hapus A record yang salah
- Matikan DNS registration di adapter PUBLIC (lihat Step 2.4)
- Jalankan `ipconfig /flushdns && ipconfig /registerdns`

### RDP dari luar tidak bisa setelah promosi DC

- Cek default gateway masih ada di adapter PUBLIC: `Get-NetRoute -InterfaceAlias "PUBLIC"`
- Cek firewall allow port 3389: `Get-NetFirewallRule -DisplayName "*Remote Desktop*"`
- Pastikan hanya adapter PUBLIC yang punya gateway

### Tidak bisa login setelah promosi

- Gunakan format: `CORP\Administrator` atau `Administrator@corp.local`
- Password sama dengan password Administrator yang kamu set saat instalasi Windows

### DNS Server menjawab query dari IP public (open resolver)

- Jalankan ulang Step 2.9 untuk set DNS listen hanya di IP internal
- Verifikasi: `dnscmd /Info /ListenAddresses` — IP public tidak boleh muncul
- Test dari luar: `nslookup corp.local <IP_PUBLIC>` harus timeout
