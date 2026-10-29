#Requires -Version 5.1
<#
.SYNOPSIS
    Collects device name, internet-connected adapters and ESET ProductInstanceID
    from one or more computers and returns one object per machine.

.DESCRIPTION
    The local machine is queried directly. Remote machines are queried in
    parallel over PowerShell Remoting (WinRM must be enabled on them).
    Machines that can't be reached still get a row, with Status = 'Unreachable'.

.EXAMPLE
    .\Get-DeviceInventory.ps1
    Local machine only.

.EXAMPLE
    .\Get-DeviceInventory.ps1 -ComputerName PC01, PC02, PC03 -CsvPath .\inventory.csv

.EXAMPLE
    Get-Content .\computers.txt | .\Get-DeviceInventory.ps1 -Credential (Get-Credential) |
        Format-Table ComputerName, Status, ProductInstanceID, MacAddresses

.EXAMPLE
    Get-ADComputer -Filter 'OperatingSystem -like "*Windows 1*"' |
        Select-Object -ExpandProperty DNSHostName |
        .\Get-DeviceInventory.ps1 -CsvPath .\inventory.csv
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('Name', 'DNSHostName', 'CN')]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [pscredential]$Credential,

    # Optional: also save the results as CSV (UTF-8)
    [string]$CsvPath,

    [int]$ThrottleLimit = 32
)

begin {
    # Runs on each target machine. Must be self-contained (no outer variables).
    $collect = {
        $logDir  = 'C:\ProgramData\ESET\RemoteAdministrator\Agent\EraAgentApplicationData\Logs'
        $pattern = 'InstallConfiguration: ProductInstanceID:\s*([A-Za-z0-9-]+)'

        $adapters = @(
            Get-NetConnectionProfile -ErrorAction SilentlyContinue |
                Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' } |
                ForEach-Object {
                    $a = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
                    if ($a) {
                        [PSCustomObject]@{
                            Interface   = $a.Name
                            Description = $a.InterfaceDescription
                            MacAddress  = $a.MacAddress -replace '-', ':'
                            Network     = $_.Name
                            LinkSpeed   = $a.LinkSpeed
                        }
                    }
                }
        )

        $productInstanceId = $null
        $idSource          = $null

        if (-not (Test-Path -LiteralPath $logDir)) {
            $idStatus = 'AgentLogFolderMissing'
        } else {
            $match = Get-ChildItem -LiteralPath $logDir -Filter 'trace*' -File `
                        -ErrorAction SilentlyContinue -ErrorVariable gciErr |
                Sort-Object LastWriteTime |
                Select-String -Pattern $pattern -ErrorAction SilentlyContinue |
                Select-Object -Last 1

            if ($match) {
                $productInstanceId = $match.Matches[0].Groups[1].Value
                $idSource          = "$($match.Filename):$($match.LineNumber)"
                $idStatus          = 'Found'
            } elseif ($gciErr) {
                $idStatus = 'LogAccessDenied'
            } else {
                $idStatus = 'NotFoundInLogs'
            }
        }

        [PSCustomObject]@{
            DeviceName        = [System.Net.Dns]::GetHostName()
            ProductInstanceID = $productInstanceId
            IdStatus          = $idStatus
            IdSource          = $idSource
            Adapters          = $adapters
        }
    }

    $localNames = @('.', 'localhost', '127.0.0.1', $env:COMPUTERNAME,
                    [System.Net.Dns]::GetHostName())
    try { $localNames += [System.Net.Dns]::GetHostEntry('').HostName } catch { }  # FQDN, if resolvable

    $targets = [System.Collections.Generic.List[string]]::new()
    $results = [System.Collections.Generic.List[object]]::new()

    # Turns a raw result into one flat, CSV-friendly row
    function ConvertTo-Row {
        param($ComputerName, $Raw, [string]$Status = 'OK', [string]$ErrorMessage)

        $ad = @($Raw.Adapters)
        [PSCustomObject]@{
            ComputerName      = $ComputerName
            Status            = $Status
            DeviceName        = $Raw.DeviceName
            ProductInstanceID = $Raw.ProductInstanceID
            IdStatus          = $Raw.IdStatus
            IdSource          = $Raw.IdSource
            Interfaces        = ($ad.Interface   -join '; ')
            MacAddresses      = ($ad.MacAddress  -join '; ')
            Networks          = ($ad.Network     -join '; ')
            LinkSpeeds        = ($ad.LinkSpeed   -join '; ')
            Descriptions      = ($ad.Description -join '; ')
            CollectedAt       = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Error             = $ErrorMessage
        }
    }
}

process {
    foreach ($c in $ComputerName) {
        if ($c -and -not $targets.Contains($c)) { $targets.Add($c) }
    }
}

end {
    $local  = @($targets | Where-Object { $localNames -contains $_ })
    $remote = @($targets | Where-Object { $localNames -notcontains $_ })

    # Local machine: run directly, no WinRM needed
    foreach ($c in $local) {
        try   { $results.Add((ConvertTo-Row -ComputerName $c -Raw (& $collect))) }
        catch { $results.Add((ConvertTo-Row -ComputerName $c -Raw $null -Status 'Error' -ErrorMessage $_.Exception.Message)) }
    }

    # Remote machines: in parallel over PowerShell Remoting
    if ($remote.Count) {
        $icParams = @{
            ComputerName  = $remote
            ScriptBlock   = $collect
            ThrottleLimit = $ThrottleLimit
            ErrorAction   = 'SilentlyContinue'
            ErrorVariable = 'remoteErrors'
        }
        if ($Credential) { $icParams.Credential = $Credential }

        $remoteResults = @(Invoke-Command @icParams)

        foreach ($r in $remoteResults) {
            $results.Add((ConvertTo-Row -ComputerName $r.PSComputerName -Raw $r))
        }

        # Any target with no result gets an 'Unreachable' row with the error, if known
        $answered = @($remoteResults.PSComputerName)
        foreach ($c in $remote | Where-Object { $answered -notcontains $_ }) {
            $err = $remoteErrors | Where-Object {
                $_.TargetObject -eq $c -or $_.OriginInfo.PSComputerName -eq $c
            } | Select-Object -First 1
            $msg = if ($err) { $err.Exception.Message } else { 'No response' }
            $results.Add((ConvertTo-Row -ComputerName $c -Raw $null -Status 'Unreachable' -ErrorMessage $msg))
        }
    }

    $sorted = $results | Sort-Object ComputerName

    if ($CsvPath) {
        $sorted | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Saved $($sorted.Count) row(s) to $CsvPath" -ForegroundColor Cyan
    }

    $sorted
}