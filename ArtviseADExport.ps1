$ErrorActionPreference = 'Stop'
Import-Module -Name 'Microsoft.PowerShell.Management' # gMSA workaround
Import-Module -Name 'Microsoft.PowerShell.Utility' # gMSA workaround
Import-Module -Name 'Microsoft.PowerShell.Security' # gMSA workaround
Import-Module -Name 'ActiveDirectory'
. "$PSScriptRoot\Config.ps1"

function AddAttribute($XmlDoc, $Name, $Value)
{
    $attr = $xml.CreateAttribute($name)
    $attr.Value = $value
    [void]$xml.Objects.Attributes.Append($attr)
}

$params = @{
    Filter = $Script:Config.Filter
    Properties = @(
        'extensionAttribute14'
        'department'
        'physicalDeliveryOfficeName'
        'title'
        'mail'
        'telephoneNumber'
        'sAMAccountName'
        'AccountExpirationDate'
    )
}
$selectProps = @(
    @{n='objectGUID';e={[System.Guid]([byte[]][System.Text.Encoding]::UTF8.GetBytes($_.ExtensionAttribute14)[0..15])}}
    @{n='active';e={$_.Enabled -and ((Get-Date) -lt $_.AccountExpirationDate -or $_.AccountExpirationDate -eq $null)}}
    'SAMAccountName'
    'givenName'
    @{n='sn';e={$_.Surname}}
    'department'
    'physicalDeliveryOfficeName'
    'title'
    'mail'
    'telephoneNumber'
)
$xml = $Script:Config.OuToExport | foreach {Get-ADUser @params -SearchBase $_} | select $selectProps | ConvertTo-Xml -NoTypeInformation
AddAttribute -XmlDoc $xml -Name 'Source' -Value 'kungsbacka.se'
AddAttribute -XmlDoc $xml -Name 'Domain' -Value 'KBA'
AddAttribute -XmlDoc $xml -Name 'Exported' -Value (Get-Date -Format 's')
$xml.Save("$PSScriptRoot\export.xml")
$params = @{
    Uri = $Script:Config.UploadUri
    Credential = (New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList @($Script:Config.Username, ($Script:Config.Password | ConvertTo-SecureString)))
    Method = 'Put'
    InFile = "$PSScriptRoot\export.xml"
}
Invoke-WebRequest @params
Start-Sleep -Seconds 2 # Invoke-WebRequest doesn't release the file immediately
Remove-Item -Path "$PSScriptRoot\export.xml"
