#Requires -RunAsAdministrator
$VerbosePreference = 'Continue'
<#
Special extension is extension where is no have special environment variable
Root nodes does not have:
- ##SUB:__SERVER##
- ##SUB:__Namespace##

so we need get server name and namespace from local computer and add is as constant
#>

$SpecialExtensionPaths = @(    
    "23e7a3fe-b0f0-4b24-813a-dc425239f9a2\Remove-RCTUpdateFromSUGSUP.ps1.xml"
    "49d3a24f-5fe5-46f1-92c9-996cb804607b\Remove-RCTUpdateFromSUGSUP.ps1.xml"
    "ac950be1-9f55-4c02-a9b0-0c664484fbd1\Sync-RCTAllEnabled3rdParty.ps1.xml"
)

# Batch file do this:
#
# ECHO Copy XML configs:
# XCOPY "%_home%Xml-RCT\*.xml" %_admincosole% /S /I /F /Y
# PAUSE

# Get- SiteServer and SiteCode from registry (Last connected Console)
$SiteServer = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\ConfigMgr10\AdminUI\MRU\1' -Name 'ServerName' -ErrorAction 0
$SiteCode = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\ConfigMgr10\AdminUI\MRU\1' -Name 'SiteCode' -ErrorAction 0

Write-Verbose "Registry SiteServer  = $SiteServer"
Write-Verbose "Registry SiteCode    = $SiteCode"

if ($SiteServer -and $SiteCode) {
    $Namespace = "ROOT\SMS\site_$($SiteCode)"
    foreach ($SpecialExtensionPath in $SpecialExtensionPaths) {
        ## $SpecialExtensionPath = $SpecialExtensionPaths[0]
        $XmlPath = Join-Path "$($env:SMS_ADMIN_UI_PATH)\..\..\XmlStorage\Extensions\Actions\" $SpecialExtensionPath
        Write-Verbose "... SpecialExtensionPath = $XmlPath"
        if(Test-Path $XmlPath) {
            Write-Verbose "... Edit: $XmlPath"
            (Get-Content $XmlPath -Encoding UTF8 -Raw) -f $SiteServer, $Namespace | Out-File -FilePath $XmlPath -Encoding utf8 -Force
        } else {
            Write-Verbose "Test-Path $XmlPath is False, skip"
        }
    }
} else {
    Write-Verbose "No `"SiteServer`" or/and `"SiteCode`" found in registry!`nPlease Connect MEMCM console to site server and Run again!`nOr add this manual to xml file extension."
}
