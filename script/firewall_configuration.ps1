# Allow SMB
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"

# Allow WinRM (untuk Evil-WinRM)
Enable-PSRemoting -Force
winrm quickconfig -q

# Allow RDP
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"