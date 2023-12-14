# DeployCryptoBlocker.ps1
# Version: 1.2
#####

################################ USER CONFIGURATION ################################

# Names to use in FSRM
$fileGroupName = "CryptoBlockerGroup"
$fileTemplateName = "CryptoBlockerTemplate"
# set screening type to
# Active screening: Do not allow users to save unathorized files
$fileTemplateType = "Active"
# Passive screening: Allow users to save unathorized files (use for monitoring)
#$fileTemplateType = "Passiv"

# Write the email options to the temporary file - comment out the entire block if no email notification should be set
$EmailNotification = $env:TEMP + "\tmpEmail001.tmp"
"Notification=m" >> $EmailNotification
"To=[Admin Email]" >> $EmailNotification
## en
"Subject=Unauthorized file from the [Violated File Group] file group detected" >> $EmailNotification
"Message=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server."  >> $EmailNotification
## de
#"Subject=Nicht autorisierte Datei erkannt, die mit Dateigruppe [Violated File Group] übereinstimmt" >> $EmailNotification
#"Message=Das System hat erkannt, dass Benutzer [Source Io Owner] versucht hat, die Datei [Source File Path] unter [File Screen Path] auf Server [Server] zu speichern. Diese Datei weist Übereinstimmungen mit der Dateigruppe [Violated File Group] auf, die auf dem System nicht zulässig ist."  >> $EmailNotification

# Write the event log options to the temporary file - comment out the entire block if no event notification should be set
$EventNotification = $env:TEMP + "\tmpEvent001.tmp"
"Notification=e" >> $EventNotification
"EventType=Warning" >> $EventNotification
## en
"Message=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server." >> $EventNotification
## de
#"Message=Das System hat erkannt, dass Benutzer [Source Io Owner] versucht hat, die Datei [Source File Path] unter [File Screen Path] auf Server [Server] zu speichern. Diese Datei weist Übereinstimmungen mit der Dateigruppe [Violated File Group] auf, die auf dem System nicht zulässig ist." >> $EventNotification

# Known Extensions URL variable
$KnownExtensionsListURL = "https://raw.githubusercontent.com/DFFspace/CryptoBlocker/master/KnownExtensions.txt"

################################ USER CONFIGURATION ################################

################################ Functions ################################

Function New-CBArraySplit
{
    <# 
        Takes an array of file extensions and checks if they would make a string >4Kb, 
        if so, turns it into several arrays
    #>
    param(
        $Extensions
    )

    $Extensions = $Extensions | Sort-Object -Unique

    $workingArray = @()
    $WorkingArrayIndex = 1
    $LengthOfStringsInWorkingArray = 0

    # TODO - is the FSRM limit for bytes or characters?
    #        maybe [System.Text.Encoding]::UTF8.GetBytes($_).Count instead?
    #        -> in case extensions have Unicode characters in them
    #        and the character Length is <4Kb but the byte count is >4Kb

    # Take the items from the input array and build up a 
    # temporary workingarray, tracking the length of the items in it and future commas
    $Extensions | ForEach-Object {

        if (($LengthOfStringsInWorkingArray + 1 + $_.Length) -gt 4000) 
        {   
            # Adding this item to the working array (with +1 for a comma)
            # pushes the contents past the 4Kb limit
            # so output the workingArray
            [PSCustomObject]@{
                index = $WorkingArrayIndex
                FileGroupName = "$Script:FileGroupName$WorkingArrayIndex"
                array = $workingArray
            }
            
            # and reset the workingArray and counters
            $workingArray = @($_) # new workingArray with current Extension in it
            $LengthOfStringsInWorkingArray = $_.Length
            $WorkingArrayIndex++

        }
        else #adding this item to the workingArray is fine
        {
            $workingArray += $_
            $LengthOfStringsInWorkingArray += (1 + $_.Length)  #1 for imaginary joining comma
        }
    }

    # The last / only workingArray won't have anything to push it past 4Kb
    # and trigger outputting it, so output that one as well
    [PSCustomObject]@{
        index = ($WorkingArrayIndex)
        FileGroupName = "$Script:FileGroupName$WorkingArrayIndex"
        array = $workingArray
    }
}

################################ Functions ################################

################################ Program code ################################

# Identify Windows Server version, PowerShell version and install FSRM role
$majorVer = [System.Environment]::OSVersion.Version.Major
$minorVer = [System.Environment]::OSVersion.Version.Minor
$powershellVer = $PSVersionTable.PSVersion.Major

