# 🏢 Step 3: Instalasi Secondary Domain Controller (DC2)

## Tujuan

Menginstal DC2 sebagai Secondary (Replica) Domain Controller untuk domain `corp.local`, menyediakan redundansi dan simulasi lingkungan enterprise yang realistis.

---

## 3.1 Membuat VM

| Parameter | Nilai |
|-----------|-------|
| Name | DC2 |
| OS | Windows Server 2019/2022 |
| RAM | 2 GB (atau 1.5 GB jika RAM terbatas) |
| CPU | 2 vCPU |
| Disk | 40 GB |
| Network | Host-Only (vboxnet0 / VMnet2) |

Instal Windows Server dengan cara yang sama seperti DC1.

---

## 3.2 Konfigurasi IP Static

```powershell
# Konfigurasi IP
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.56.11 -PrefixLength 24

# DNS harus menunjuk ke DC1 terlebih dahulu
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.56.10, 127.0.0.1
```

**PENTING:** DNS harus menunjuk ke DC1 (`192.168.56.10`) SEBELUM join domain. Ini krusial karena DC2 perlu menemukan domain `corp.local` melalui DNS DC1.

---

## 3.3 Ubah Hostname

```powershell
Rename-Computer -NewName "DC2" -Restart
```

---

## 3.4 Verifikasi Konektivitas ke DC1

Sebelum melanjutkan, pastikan DC2 bisa berkomunikasi dengan DC1:

```powershell
# Ping DC1
ping 192.168.56.10

# Resolve domain name
nslookup corp.local

# Resolve DC1
nslookup dc1.corp.local
```

Semua perintah di atas harus berhasil sebelum melanjutkan.

---

## 3.5 Instal AD DS dan Promosikan sebagai Replica DC

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

## 3.6 Verifikasi Replikasi

Setelah restart, login sebagai `CORP\Administrator`:

```powershell
# Cek DC terdaftar
Get-ADDomainController -Filter *

# Verifikasi replikasi
repadmin /replsummary

# Cek status replikasi detail
repadmin /showrepl

# Pastikan tidak ada error replikasi
repadmin /syncall /AdeP
```

Output yang diharapkan: `repadmin /replsummary` menunjukkan **0 failures** untuk kedua DC.

---

## 3.7 Update DNS pada DC1

Setelah DC2 aktif, update DNS di DC1 agar punya fallback:

Di DC1, jalankan:

```powershell
# Update alternate DNS di DC1 agar menunjuk ke DC2
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1, 192.168.56.11
```

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

### Gagal join domain

- Pastikan DNS di DC2 menunjuk ke `192.168.56.10` (DC1)
- Cek `nslookup corp.local` — harus berhasil resolve
- Pastikan DC1 dan DC2 di subnet yang sama

### Replikasi gagal

- Cek konektivitas: `ping dc1.corp.local`
- Force replikasi: `repadmin /syncall /AdeP`
- Cek event log: `Get-WinEvent -LogName 'Directory Service' -MaxEvents 10`

### DNS zone tidak muncul di DC2

- Tunggu beberapa menit untuk replikasi DNS
- Force: `Sync-DnsServerZone -Name "corp.local"`
- Restart DNS: `Restart-Service DNS`
