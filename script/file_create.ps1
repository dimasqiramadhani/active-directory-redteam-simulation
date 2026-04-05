# Script deployment yang berisi password
@"
# Deploy Script - INTERNAL USE ONLY
# Server: FILESRV
# Service Account: svc_backup
# Password: Backup2024!
# Last updated: 2024-01-15

net use \\filesrv\backup /user:CORP\svc_backup Backup2024!
"@ | Out-File "C:\Shares\IT\deploy_script.bat"

# File konfigurasi dengan credentials
@"
[Database Connection]
Server=FILESRV
Database=InventoryDB
User=svc_sql
Password=SQLService2024!
"@ | Out-File "C:\Shares\IT\db_config.txt"

# Dokumen HR
@"
Employee Onboarding Credentials
================================
New Employee Default Password: Welcome2024!
WiFi Password: CorpWiFi2024
VPN Access: vpn.corp.local
"@ | Out-File "C:\Shares\HR\onboarding_guide.txt"

# File budget Finance
@"
Q4 Budget Allocation - CONFIDENTIAL
Department budgets and salary ranges enclosed.
"@ | Out-File "C:\Shares\Finance\q4_budget.xlsx"

# File readme di Public share
@"
Welcome to CORP File Server
============================
Public share untuk file yang bisa diakses semua karyawan.
Untuk akses share departemen, hubungi IT Support.

IT Support Contact: helpdesk@corp.local
"@ | Out-File "C:\Shares\Public\README.txt"