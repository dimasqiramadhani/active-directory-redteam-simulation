# 🔴 Active Directory Red Team Lab

## Lab Simulasi Penetration Testing Active Directory untuk Praktik Offensive Security

---

## ⚠️ Disclaimer Keamanan

> **PERINGATAN: Project ini dibuat HANYA untuk tujuan edukasi.**
>
> - Gunakan **hanya** di lingkungan lab yang terisolasi
> - **JANGAN** menguji teknik ini pada sistem tanpa izin tertulis
> - Ikuti prinsip **ethical hacking** yang bertanggung jawab
> - Penulis tidak bertanggung jawab atas penyalahgunaan materi ini
> - Selalu patuhi hukum dan regulasi yang berlaku (UU ITE, Computer Fraud and Abuse Act, dll.)

---

## 📋 Gambaran Project

Project ini adalah **lab Active Directory** lengkap yang dirancang untuk mempraktikkan teknik **red team** dan **penetration testing** di lingkungan Windows domain yang realistis.

Lab ini mensimulasikan infrastruktur enterprise dengan **kesalahan konfigurasi yang disengaja** (intentional misconfigurations) agar pengguna dapat berlatih:

- Enumerasi jaringan dan domain
- Akses kredensial (credential access)
- Eskalasi hak akses (privilege escalation)
- Pergerakan lateral (lateral movement)
- Persistensi (persistence)

Semua teknik serangan dipetakan ke framework **MITRE ATT&CK**.

---

## 🏗️ Arsitektur Lab

| VM  | Hostname | OS                       | IP Address    | Peran                          |
|-----|----------|--------------------------|---------------|--------------------------------|
| VM1 | DC1      | Windows Server 2019/2022 | 192.168.56.10 | Primary Domain Controller, DNS |
| VM2 | DC2      | Windows Server 2019/2022 | 192.168.56.11 | Secondary Domain Controller    |
| VM3 | FILESRV  | Windows Server 2019/2022 | 192.168.56.20 | File Server, Service Accounts  |
| VM4 | CLIENT   | Windows 10/11            | 192.168.56.30 | Workstation Karyawan           |
| VM5 | KALI     | Kali Linux (latest)      | 192.168.56.40 | Mesin Penyerang                |

**Domain:** `corp.local`
**Subnet:** `192.168.56.0/24`
**Network Type:** Host-Only / Internal Network (terisolasi)

---

## 🎯 Skill yang Didemonstrasikan

- Desain dan deployment infrastruktur Active Directory
- Konfigurasi Windows Server (AD DS, DNS, File Services)
- Offensive security dan penetration testing
- Enumerasi domain dan jaringan
- Teknik credential access (Kerberoasting, AS-REP Roasting, Password Spraying)
- Privilege escalation di lingkungan Windows
- Lateral movement (Pass-the-Hash, Pass-the-Ticket)
- Pemetaan serangan ke MITRE ATT&CK framework
- Penggunaan tool red team (BloodHound, Impacket, Mimikatz, dll.)

---

## 🗺️ Referensi MITRE ATT&CK

| Teknik                | ATT&CK ID | Kategori             |
|-----------------------|-----------|----------------------|
| Network Scanning      | T1046     | Discovery            |
| LDAP Enumeration      | T1018     | Discovery            |
| Password Spraying     | T1110.003 | Credential Access    |
| Kerberoasting         | T1558.003 | Credential Access    |
| AS-REP Roasting       | T1558.004 | Credential Access    |
| LLMNR Poisoning       | T1557.001 | Credential Access    |
| OS Credential Dumping | T1003     | Credential Access    |
| Pass-the-Hash         | T1550.002 | Lateral Movement     |
| Pass-the-Ticket       | T1550.003 | Lateral Movement     |
| Token Impersonation   | T1134     | Privilege Escalation |
| Scheduled Task        | T1053.005 | Persistence          |
| Registry Run Keys     | T1547.001 | Persistence          |
| Windows Service       | T1543.003 | Persistence          |

---

## 🛠️ Tool yang Digunakan

