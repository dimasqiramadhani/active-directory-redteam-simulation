# 🏢 Step 3: Instalasi Secondary Domain Controller (DC2)

## Tujuan

Menginstal DC2 sebagai Secondary (Replica) Domain Controller untuk domain `corp.local`, menyediakan redundansi dan simulasi lingkungan enterprise yang realistis.

Server ini menggunakan **dua network adapter** seperti DC1:
- **Adapter PUBLIC** — IP public untuk akses RDP dari luar
- **Adapter INTERNAL** — IP private untuk AD DS, DNS, dan semua traffic domain

---

## 3.1 Membuat VM / Menyiapkan Server

### Spesifikasi

| Parameter | Nilai |
|-----------|-------|
| Name | DC2 |
| OS | Windows Server 2019/2022 |
| RAM | 2 GB (atau 1.5 GB jika RAM terbatas) |
| CPU | 2 vCPU |
| Disk | 40 GB |
| Adapter 1 | PUBLIC — IP dari ISP/cloud provider (untuk RDP) |
| Adapter 2 | INTERNAL — Host-Only / private network (untuk AD) |

Instal Windows Server dengan cara yang sama seperti DC1.

---

## 3.2 Identifikasi dan Rename Adapter

Buka **PowerShell sebagai Administrator**:

```powershell
# Lihat semua adapter
Get-NetAdapter | Select-Object Name, InterfaceIndex, Status, MacAddress


# (Opsional) Lakukan sysprep terlebih dahulu jika vm yang digunakan berupa clone dari vm yang sudah ada
C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown

# Rename agar mudah dikenali
Rename-NetAdapter -Name "Ethernet 1" -NewName "PUBLIC"
Rename-NetAdapter -Name "Ethernet 2" -NewName "INTERNAL"

# Verifikasi
Get-NetAdapter | Select-Object Name, Status
```

---

## 3.3 Konfigurasi IP Static — Dual Adapter

### Adapter PUBLIC (untuk RDP dari luar)

```powershell
New-NetIPAddress -InterfaceAlias "PUBLIC" `
    -IPAddress <IP_PUBLIC_DC2> `
    -PrefixLength 24 `
    -DefaultGateway <GATEWAY_PUBLIC>
```

**PENTING:** Hanya adapter PUBLIC yang boleh punya **default gateway**.

### Adapter INTERNAL (untuk AD/DNS)

```powershell
New-NetIPAddress -InterfaceAlias "INTERNAL" `
    -IPAddress 192.168.56.11 `
    -PrefixLength 24
# JANGAN set gateway di adapter ini
```

### Konfigurasi DNS Client — Menunjuk ke DC1

**Ini perbedaan utama dengan DC1.** Sebelum join domain, DNS **harus** menunjuk ke DC1 agar DC2 bisa menemukan domain `corp.local`:

```powershell
# INTERNAL — menunjuk ke DC1
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10

# PUBLIC — juga menunjuk ke DC1 (JANGAN pakai DNS public)
Set-DnsClientServerAddress -InterfaceAlias "PUBLIC" -ServerAddresses 192.168.56.10
```

**Mengapa menunjuk ke DC1, bukan ke diri sendiri?** DC2 belum punya DNS Server. Domain `corp.local` hanya bisa di-resolve oleh DC1 yang sudah menjadi Domain Controller. Setelah DC2 dipromosikan, kita akan update konfigurasi ini.

---

## 3.4 Matikan DNS Registration di Adapter PUBLIC

Mencegah IP public DC2 terdaftar di DNS record domain:

```powershell
Set-DnsClient -InterfaceAlias "PUBLIC" -RegisterThisConnectionsAddress $false
```

Atau lewat GUI:
1. **Network Connections** → klik kanan **PUBLIC** → **Properties**
2. Pilih **IPv4** → **Properties** → klik **Advanced**
3. Tab **DNS** → **uncheck** "Register this connection's addresses in DNS"

---

## 3.5 Set Binding Order — Prioritaskan Adapter Internal

```powershell
Set-NetIPInterface -InterfaceAlias "INTERNAL" -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias "PUBLIC" -InterfaceMetric 50
```

Verifikasi:

```powershell
Get-NetIPInterface | Select-Object InterfaceAlias, InterfaceMetric, AddressFamily | Sort-Object InterfaceMetric
```

---

## 3.6 Ubah Hostname

```powershell
Rename-Computer -NewName "DC2" -Restart
```

---

## 3.7 Verifikasi Konektivitas ke DC1

**Jangan lanjut sebelum semua perintah ini berhasil:**

```powershell
# Ping DC1 via IP internal
ping 192.168.56.10

