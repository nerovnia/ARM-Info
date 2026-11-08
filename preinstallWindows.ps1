#Requires -Version 5.1

# Install the language pack only, without optional features
Install-Language -Language uk-UA -ExcludeFeatures

# Add the "Basic typing" feature (spell check, text prediction)
Add-WindowsCapability -Online -Name "Language.Basic~~~uk-UA~0.0.1.0"

# 2. Add Ukrainian to your language list

$list = Get-WinUserLanguageList
$list.Add("uk-UA")
Set-WinUserLanguageList $list -Force

# 3. Check that it worked

Get-InstalledLanguage -Language uk-UA
Get-WindowsCapability -Online | Where-Object Name -like "*uk-UA*" | Select-Object Name, State

# Optional: make Ukrainian the Windows display language


#Set-SystemPreferredUILanguage -Language uk-UA
#Set-WinUILanguageOverride -Language uk-UA
#Restart-Computer