# Define variables
$ErrorLog          = "C:\FSRMscript\Error\FSRMscript.txt"
$DateTime          = Get-Date
$UpdateURL         = "https://raw.githubusercontent.com/DFFspace/CryptoBlocker/master/KnownExtensions.txt"
$FsrmFileGroupName = "Known Ransomware Files"
$Logfile           = $ErrorLog

Function LogWrite {
    Param ([string]$logstring)
    Add-Content $Logfile -Value $logstring -Encoding UTF8
}

try {
    # Get last updated date
    LogWrite "Fetching last updated date from $UpdateURL ..."
    $LastUpdated = ((Invoke-WebRequest -Uri $UpdateURL -ErrorAction Stop).Content | ConvertFrom-Json).lastupdated
    $Date = $LastUpdated.Substring(0, $LastUpdated.LastIndexOf('T'))

    # Get extensions
    LogWrite "Fetching list of extensions from $UpdateURL ..."
    $Extensions = ((Invoke-WebRequest -Uri $UpdateURL -ErrorAction Stop).Content | ConvertFrom-Json).filters

    # Check if file group exists, update or create file group accordingly
    if (Get-FsrmFileGroup -Name $FsrmFileGroupName -ErrorAction SilentlyContinue) {
        LogWrite "File group '$FsrmFileGroupName' already exists. Updating include patterns ..."
        $FSRMgroup = Get-FsrmFileGroup $FsrmFileGroupName
        $NewExtensions = Compare-Object -ReferenceObject $Extensions -DifferenceObject $FSRMgroup.IncludePattern -PassThru | Sort-Object
        $list = $FSRMgroup.IncludePattern + @($NewExtensions)
        Set-FsrmFileGroup -Name $FsrmFileGroupName -IncludePattern $list
    }
    else {
        LogWrite "Creating new file group '$FsrmFileGroupName' with include patterns ..."
        New-FsrmFileGroup -Name $FsrmFileGroupName -IncludePattern $Extensions -ErrorAction Stop | Out-Null
        $NewExtensions = $Extensions | Sort-Object
    }

    LogWrite "Script completed successfully."
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host -ForegroundColor Yellow $ErrorMessage
    LogWrite "$($DateTime) - ERROR: $ErrorMessage"
}