# Resolve domain name via DNS DC1
nslookup corp.local

# Resolve hostname DC1
nslookup dc1.corp.local

# Test port AD (LDAP 389, Kerberos 88)
Test-NetConnection 192.168.56.10 -Port 389
Test-NetConnection 192.168.56.10 -Port 88
```

Semua harus berhasil. Jika `nslookup corp.local` gagal, periksa konfigurasi DNS client (Step 3.3).

---

## 3.8 Instal AD DS dan Promosikan sebagai Replica DC

### Via PowerShell (Rekomendasi)

```powershell
# Instal role AD DS
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promosikan sebagai DC tambahan di domain corp.local
Install-ADDSDomainController `
    -DomainName "corp.local" `
    -InstallDns:$true `
    -Credential (Get-Credential) `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "Lab@dmin2024!" -AsPlainText -Force) `
    -Force:$true
```

Saat diminta credential, masukkan:
- Username: `CORP\Administrator`
- Password: (password Administrator domain)

**Catatan:** Perintahnya adalah `Install-ADDSDomainController`, **BUKAN** `Install-ADDSForest`. DC1 yang membuat forest baru, DC2 hanya join sebagai replica.

### Via Server Manager (GUI)

1. **Add Roles and Features** → centang **Active Directory Domain Services**
2. Setelah instal, klik notifikasi → **Promote this server to a domain controller**
3. Pilih **Add a domain controller to an existing domain**
4. Domain: `corp.local`
5. Masukkan credential `CORP\Administrator`
6. **Domain Controller Options:**
   - ✅ DNS Server
   - ✅ Global Catalog
   - DSRM Password: `Lab@dmin2024!`
7. Klik **Next** sampai selesai → **Install**
8. Server restart otomatis

---

## 3.9 Konfigurasi DNS Server — Hanya Listen di IP Internal

Setelah promosi dan restart, login sebagai `CORP\Administrator`. Sama seperti DC1, pastikan DNS Server DC2 **tidak** listen di IP public:

### Via dnscmd (Rekomendasi)

```powershell
dnscmd localhost /ResetListenAddresses 192.168.56.11
Restart-Service DNS
```

Verifikasi:

```powershell
dnscmd /Info /ListenAddresses
Get-DnsServerSetting | Select-Object -ExpandProperty ListeningIPAddress | Select-Object IPAddressToString
```

**Output yang diharapkan:** Hanya `192.168.56.11`. IP public DC2 **tidak boleh** muncul.

### Via Registry (Jika dnscmd Gagal)

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters" `
    -Name "ListenAddresses" `
    -Value @("192.168.56.11")
Restart-Service DNS
```

### Via DNS Manager (GUI)

1. Buka **DNS Manager** (`dnsmgmt.msc`)
2. Klik kanan nama server **DC2** → **Properties**
3. Tab **Interfaces**
4. Pilih **Only the following IP addresses**
5. **Centang** hanya `192.168.56.11`
6. **Uncheck** IP public dan semua IPv6
7. Klik **OK**

---

## 3.10 Update DNS Client di DC2 (Setelah Promosi)

Sekarang DC2 sudah punya DNS Server sendiri. Update agar DNS client fallback ke diri sendiri:

```powershell
# Update DNS di adapter INTERNAL — DC1 primer, DC2 (diri sendiri) sebagai fallback
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10, 192.168.56.11

# Update DNS di adapter PUBLIC
Set-DnsClientServerAddress -InterfaceAlias "PUBLIC" -ServerAddresses 192.168.56.10, 192.168.56.11
```

---

## 3.11 Update DNS Client di DC1 (Crossover Fallback)

Kembali ke **DC1**, update agar DC1 juga punya fallback ke DC2:

```powershell
# Di DC1 — update DNS agar fallback ke DC2
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10, 192.168.56.11
Set-DnsClientServerAddress -InterfaceAlias "PUBLIC" -ServerAddresses 192.168.56.10, 192.168.56.11
```

Sekarang kedua DC saling menjadi fallback DNS satu sama lain.

---

## 3.12 Bersihkan DNS Record yang Salah (Jika Ada)

Sama seperti DC1, cek apakah IP public DC2 terdaftar di DNS zone:

1. Buka **DNS Manager** (`dnsmgmt.msc`) — bisa dari DC1 atau DC2
2. Navigasi ke **Forward Lookup Zones** → **corp.local**
3. Cari A record untuk `dc2` — jika ada entry yang menunjuk ke IP public DC2, **hapus**
4. Sisakan hanya record yang menunjuk ke `192.168.56.11`

Force re-register:

