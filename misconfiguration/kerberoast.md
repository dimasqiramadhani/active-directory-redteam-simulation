# 🎫 Misconfiguration: Kerberoastable Service Accounts

## Apa itu Kerberoasting?

Kerberoasting memanfaatkan cara kerja Kerberos di Active Directory. Ketika user meminta akses ke service (misalnya SQL Server), KDC mengeluarkan TGS (Ticket Granting Service) yang dienkripsi dengan password hash dari service account yang menjalankan service tersebut.

Masalahnya: **siapa pun** dengan akun domain valid bisa meminta TGS untuk SPN apa pun — tidak perlu privilege khusus. Attacker kemudian bisa mengekstrak TGS dan crack password-nya secara offline.

**MITRE ATT&CK:** T1558.003 — Steal or Forge Kerberos Tickets: Kerberoasting

---

## Konfigurasi yang Sudah Diterapkan

Lihat `active_directory/service_accounts.md` — tiga service account sudah dibuat dengan SPN:

- `svc_backup` → SPN: `CIFS/filesrv.corp.local`
- `svc_sql` → SPN: `MSSQLSvc/filesrv.corp.local:1433`
- `svc_web` → SPN: `HTTP/filesrv.corp.local`

---

## Mengapa Ini Berbahaya di Dunia Nyata?

1. **Tidak membutuhkan privilege tinggi** — akun domain user biasa sudah cukup
2. **Tidak memicu alert standar** — meminta TGS adalah operasi Kerberos normal
3. **Offline cracking** — setelah mendapat TGS, cracking dilakukan offline tanpa batas percobaan
4. **Password service account sering lemah** — dan jarang dirotasi
5. **Service account sering overprivileged** — bisa menjadi jalur ke Domain Admin

---

## Cara Menguji (dari Kali)

```bash
# Enumerasi user dengan SPN menggunakan Impacket
impacket-GetUserSPNs corp.local/j.doe:Welcome2024! -dc-ip 192.168.56.10

# Request TGS dan simpan hash
impacket-GetUserSPNs corp.local/j.doe:Welcome2024! -dc-ip 192.168.56.10 -request -outputfile kerberoast_hashes.txt

# Crack menggunakan hashcat
hashcat -m 13100 kerberoast_hashes.txt /usr/share/wordlists/rockyou.txt

# Atau menggunakan John the Ripper
john --wordlist=/usr/share/wordlists/rockyou.txt kerberoast_hashes.txt
```

---

## Mitigasi di Dunia Nyata

- Gunakan Managed Service Accounts (MSA/gMSA) yang otomatis mengganti password
- Gunakan password yang sangat panjang (25+ karakter) untuk service account
- Minimalkan jumlah user account dengan SPN
- Monitor request TGS yang tidak biasa (Event ID 4769)
