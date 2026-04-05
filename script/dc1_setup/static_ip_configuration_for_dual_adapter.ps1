# Step 1
# For Public IP
New-NetIPAddress -InterfaceAlias "PUBLIC" `
    -IPAddress <IP_PUBLIC_DC2> `
    -PrefixLength 24 `
    -DefaultGateway <GATEWAY_PUBLIC>

# Step 2
# For Static IP
New-NetIPAddress -InterfaceAlias "INTERNAL" `
    -IPAddress 192.168.56.11 `
    -PrefixLength 24
# JANGAN set gateway di adapter ini