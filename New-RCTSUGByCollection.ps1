[CmdletBinding()]
param(
    [parameter(Mandatory = $true, HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    , [parameter(Mandatory = $true, HelpMessage = "The unique ID of the device collection.")]
    [ValidateNotNullOrEmpty()]
    [string] $CollectionID

    , [parameter(Mandatory = $false, HelpMessage = "The Software Update Group name template.")]
    [string] $SUGNameTemplate
)
Begin {
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"

    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Cmdlet "New-CMSoftwareUpdateGroup" -Verbose:$false
    $SiteCode = Get-PSDrive -PSProvider CMSITE

    Add-Type -AssemblyName PresentationFramework

    if (!$SUGNameTemplate) {
        $SUGNameTemplate = "{0}-{1}-{2} {3}-{4}-{5} - Updates for $($CollectionID)"
    }
    $Now = Get-Date
    $SUGName = $SUGNameTemplate  -f $Now.ToString("yyyy"), $Now.ToString("MM"), $Now.ToString("dd"), $Now.ToString("HH"), $Now.ToString("mm"), $Now.ToString("ss")

    Write-Verbose "SiteServer = $SiteServer"
    Write-Verbose "Namespace  = $Namespace"
    Write-Verbose "CollectionID  = $CollectionID"
    Write-Verbose "SUGName  = $SUGName"
}
Process {
    $Query = @"
    SELECT DISTINCT SMS_SoftwareUpdate.CI_ID
    FROM
        SMS_FullCollectionMembership
        JOIN SMS_R_System
            ON SMS_FullCollectionMembership.ResourceID = SMS_R_System.ResourceID
        JOIN SMS_UpdateComplianceStatus
            ON SMS_R_System.ResourceID = SMS_UpdateComplianceStatus.MachineID
        JOIN SMS_SoftwareUpdate
            ON SMS_UpdateComplianceStatus.CI_ID = SMS_SoftwareUpdate.CI_ID
            AND SMS_UpdateComplianceStatus.Status = 2
            AND SMS_SoftwareUpdate.IsHidden = 0
            AND SMS_SoftwareUpdate.IsExpired = 0
            AND SMS_SoftwareUpdate.NumMissing > 0
            AND SMS_SoftwareUpdate.IsSuperseded = 0
        JOIN SMS_CIAllCategories
            ON SMS_SoftwareUpdate.CI_ID = SMS_CIAllCategories.CI_ID
            AND SMS_SoftwareUpdate.CI_ID  NOT IN (SELECT CI_ID FROM SMS_CIAllCategories WHERE CategoryInstance_UniqueID='UpdateClassification:3689bdc8-b205-4af4-8d4a-a63924c5e9d5')
    WHERE
        SMS_FullCollectionMembership.CollectionID = '$CollectionID'
"@
    ## UpdateClassification:3689bdc8-b205-4af4-8d4a-a63924c5e9d5 - 'Upgrades'

    $Updates = Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace
    Write-Verbose "Updates count: $($Updates.Count)"

        if ($Updates.Count) {
            Set-Location "$($SiteCode.Name):\"
            $SUG = New-CMSoftwareUpdateGroup -Name $SUGName -SoftwareUpdateId $Updates.CI_ID -Description "Updates required for the device CollectionID: $($CollectionID)"
            $SUG | Out-String | Write-Verbose
            if ($SUG) {
                Write-Verbose "Complete."
                [System.Windows.MessageBox]::Show("The SUG was created successfully`n""$($SUGName)""", 'Complete', 'OK', 'Asterisk') | Out-Null
            }
            else {
                Write-Verbose "Failed to create SUG: ""$($SUGName)"""
                [System.Windows.MessageBox]::Show("Failed to create SUG:`n""$($SUGName)""", 'Error', 'OK', 'Error') | Out-Null
            }
        }
        else {
            Write-Verbose "No Updates for collection members"
            [System.Windows.MessageBox]::Show("No updates for collection members", 'No updates', 'OK', 'Asterisk') | Out-Null
        }
}
End {
    Write-Verbose "Complete."
}