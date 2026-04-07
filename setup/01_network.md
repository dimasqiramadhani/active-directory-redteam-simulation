# 🌐 Step 1: Konfigurasi Jaringan Virtual

## Tujuan

Menyiapkan jaringan internal terisolasi agar semua VM dapat berkomunikasi satu sama lain melalui adapter kedua (INTERNAL), sementara adapter pertama (PUBLIC) digunakan untuk akses RDP dari luar.

---

## Arsitektur Jaringan Dual-Adapter

Setiap VM/server memiliki **dua network adapter**:

```
Internet / Public Network
        │
   ┌────┴────────────────────────────────────────┐
   │              ADAPTER 1 (PUBLIC)             │
   │         IP Public dari ISP/cloud            │
   │         Untuk: RDP, SSH, akses luar         │
   └────┬────────────────────────────────────────┘
        │
   ┌────┴────────────────────────────────────────┐
   │              SEMUA VM / SERVER              │
   └────┬────────────────────────────────────────┘
        │
   ┌────┴────────────────────────────────────────┐
   │            ADAPTER 2 (INTERNAL)             │
   │         Subnet: 192.168.56.0/24             │
   │         Untuk: AD, DNS, domain traffic      │
   └────┬────────────────────────────────────────┘
        │
   ┌────┴────────────────────────────────────────┐
   │                DC1(.10)                     │
   │                DC2(.11)                     │
   │                FILESRV(.20)                 │
   │                CLIENT(.30)                  │ 
   │                KALI(.40)                    │
   └─────────────────────────────────────────────┘
```

---

## Alokasi IP — Adapter INTERNAL

| Hostname | IP Address    | Subnet Mask   | Peran           |
|----------|---------------|---------------|-----------------|
| DC1      | 192.168.56.10 | 255.255.255.0 | Primary DC, DNS |
| DC2      | 192.168.56.11 | 255.255.255.0 | Replica DC, DNS |
| FILESRV  | 192.168.56.20 | 255.255.255.0 | File Server     |
| KALI     | 192.168.56.40 | 255.255.255.0 | Attacker        |

**Catatan:** Adapter PUBLIC menggunakan IP yang diberikan oleh ISP/cloud provider masing-masing.

---

## Aturan Penting Dual-Adapter

| Aturan            | Detail                                                             |
|-------------------|--------------------------------------------------------------------|
| Default gateway   | **Hanya** di adapter PUBLIC                                        |
| DNS client        | Semua adapter menunjuk ke IP **internal** DC (192.168.56.10)       |
| DNS registration  | **Matikan** di adapter PUBLIC                                      |
| Binding order     | Adapter INTERNAL harus prioritas lebih tinggi (metric lebih kecil) |
| DNS Server listen | Hanya di IP internal (berlaku untuk DC1 dan DC2)                   |

---

## Setup Jaringan Internal

### VirtualBox

1. Buka **File** → **Host Network Manager**
2. Klik **Create** → buat adapter `vboxnet0`
3. IPv4 Address: `192.168.56.1`, Subnet mask: `255.255.255.0`
4. **Uncheck** DHCP Server
5. Setiap VM → **Settings** → **Network** → **Adapter 2**:
   - Attached to: `Host-only Adapter`
   - Name: `vboxnet0`
   - Promiscuous Mode: `Allow All`

### VMware Workstation

1. Buka **Edit** → **Virtual Network Editor** → **Change Settings**
2. **Add Network** → pilih VMnet (contoh: VMnet2)
3. Type: `Host-only`, Subnet: `192.168.56.0`, Mask: `255.255.255.0`
4. **Uncheck** DHCP
5. Setiap VM → **Settings** → **Network Adapter 2** → Custom: VMnet2

### Cloud / VPS

Jika menggunakan cloud provider (AWS, GCP, Azure, dll.):
- Adapter PUBLIC = interface utama dengan IP public
- Adapter INTERNAL = tambahkan **secondary network interface** di private subnet (contoh: 192.168.56.0/24)
- Pastikan semua VM berada di private subnet yang sama

---

## Urutan Setup yang Benar

**PENTING:** Ikuti urutan ini untuk menghindari error dependency:

```
Step 1  → Konfigurasi jaringan (file ini)
Step 2  → Instalasi DC1 (Primary Domain Controller)
Step 3  → Instalasi DC2 (Replica Domain Controller)

--- Sebelum setup server lain, buat AD objects di DC1: ---
         → ou_structure.md  (Buat OU)
         → Turunkan password policy
         → users.md         (Buat semua user)
         → groups.md        (Buat group + assign member)
         → service_accounts.md (Buat service account + SPN)

Step 4  → Instalasi FILESRV (join domain + buat shares)
Step 5  → Instalasi CLIENT01 (join domain)
Step 6  → Setup Kali Linux (attacker)
```

**Mengapa urutan ini penting?**
- OU harus ada sebelum user dibuat (user ditempatkan di OU)
- User harus ada sebelum group bisa assign member
- Group harus ada sebelum SMB share bisa set permission (contoh: `CORP\Finance Users`)
- Service account harus ada sebelum SPN bisa didaftarkan

---

## Alokasi Resource Per VM

| VM        | RAM      | vCPU  | Disk       | Catatan     |
|-----------|----------|-------|------------|-------------|
| DC1       | 2 GB     | 2     | 40 GB      | AD DS + DNS |
| DC2       | 2 GB     | 2     | 40 GB      | Replica DC  |
| FILESRV   | 2 GB     | 2     | 40 GB      | File Server |
| KALI      | 2 GB     | 2     | 30 GB      | Attacker    |
| **TOTAL** | **8 GB** | **8** | **150 GB** |             |

### Tips Optimasi untuk RAM Terbatas

- Matikan DC2 saat tidak dibutuhkan
- Gunakan Windows Server **Core** (tanpa GUI) untuk DC2 agar hemat ~500 MB
- Gunakan **Thin Provisioning** untuk disk
- Tutup aplikasi lain di host saat menjalankan lab

---

## Verifikasi Jaringan

Setelah semua VM dikonfigurasi, dari setiap VM jalankan:

```powershell
# Windows — ping semua host internal
ping 192.168.56.10
ping 192.168.56.11
ping 192.168.56.20
ping 192.168.56.40
```

```bash
# Kali — ping semua host internal
ping -c 3 192.168.56.10
ping -c 3 192.168.56.11
ping -c 3 192.168.56.20
```

Jika ping gagal dari Windows:

```powershell
# Allow ICMP di firewall
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Action Allow
```