if ($powershellVer -le 2)
{
    Write-Host "`n####"
    Write-Host "ERROR: PowerShell v3 or higher required."
    exit
}

Write-Host "`n####"
Write-Host "Checking File Server Resource Manager.."

Import-Module ServerManager

if ($majorVer -ge 6)
{
    $checkFSRM = Get-WindowsFeature -Name FS-Resource-Manager

    if (($minorVer -ge 2 -or $majorVer -eq 10) -and $checkFSRM.Installed -ne "True")
    {
        # Server 2012 / 2016
        Write-Host "`n####"
        Write-Host "FSRM not found.. Installing (2012 / 2016).."

        $install = Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools
	if ($? -ne $True)
	{
		Write-Host "Install of FSRM failed."
		exit
	}
    }
    elseif ($minorVer -ge 1 -and $checkFSRM.Installed -ne "True")
    {
        # Server 2008 R2
        Write-Host "`n####"
		Write-Host "FSRM not found.. Installing (2008 R2).."
        $install = Add-WindowsFeature FS-FileServer, FS-Resource-Manager
	if ($? -ne $True)
	{
		Write-Host "Install of FSRM failed."
		exit
	}
	
    }
    elseif ($checkFSRM.Installed -ne "True")
    {
        # Server 2008
        Write-Host "`n####"
		Write-Host "FSRM not found.. Installing (2008).."
        $install = &servermanagercmd -Install FS-FileServer FS-Resource-Manager
	if ($? -ne $True)
	{
		Write-Host "Install of FSRM failed."
		exit
	}
    }
}
else
{
    # Assume Server 2003
    Write-Host "`n####"
	Write-Host "Unsupported version of Windows detected! Quitting.."
    return
}

## Enumerate shares
Write-Host "`n####"
Write-Host "Processing ProtectList.."
### move file from C:\Windows\System32 or whatever your relative path is to the directory of this script
if (Test-Path .\ProtectList.txt)
{
    Move-Item -Path .\ProtectList.txt -Destination $PSScriptRoot\ProtectList.txt -Force
}

if (Test-Path $PSScriptRoot\ProtectList.txt)
{
    $drivesContainingShares = Get-Content $PSScriptRoot\ProtectList.txt | ForEach-Object { $_.Trim() }
}
Else {
    $drivesContainingShares =   @(Get-WmiObject Win32_Share | 
                    Select Name,Path,Type | 
                    Where-Object { $_.Type -match '0|2147483648' } | 
                    Select -ExpandProperty Path | 
                    Select -Unique)
}


if ($drivesContainingShares.Count -eq 0)
{
    Write-Host "`n####"
    Write-Host "No drives containing shares were found. Exiting.."
    exit
}

Write-Host "`n####"
Write-Host "The following shares needing to be protected: $($drivesContainingShares -Join ",")"

# Download list of CryptoLocker file extensions
Write-Host "`n####"
Write-Host "Dowloading CryptoLocker file extensions list from DFFspace/CryptoBlocker/master/KnownExtensions.txt.."

# 
$monitoredExtensions = ((Invoke-WebRequest -Uri $KnownExtensionsListURL -ErrorAction Stop).Content | ConvertFrom-Json).filters

# Process SkipList.txt
Write-Host "`n####"
Write-Host "Processing SkipList.."
### move file from C:\Windows\System32 or whatever your relative path is to the directory of this script
if (Test-Path .\SkipList.txt)
{
    Move-Item -Path .\SkipList.txt -Destination $PSScriptRoot\SkipList.txt -Force
}

If (Test-Path $PSScriptRoot\SkipList.txt)
{
    $Exclusions = Get-Content $PSScriptRoot\SkipList.txt | ForEach-Object { $_.Trim() }
    $monitoredExtensions = $monitoredExtensions | Where-Object { $Exclusions -notcontains $_ }

}
Else 
{
    $emptyFile = @'
#
# Add one filescreen per line that you want to ignore
#
# For example, if *.doc files are being blocked by the list but you want 
# to allow them, simply add a new line in this file that exactly matches 
# the filescreen:
#
# *.doc
#
# The script will check this file every time it runs and remove these 
# entries before applying the list to your FSRM implementation.
#
'@
    Set-Content -Path $PSScriptRoot\SkipList.txt -Value $emptyFile
}

