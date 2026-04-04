# 🗺️ Pemetaan MITRE ATT&CK

## Gambaran Umum

Seluruh teknik serangan yang dipraktikkan di lab ini dipetakan ke framework MITRE ATT&CK. Framework ini merupakan standar industri untuk mengkategorikan dan mengklasifikasikan teknik serangan berdasarkan taktik (tujuan) yang ingin dicapai oleh adversary.

**Referensi:** https://attack.mitre.org/

---

## Pemetaan Lengkap per Taktik

### Reconnaissance (TA0043)

| ID | Teknik | Skenario Lab | Tool |
|----|--------|-------------|------|
| T1595.001 | Active Scanning: Scanning IP Blocks | Network scanning subnet 192.168.56.0/24 | nmap |

### Discovery (TA0007)

| ID | Teknik | Skenario Lab | Tool |
|----|--------|-------------|------|
| T1046 | Network Service Discovery | Port scanning semua target | nmap |
| T1018 | Remote System Discovery | Menemukan host di domain | nmap, BloodHound |
| T1087.002 | Account Discovery: Domain Account | Enumerasi user domain via LDAP/Kerberos | ldapsearch, kerbrute, BloodHound |
| T1069.002 | Permission Groups Discovery: Domain Groups | Enumerasi group membership | ldapsearch, BloodHound, CrackMapExec |
| T1135 | Network Share Discovery | Enumerasi SMB shares | smbclient, enum4linux, CrackMapExec |
| T1016 | System Network Configuration Discovery | Mapping jaringan dan DNS | nmap, nslookup |

### Credential Access (TA0006)

| ID | Teknik | Skenario Lab | Tool |
|----|--------|-------------|------|
| T1110.003 | Brute Force: Password Spraying | Spray password umum ke semua user | CrackMapExec, kerbrute |
| T1558.003 | Steal or Forge Kerberos Tickets: Kerberoasting | Crack TGS hash dari service account dengan SPN | Impacket GetUserSPNs, Rubeus |
| T1558.004 | Steal or Forge Kerberos Tickets: AS-REP Roasting | Crack AS-REP dari akun tanpa pre-auth | Impacket GetNPUsers, Rubeus |
| T1557.001 | Adversary-in-the-Middle: LLMNR/NBT-NS Poisoning | Capture NTLMv2 hash via poisoning | Responder |
| T1003.001 | OS Credential Dumping: LSASS Memory | Dump credential dari memori LSASS | Mimikatz, secretsdump |
| T1003.002 | OS Credential Dumping: SAM | Dump hash dari SAM database | Mimikatz, secretsdump, CrackMapExec |
| T1003.006 | OS Credential Dumping: DCSync | Replikasi hash dari DC | Mimikatz, secretsdump |
| T1552.001 | Unsecured Credentials: Credentials in Files | Password ditemukan di script dan config file | smbclient, manual |

### Privilege Escalation (TA0004)

| ID | Teknik | Skenario Lab | Tool |
|----|--------|-------------|------|
| T1134.001 | Access Token Manipulation: Token Impersonation | Impersonate token DA yang login di mesin | Mimikatz |
| T1078.002 | Valid Accounts: Domain Accounts | Abuse overprivileged accounts (helpdesk) | CrackMapExec, Evil-WinRM |
| T1222.001 | File and Directory Permissions Modification | Abuse ACL GenericAll pada OU HR | BloodHound, PowerShell |
| T1543.003 | Create or Modify System Process: Windows Service | Server Operators abuse — buat service di DC | Impacket services |

### Lateral Movement (TA0008)

| ID | Teknik | Skenario Lab | Tool |
|----|--------|-------------|------|
| T1550.002 | Use Alternate Authentication Material: Pass the Hash | Autentikasi menggunakan NTLM hash | psexec, wmiexec, Evil-WinRM, CrackMapExec |
| T1550.003 | Use Alternate Authentication Material: Pass the Ticket | Autentikasi menggunakan Kerberos ticket | Mimikatz, Rubeus, Impacket |
| T1021.002 | Remote Services: SMB/Windows Admin Shares | Remote execution via SMB | psexec, smbexec, CrackMapExec |
| T1021.006 | Remote Services: Windows Remote Management | Remote shell via WinRM | Evil-WinRM |
| T1021.003 | Remote Services: Distributed Component Object Model | Remote execution via DCOM | dcomexec |

### Persistence (TA0003)

| ID | Teknik | Skenario Lab | Tool |
|----|--------|-------------|------|
| T1053.005 | Scheduled Task/Job: Scheduled Task | Buat scheduled task untuk persistence | schtasks, atexec |
| T1547.001 | Boot or Logon Autostart Execution: Registry Run Keys | Registry run key untuk autostart | reg.exe |
| T1543.003 | Create or Modify System Process: Windows Service | Buat Windows service untuk persistence | sc.exe, Impacket services |
| T1558.001 | Steal or Forge Kerberos Tickets: Golden Ticket | Buat TGT palsu dengan hash krbtgt | Mimikatz, Impacket ticketer |
| T1136.002 | Create Account: Domain Account | Buat backdoor domain admin account | net user, PowerShell |

---

## Attack Chain — Pemetaan End-to-End

```
Phase 1: DISCOVERY
├── T1046  Network Service Discovery         → nmap scan
├── T1087  Account Discovery                 → ldapsearch, kerbrute
├── T1135  Network Share Discovery           → smbclient, CrackMapExec
└── T1069  Permission Groups Discovery       → BloodHound

Phase 2: CREDENTIAL ACCESS
├── T1552  Unsecured Credentials in Files    → file share enumeration
├── T1110  Password Spraying                 → CrackMapExec, kerbrute
├── T1558  Kerberoasting + AS-REP Roasting   → Impacket, Rubeus
└── T1557  LLMNR Poisoning                   → Responder

Phase 3: PRIVILEGE ESCALATION
├── T1222  ACL Abuse (GenericAll)             → BloodHound, PowerShell
├── T1543  Server Operators Abuse             → Impacket services
└── T1134  Token Impersonation                → Mimikatz

Phase 4: LATERAL MOVEMENT
├── T1550  Pass-the-Hash / Pass-the-Ticket   → psexec, Evil-WinRM
├── T1021  Remote Services                    → wmiexec, CrackMapExec
└── T1003  DCSync                             → secretsdump, Mimikatz

Phase 5: PERSISTENCE
├── T1053  Scheduled Task                     → schtasks
├── T1547  Registry Run Keys                  → reg.exe
├── T1543  Windows Service                    → sc.exe
├── T1558  Golden Ticket                      → Mimikatz, ticketer
└── T1136  Backdoor Account                   → net user
```

---

## ATT&CK Navigator Layer

Untuk membuat visualisasi ATT&CK Navigator dari lab ini:

1. Buka https://mitre-attack.github.io/attack-navigator/
2. Klik **Create New Layer** → **Enterprise**
3. Search dan highlight teknik berikut:
   - T1046, T1018, T1087, T1069, T1135, T1016
   - T1110, T1558, T1557, T1003, T1552
   - T1134, T1078, T1222, T1543
   - T1550, T1021
   - T1053, T1547, T1136
4. Gunakan warna berbeda per taktik untuk memudahkan visualisasi
5. Export sebagai JSON atau SVG untuk dokumentasi

**Tips:** Kamu juga bisa menggunakan tool **ATT&CK Log Mapper** buatan sendiri untuk memetakan log ke teknik ATT&CK secara otomatis.
