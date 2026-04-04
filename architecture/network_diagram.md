# 🗺️ Diagram Topologi Jaringan

## Gambaran Umum

Lab ini menggunakan **jaringan internal terisolasi** (Host-Only atau Internal Network) untuk memastikan semua traffic tetap berada di dalam lingkungan lab. Tidak ada koneksi ke internet dari jaringan lab ini.

---

## Diagram Jaringan

```
                    ┌─────────────────────────────────────────────┐
                    │          HOST MACHINE (Laptop/PC)            │
                    │         Hypervisor: VirtualBox/VMware        │
                    └─────────────────┬───────────────────────────┘
                                      │
                                      │ Virtual Network Adapter
                                      │ (Host-Only: 192.168.56.0/24)
                                      │
              ┌───────────────────────┼───────────────────────────┐
              │                       │                           │
              │          ISOLATED INTERNAL NETWORK                │
              │          Subnet: 192.168.56.0/24                  │
              │          Gateway: N/A (terisolasi)                 │
              │                                                   │
              │   ┌──────────┐    ┌──────────┐                    │
              │   │   DC1    │    │   DC2    │                    │
              │   │ .56.10   │    │ .56.11   │                    │
              │   │ Pri. DC  │◄──►│ Sec. DC  │                    │
              │   │ DNS, AD  │    │ Replica  │                    │
              │   └────┬─────┘    └────┬─────┘                    │
              │        │               │                          │
              │   ─────┴───────────────┴──────────────────        │
              │        │                        │                 │
              │   ┌────┴─────┐           ┌──────┴─────┐           │
              │   │ FILESRV  │           │ CLIENT01   │           │
              │   │ .56.20   │           │ .56.30     │           │
              │   │ File Srv │           │ Win10/11   │           │
              │   │ Svc Acct │           │ Workstation│           │
              │   └──────────┘           └────────────┘           │
              │        │                                          │
              │   ─────┴──────────────────────────────────        │
              │        │                                          │
              │   ┌────┴─────┐                                    │
              │   │  KALI    │                                    │
              │   │ .56.40   │                                    │
              │   │ Attacker │                                    │
              │   └──────────┘                                    │
              │                                                   │
              └───────────────────────────────────────────────────┘
```

---

## Penjelasan Topologi

### Mengapa Host-Only Network?

Host-Only Network (VirtualBox) atau VMnet yang terisolasi (VMware) memastikan:

1. **Isolasi penuh** — traffic lab tidak bocor ke jaringan produksi atau internet
2. **Keamanan** — tool dan teknik ofensif tetap terkurung dalam sandbox
3. **Kontrol penuh** — semua mesin berada dalam subnet yang sama dan dapat berkomunikasi langsung
4. **Reprodusibilitas** — lab bisa di-reset tanpa khawatir dampak ke jaringan luar

### Alur Komunikasi

- **DC1 ↔ DC2**: Replikasi Active Directory (AD Replication) untuk menjaga sinkronisasi database AD
- **Semua VM Windows → DC1**: DNS resolution dan autentikasi domain menggunakan DC1 sebagai Primary DNS
- **Semua VM Windows → DC2**: Fallback DNS jika DC1 tidak tersedia
- **KALI → Semua VM**: Mesin penyerang dapat menjangkau seluruh host di jaringan untuk pengujian

### Tipe Jaringan di Hypervisor

**VirtualBox:**
- Buka menu **File → Host Network Manager**
- Buat adapter baru: `vboxnet0`
- Set IP: `192.168.56.1` (ini adalah IP host di jaringan internal)
- Subnet mask: `255.255.255.0`
- Matikan DHCP Server bawaan VirtualBox

**VMware Workstation:**
- Buka **Virtual Network Editor**
- Buat VMnet baru (contoh: VMnet2)
- Tipe: Host-Only
- Subnet: `192.168.56.0`
- Subnet mask: `255.255.255.0`
- Matikan DHCP

---

## Alokasi Resource Per VM

| VM | RAM | vCPU | Disk | Catatan |
|----|-----|------|------|---------|
| DC1 | 2 GB | 2 | 40 GB | Minimum untuk AD DS + DNS |
| DC2 | 2 GB | 2 | 40 GB | Replica DC, bisa 1.5 GB jika RAM terbatas |
| FILESRV | 2 GB | 2 | 40 GB | File server + service accounts |
| CLIENT01 | 2 GB | 2 | 40 GB | Windows 10/11 desktop |
| KALI | 2 GB | 2 | 30 GB | Attacker machine |
| **TOTAL** | **10 GB** | **10** | **190 GB** | |

### Tips Optimasi untuk Laptop dengan RAM 16 GB

- Jalankan hanya 3-4 VM secara bersamaan (matikan DC2 saat tidak dibutuhkan)
- Gunakan Windows Server **Core** (tanpa GUI) untuk DC2 dan FILESRV agar hemat RAM ~500 MB per VM
- Alokasikan 1.5 GB RAM untuk DC2 jika hanya sebagai replica
- Gunakan **Thin Provisioning** untuk disk agar tidak langsung menggunakan seluruh alokasi disk
- Tutup aplikasi lain di host saat menjalankan lab
