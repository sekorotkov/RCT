[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ParameterSetName="ByCollectionID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [parameter(Mandatory = $true, ParameterSetName="ByResourceID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, ParameterSetName="ByCollectionID", HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [parameter(Mandatory = $true, ParameterSetName="ByResourceID", HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    , [parameter(Mandatory = $true, ParameterSetName="ByCollectionID", HelpMessage = "The unique ID of the device collection.")]
    [ValidateNotNullOrEmpty()]
    [string] $CollectionID

    , [parameter(Mandatory = $true, ParameterSetName="ByResourceID", HelpMessage = "The unique ID of the device.")]
    [ValidateNotNullOrEmpty()]
    [UInt32[]] $ResourceID
)
Begin {
    #[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]"en-US"
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"

    Write-Verbose "SiteServer       = $SiteServer"
    Write-Verbose "Namespace        = $Namespace"
    Write-Verbose "CollectionID     = $CollectionID"
    Write-Verbose "ResourceID       = $ResourceID"
}
Process {
    if ($psCmdlet.ParameterSetName -eq "ByCollectionID") {
        Write-Verbose "... running by ParameterSetName = ""$($psCmdlet.ParameterSetName)"""
        $Query = @"
        SELECT DISTINCT
            SMS_R_System.NetbiosName
            , SMS_SoftwareUpdate.LocalizedDisplayName
            , SMS_SoftwareUpdate.NumMissing
            , SMS_SoftwareUpdate.IsContentProvisioned
            , SMS_SoftwareUpdate.IsDeployed
            , SMS_SoftwareUpdate.DateRevised
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
    }
    if ($psCmdlet.ParameterSetName -eq "ByResourceID") {
        Write-Verbose "... running by ParameterSetName = ""$($psCmdlet.ParameterSetName)"""
        $Query = @"
        SELECT DISTINCT
            SMS_R_System.NetbiosName
            , SMS_SoftwareUpdate.LocalizedDisplayName
            , SMS_SoftwareUpdate.NumMissing
            , SMS_SoftwareUpdate.IsContentProvisioned
            , SMS_SoftwareUpdate.IsDeployed
            , SMS_SoftwareUpdate.DateRevised
        FROM
            SMS_R_System            
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
        WHERE SMS_R_System.ResourceID IN ($($ResourceID -join ", "))
"@
    }
    ## UpdateClassification:3689bdc8-b205-4af4-8d4a-a63924c5e9d5 - 'Upgrades'

    $Updates = Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace
    Write-Verbose "Updates count: $($Updates.Count)"
    $Updates | 
        Select-Object   @{n = "Netbios Name";  e = {$_.SMS_R_System.NetbiosName}},
                        @{n = "Update Title";           e = {$_.SMS_SoftwareUpdate.LocalizedDisplayName}},
                        @{n = "Required";               e = {$_.SMS_SoftwareUpdate.NumMissing}},
                        @{n = "Downloaded";             e = {$_.SMS_SoftwareUpdate.IsContentProvisioned}},
                        @{n = "Deployed";               e = {$_.SMS_SoftwareUpdate.IsDeployed}},
                        @{n = "Released or Revised";    e = {[System.Management.ManagementDateTimeConverter]::ToDateTime($_.SMS_SoftwareUpdate.DateRevised)}} |
        Sort-Object "Netbios Name","Released or Revised" |  Out-GridView -Wait -Title "Updates required for the computer"
}
End {
    Write-Verbose "Completed."
}