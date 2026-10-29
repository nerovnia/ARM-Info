# 1. Device name (Settings > System > About > Device name)
$deviceName = [System.Net.Dns]::GetHostName()

# 2. Interfaces that Windows reports as having Internet access

# $internetAdapters = Get-NetConnectionProfile |
#     Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' } |
#     ForEach-Object {
#         $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex
#         [PSCustomObject]@{
#             Interface   = $adapter.Name
#             Description = $adapter.InterfaceDescription
#             MacAddress  = $adapter.MacAddress -replace '-', ':'
#             Network     = $_.Name
#             LinkSpeed   = $adapter.LinkSpeed
#         }
#     }

$internetAdapters | Format-Table -AutoSize | Out-Host

Write-Host "Device name: $deviceName" -ForegroundColor Cyan
$internetAdapters | Format-Table -AutoSize


$logDir  = 'C:\ProgramData\ESET\RemoteAdministrator\Agent\EraAgentApplicationData\Logs'
$pattern = 'InstallConfiguration: ProductInstanceID:\s*([A-Za-z0-9-]+)'

$match = Get-ChildItem -Path $logDir -Filter 'trace*' -File |
    Sort-Object LastWriteTime |
    Select-String -Pattern $pattern |
    Select-Object -Last 1

if ($match) {
    $productInstanceId = $match.Matches[0].Groups[1].Value
    Write-Host "ProductInstanceID: $productInstanceId" -ForegroundColor Cyan
} else {
    Write-Warning "ProductInstanceID not found in $logDir"
}


Get-ChildItem $logDir -Filter 'trace*' -File |
    Select-String -Pattern $pattern |
    ForEach-Object { $_.Line }