# Check to see if we have any local patterns to include
Write-Host "`n####"
Write-Host "Processing IncludeList.."
### move file from C:\Windows\System32 or whatever your relative path is to the directory of this script
if (Test-Path .\IncludeList.txt)
{
    Move-Item -Path .\IncludeList.txt -Destination $PSScriptRoot\IncludeList.txt -Force
}
If (Test-Path $PSScriptRoot\IncludeList.txt)
{
    $includeExt = Get-Content $PSScriptRoot\IncludeList.txt | ForEach-Object { $_.Trim() }
    $monitoredExtensions = $monitoredExtensions + $includeExt
}

# Split the $monitoredExtensions array into fileGroups of less than 4kb to allow processing by filescrn.exe
$fileGroups = @(New-CBArraySplit $monitoredExtensions)

# Perform these steps for each of the 4KB limit split fileGroups
Write-Host "`n####"
Write-Host "Adding/replacing File Groups.."
ForEach ($group in $fileGroups) {
    #Write-Host "Adding/replacing File Group [$($group.fileGroupName)] with monitored file [$($group.array -Join ",")].."
    Write-Host "`nFile Group [$($group.fileGroupName)] with monitored files from [$($group.array[0])] to [$($group.array[$group.array.GetUpperBound(0)])].."
	&filescrn.exe filegroup Delete "/Filegroup:$($group.fileGroupName)" /Quiet
    &filescrn.exe Filegroup Add "/Filegroup:$($group.fileGroupName)" "/Members:$($group.array -Join '|')"
}

# Create File Screen Template with Notification
Write-Host "`n####"
Write-Host "Adding/replacing [$fileTemplateType] File Screen Template [$fileTemplateName] with eMail Notification [$EmailNotification] and Event Notification [$EventNotification].."
&filescrn.exe Template Delete /Template:$fileTemplateName /Quiet
# Build the argument list with all required fileGroups and notifications
$screenArgs = 'Template', 'Add', "/Template:$fileTemplateName", "/Type:$fileTemplateType"
ForEach ($group in $fileGroups) {
    $screenArgs += "/Add-Filegroup:$($group.fileGroupName)"
}
If ($EmailNotification -ne "") {
    $screenArgs += "/Add-Notification:m,$EmailNotification"
}
If ($EventNotification -ne "") {
    $screenArgs += "/Add-Notification:e,$EventNotification"
}
&filescrn.exe $screenArgs

# Create File Screens for every drive containing shares
Write-Host "`n####"
Write-Host "Adding/replacing File Screens.."
$drivesContainingShares | ForEach-Object {
    Write-Host "File Screen for [$_] with Source Template [$fileTemplateName].."
    &filescrn.exe Screen Delete "/Path:$_" /Quiet
    &filescrn.exe Screen Add "/Path:$_" "/SourceTemplate:$fileTemplateName" # "/Add-Filegroup:Custom Files"
}

# Add Folder Exceptions from ExcludeList.txt
Write-Host "`n####"
Write-Host "Processing ExcludeList.."
### move file from C:\Windows\System32 or whatever your relative path is to the directory of this script
if (Test-Path .\ExcludePaths.txt)
{
    Move-Item -Path .\ExcludePaths.txt -Destination $PSScriptRoot\ExcludePaths.txt -Force
}
If (Test-Path $PSScriptRoot\ExcludePaths.txt) {
    Get-Content $PSScriptRoot\ExcludePaths.txt | ForEach-Object {
        If (Test-Path $_) {
            # Build the argument list with all required fileGroups
			$ExclusionArgsDe = 'Exception', 'Delete', "/Path:$_" ,"/Quiet"
            $ExclusionArgs = 'Exception', 'Add', "/Path:$_"
            ForEach ($group in $fileGroups) {
                $ExclusionArgs += "/Add-Filegroup:$($group.fileGroupName)"
            }
            &filescrn.exe $ExclusionArgsDe
            &filescrn.exe $ExclusionArgs
        }
    }
}

# Cleanup temporary files if they were created
Write-Host "`n####"
Write-Host "Cleaning up temporary stuff.."
If ($EmailNotification -ne "") {
	Remove-Item $EmailNotification -Force
}
If ($EventNotification -ne "") {
	Remove-Item $EventNotification -Force
}

Write-Host "`n####"
Write-Host "Done."
Write-Host "####"

################################ Program code ################################
