# Ini adalah file script otomatis untuk menjalankan semua prompt dari powershell

# Step 1
# Lihat Semua Adapter\
Get-NetAdapter | Select-Object Name, InterfaceIndex, Status, MacAddress

# Step 2
# (Opsional) Lakukan sysrep terlebih dahulu jika vm yang digunakan berupa clone dari vm yang lain
C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown

# Step 3
# Rename agar mudah dikenali
Rename-NetAdapter -Name "Ethernet" -NewName "PUBLIC"
Rename-NetAdapter -Name "Ethernet 2" -NewName "INTERNAL"

# Step 4
# Verifikasi
Get-NetAdapter | Select-Object Name, Status