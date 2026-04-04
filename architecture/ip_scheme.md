# 📋 Skema IP Addressing

## Tabel Alokasi IP

| Hostname | IP Address | Subnet Mask | Gateway | DNS Primer | DNS Sekunder |
|----------|-----------|-------------|---------|------------|-------------|
| DC1 | 192.168.56.10 | 255.255.255.0 | - | 127.0.0.1 | 192.168.56.11 |
| DC2 | 192.168.56.11 | 255.255.255.0 | - | 192.168.56.10 | 127.0.0.1 |
| FILESRV | 192.168.56.20 | 255.255.255.0 | - | 192.168.56.10 | 192.168.56.11 |
| CLIENT01 | 192.168.56.30 | 255.255.255.0 | - | 192.168.56.10 | 192.168.56.11 |
| KALI | 192.168.56.40 | 255.255.255.0 | - | 192.168.56.10 | 192.168.56.11 |

**Catatan:** Gateway dikosongkan karena jaringan ini terisolasi (tidak ada akses internet).

---

## Detail Domain

| Parameter | Nilai |
|-----------|-------|
| Domain Name | corp.local |
| NetBIOS Name | CORP |
| Forest Functional Level | Windows Server 2016 (minimum) |
| Domain Functional Level | Windows Server 2016 (minimum) |

---

## Mengapa Harus Static IP?

Active Directory **sangat bergantung** pada DNS yang stabil. Berikut alasannya:

### 1. Domain Controller Harus Selalu Bisa Ditemukan

Domain Controller mendaftarkan **SRV record** di DNS (contoh: `_ldap._tcp.corp.local`). Jika IP DC berubah karena DHCP, semua mesin di domain kehilangan kemampuan untuk menemukan DC dan autentikasi gagal.

### 2. DNS adalah Fondasi Active Directory

Active Directory menggunakan DNS untuk:
- **Lokasi service** — client mencari DC melalui SRV record
- **Replikasi antar DC** — DC1 dan DC2 harus bisa saling menemukan
- **Domain join** — mesin baru harus resolve nama domain ke IP DC
- **Kerberos authentication** — ticket request membutuhkan resolusi DNS yang benar

### 3. Konsistensi Konfigurasi

Jika IP berubah, maka perlu update di banyak tempat:
- DNS records
- Konfigurasi DNS client di setiap mesin
- Service yang terikat ke IP tertentu
- Firewall rules (jika ada)

Menggunakan static IP menghilangkan semua risiko tersebut.

---

## Konfigurasi DNS untuk Active Directory

### Pada DC1 (Primary Domain Controller)

DC1 menjalankan **DNS Server role** dan menjadi authoritative DNS untuk zona `corp.local`.

Konfigurasi DNS pada DC1 sendiri:
- **Preferred DNS:** `127.0.0.1` (menunjuk ke diri sendiri)
- **Alternate DNS:** `192.168.56.11` (DC2 sebagai fallback)

### Pada DC2 (Secondary Domain Controller)

Setelah DC2 dipromosikan menjadi DC, ia juga menjalankan DNS Server dan melakukan replikasi zona DNS dari DC1.

Konfigurasi DNS pada DC2:
- **Preferred DNS:** `192.168.56.10` (DC1 sebagai primer)
- **Alternate DNS:** `127.0.0.1` (diri sendiri sebagai fallback)

### Pada Semua Member (FILESRV, CLIENT01, KALI)

- **Preferred DNS:** `192.168.56.10` (DC1)
- **Alternate DNS:** `192.168.56.11` (DC2)

**PENTING:** Jangan pernah menggunakan DNS publik (seperti 8.8.8.8) sebagai DNS primer pada mesin yang tergabung ke domain. DNS harus selalu menunjuk ke Domain Controller agar resolusi nama domain internal berjalan dengan benar.

---

## Verifikasi DNS

Setelah konfigurasi, jalankan perintah berikut dari setiap mesin Windows untuk memverifikasi:

```powershell
# Cek konfigurasi DNS
ipconfig /all

# Test resolusi nama domain
nslookup corp.local

# Test resolusi nama DC
nslookup dc1.corp.local

# Test SRV record (bukti AD DNS berfungsi)
nslookup -type=SRV _ldap._tcp.corp.local

# Dari Kali Linux
nslookup corp.local 192.168.56.10
dig @192.168.56.10 corp.local
dig @192.168.56.10 _ldap._tcp.corp.local SRV
```
