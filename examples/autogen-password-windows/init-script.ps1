Install-WindowsFeature -name Web-Server -IncludeManagementTools
New-Item -Path "C:\inetpub\wwwroot\index.html" -ItemType "file" -Value "<html><body><h1>Healthy</h1></body></html>"