```powershell
ipconfig /flushdns
ipconfig /registerdns
```

---

## 3.13 Verifikasi Replikasi

```powershell
# Cek kedua DC terdaftar
Get-ADDomainController -Filter * | Select-Object Name, IPv4Address, IsGlobalCatalog

# Verifikasi replikasi — harus 0 failures
repadmin /replsummary

# Cek status replikasi detail
repadmin /showrepl

# Force sinkronisasi semua partisi
repadmin /syncall /AdeP
```

Output yang diharapkan: `repadmin /replsummary` menunjukkan **0 failures** untuk kedua DC.

---

## 3.14 Verifikasi Keseluruhan

```powershell
# Cek A record DC2 — harus 192.168.56.11
nslookup dc2.corp.local

# Cek SRV record — harus menampilkan DC1 dan DC2
nslookup -type=SRV _ldap._tcp.corp.local

# Cek DNS tidak bisa diakses dari IP public DC2
# (dari mesin luar: nslookup corp.local <IP_PUBLIC_DC2> → harus timeout)

# Cek service berjalan
Get-Service NTDS, DNS, Netlogon, KDC
```

Pastikan:
- A record `dc2.corp.local` menunjuk ke `192.168.56.11` (bukan IP public)
- SRV record menampilkan **dua** DC: `dc1.corp.local` dan `dc2.corp.local`
- Semua service **Running**

---

## Ringkasan Perbandingan DC1 vs DC2

| Konfigurasi | DC1 | DC2 |
|-------------|-----|-----|
| IP Internal | 192.168.56.10 | 192.168.56.11 |
| DNS Client (sebelum promosi) | 192.168.56.10 (diri sendiri) | 192.168.56.10 (DC1) |
| DNS Client (setelah promosi) | 192.168.56.10, 192.168.56.11 | 192.168.56.10, 192.168.56.11 |
| Perintah promosi | `Install-ADDSForest` | `Install-ADDSDomainController` |
| DNS Listen Address | 192.168.56.10 | 192.168.56.11 |
| Reverse lookup zone | Buat manual | Otomatis replikasi dari DC1 |
| DNS Registration (PUBLIC) | ❌ Dimatikan | ❌ Dimatikan |
| Binding order (INTERNAL) | Metric 10 (prioritas) | Metric 10 (prioritas) |
| Default gateway | Hanya di PUBLIC | Hanya di PUBLIC |

---

## Mengapa Perlu Secondary DC?

Dalam environment enterprise nyata, secondary DC menyediakan:

1. **Redundansi** — jika DC1 mati, autentikasi tetap berjalan
2. **Load balancing** — request autentikasi bisa didistribusi
3. **Realisme lab** — mempraktikkan serangan yang melibatkan replikasi DC (DCSync)
4. **Attack surface tambahan** — lateral movement dari/ke DC kedua

Untuk red team, DC2 juga menjadi target yang berharga karena memiliki database AD yang identik dengan DC1.

---

## Troubleshooting

### Gagal join domain / promosi gagal

- Pastikan DNS di DC2 menunjuk ke `192.168.56.10` (DC1) SEBELUM promosi
- Cek `nslookup corp.local` — harus berhasil resolve
- Pastikan adapter INTERNAL DC1 dan DC2 di subnet yang sama
- Cek apakah DC1 bisa diakses: `Test-NetConnection 192.168.56.10 -Port 389`

### Replikasi gagal

- Cek konektivitas internal: `ping dc1.corp.local`
- Force replikasi: `repadmin /syncall /AdeP`
- Cek event log: `Get-WinEvent -LogName 'Directory Service' -MaxEvents 10`

### DNS zone tidak muncul di DC2

- Tunggu beberapa menit untuk replikasi DNS
- Force: `Sync-DnsServerZone -Name "corp.local"`
- Restart DNS: `Restart-Service DNS`

### nslookup timeout sebelum resolve

- DNS client mencoba IPv6 dulu. Fix:
```powershell
Set-DnsClientServerAddress -InterfaceAlias "INTERNAL" -ServerAddresses 192.168.56.10, 192.168.56.11
```

### A record dc2 menunjuk ke IP public

- Buka DNS Manager → hapus A record yang salah
- Pastikan DNS registration di adapter PUBLIC sudah dimatikan (Step 3.4)
- Jalankan `ipconfig /flushdns && ipconfig /registerdns`

### DNS Server DC2 menjawab query dari IP public (open resolver)

- Jalankan ulang Step 3.9 untuk set DNS listen hanya di IP internal
- Verifikasi: `dnscmd /Info /ListenAddresses` — IP public tidak boleh muncul