| Tool                    | Fungsi                                   |
|-------------------------|------------------------------------------|
| BloodHound + SharpHound | Visualisasi attack path AD               |
| Impacket                | Suite tool Python untuk protokol Windows |
| CrackMapExec (NetExec)  | Swiss army knife untuk pentesting AD     |
| Mimikatz                | Ekstraksi kredensial Windows             |
| Rubeus                  | Serangan Kerberos                        |
| Responder               | LLMNR/NBT-NS poisoning                   |
| enum4linux              | Enumerasi SMB/NetBIOS                    |
| Evil-WinRM              | Remote shell via WinRM                   |
| ldapsearch              | Enumerasi LDAP                           |
| smbclient               | Akses SMB share                          |

---

## 📚 Tujuan Pembelajaran

Setelah menyelesaikan lab ini, pengguna diharapkan mampu:

1. Membangun lingkungan Active Directory enterprise dari nol
2. Memahami arsitektur dan komponen Active Directory
3. Melakukan enumerasi domain secara menyeluruh
4. Mengeksploitasi misconfiguration umum di Active Directory
5. Menjalankan teknik credential access tingkat lanjut
6. Memahami dan mempraktikkan lateral movement
7. Membuat persistence di lingkungan Windows domain
8. Memetakan seluruh aktivitas ke framework MITRE ATT&CK
9. Menggunakan tool red team standar industri
10. Mendokumentasikan temuan secara profesional

---

## 📁 Struktur Project

```
ad-redteam-lab/
│
├── README.md                          # Dokumentasi utama (file ini)
│
├── architecture/
│   ├── network_diagram.md             # Diagram topologi jaringan
│   └── ip_scheme.md                   # Skema IP addressing
│
├── setup/
│   ├── 01_network.md                  # Konfigurasi jaringan virtual
│   ├── 02_dc1.md                      # Instalasi Domain Controller utama
│   ├── 03_dc2.md                      # Instalasi Domain Controller kedua
│   ├── 04_filesrv.md                  # Instalasi File Server
│   ├── 05_client.md                   # Instalasi workstation Windows
│   └── 06_kali.md                     # Setup mesin Kali Linux
│
├── active_directory/
│   ├── users.md                       # Daftar user dan konfigurasi
│   ├── groups.md                      # Daftar group dan membership
│   ├── ou_structure.md                # Struktur Organizational Unit
│   └── service_accounts.md            # Konfigurasi service account
│
├── misconfigurations/
│   ├── kerberoast.md                  # Setup Kerberoastable SPN
│   ├── weak_permissions.md            # Misconfiguration permission
│   └── delegation.md                  # Unconstrained delegation
│
├── attacks/
│   ├── enumeration.md                 # Skenario enumerasi
│   ├── credential_access.md           # Skenario credential access
│   ├── privilege_escalation.md        # Skenario privilege escalation
│   ├── lateral_movement.md            # Skenario lateral movement
│   └── persistence.md                 # Skenario persistence
│
└── resources/
    ├── tools_list.md                  # Daftar tool dan instalasi
    └── mitre_attack_mapping.md        # Pemetaan lengkap MITRE ATT&CK
```

---

## 🚀 Cara Memulai

1. Baca `architecture/` untuk memahami desain jaringan
2. Ikuti panduan di `setup/` secara berurutan (01 → 06)
3. Konfigurasi AD sesuai panduan di `active_directory/`
4. Terapkan misconfiguration dari `misconfigurations/`
5. Jalankan skenario serangan di `attacks/`
6. Referensikan `resources/` untuk daftar tool dan mapping ATT&CK

---

## 💻 Kebutuhan Hardware Minimum

| Resource       | Minimum                             | Rekomendasi            |
|----------------|-------------------------------------|------------------------|
| RAM            | 16 GB                               | 32 GB                  |
| CPU            | 4 Core                              | 8 Core                 |
| Storage        | 100 GB SSD                          | 200 GB SSD             |
| Virtualization | VirtualBox 7.x / VMware Workstation | VMware Workstation Pro |

---

## 📄 Disclaimer

Project ini dibuat **murni untuk tujuan edukasi** dalam bidang cybersecurity.
