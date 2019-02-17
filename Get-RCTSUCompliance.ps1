[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ParameterSetName = "ByCollectionID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [parameter(Mandatory = $true, ParameterSetName = "ByResourceID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, ParameterSetName = "ByCollectionID", HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [parameter(Mandatory = $true, ParameterSetName = "ByResourceID", HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    , [parameter(Mandatory = $true, ParameterSetName = "ByCollectionID", HelpMessage = "The unique ID of the device collection.")]
    [ValidateNotNullOrEmpty()]
    [string] $CollectionID

    , [parameter(Mandatory = $false, ParameterSetName = "ByCollectionID", HelpMessage = "If members count more then 'BatchBy', query by BatchBy members.")]
    [ValidateRange(1, 200)]
    [uint16] $BatchBy = 50

    , [parameter(Mandatory = $true, ParameterSetName = "ByResourceID", HelpMessage = "The unique ID of the device.")]
    [ValidateNotNullOrEmpty()]
    [UInt32[]] $ResourceID

    , [parameter(Mandatory = $false, HelpMessage = "Title of GridView window.")]
    [string] $Title = "Updates required for the computer"

    , [parameter(Mandatory = $false, HelpMessage = "Exclude updates with Custom Severity.")]
    [switch] $ExcludeCustomSeverity
)
Begin {
    #[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]"en-US"
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"

    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

    Write-Verbose "SiteServer   = $SiteServer"
    Write-Verbose "Namespace    = $Namespace"
    Write-Verbose "CollectionID = $CollectionID"
    Write-Verbose "BatchBy      = $BatchBy"
    Write-Verbose "ResourceID   = $ResourceID"
    Write-Verbose "Title        = $Title"
    Write-Verbose "ExcludeCustomSeverity = $ExcludeCustomSeverity"
}
Process {
    if ($psCmdlet.ParameterSetName -eq "ByCollectionID") {
        Write-Verbose "... running by ParameterSetName = ""$($psCmdlet.ParameterSetName)"""

        $QueryMembers = @"
        SELECT DISTINCT
            SMS_R_System.ResourceID
        FROM
            SMS_FullCollectionMembership
            JOIN SMS_R_System
                ON SMS_FullCollectionMembership.ResourceID = SMS_R_System.ResourceID
        WHERE
            SMS_FullCollectionMembership.CollectionID = '$CollectionID'
"@
        $ResourceID = (Get-WmiObject -Query $QueryMembers -ComputerName $SiteServer -Namespace $Namespace).ResourceId
        Write-Verbose "CollectionID = $($CollectionID), member count = $($ResourceID.Count)"
    }
    if ($ResourceID.Count) {
        Write-Verbose "... running batch jobs for $($ResourceID.Count) ResourceID"
        $Query = @"
        SELECT DISTINCT
            SMS_R_System.NetbiosName
            , SMS_SoftwareUpdate.CI_ID
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
                $(if($ExcludeCustomSeverity) {"AND SMS_SoftwareUpdate.CustomSeverity = 0"})
            JOIN SMS_CIAllCategories
                ON SMS_SoftwareUpdate.CI_ID = SMS_CIAllCategories.CI_ID
                AND SMS_SoftwareUpdate.CI_ID NOT IN (SELECT CI_ID FROM SMS_CIAllCategories WHERE CategoryInstance_UniqueID='UpdateClassification:3689bdc8-b205-4af4-8d4a-a63924c5e9d5')
        WHERE SMS_R_System.ResourceID IN ({0})
"@
        ## UpdateClassification:3689bdc8-b205-4af4-8d4a-a63924c5e9d5 - 'Upgrades'

        Write-Verbose "Starting query by batch: $($BatchBy)"
        $CurrentStep = 0; $Updates = $null
        while ($CurrentStep -lt $ResourceID.Count) {
            Write-Verbose "... batch CurrentStep = $($CurrentStep)"
            $Batch = @($ResourceID | Select-Object -First $BatchBy -Skip $CurrentStep)
            $BatchQuery = $Query -f ($Batch -join ", ")
            $Updates += @(Get-WmiObject -Query $BatchQuery -ComputerName $SiteServer -Namespace $Namespace)
            Write-Verbose "... updates count now = $($Updates.Count)"
            $CurrentStep += $BatchBy
        }

        Write-Verbose "Total items count: $($Updates.Count)"
        if (!$Updates.Count) {
            [Microsoft.VisualBasic.Interaction]::MsgBox("No updates are required", "OkOnly,SystemModal,Information", "Completed") | Out-Null
            return 0
        }

        $Title += ". All devices: $($ResourceID.count), need updates: $(($Updates.SMS_R_System.NetbiosName | Select-Object -Unique).Count). All updates: $(($Updates.SMS_SoftwareUpdate.CI_ID | Select-Object -Unique).Count)."
        $Title += " ""Custom severity"" excluded: $ExcludeCustomSeverity"
        $Updates | 
            Select-Object   @{n = "Netbios Name"; e = {$_.SMS_R_System.NetbiosName}},
                            @{n = "Update Title"; e = {$_.SMS_SoftwareUpdate.LocalizedDisplayName}},
                            @{n = "Required"; e = {$_.SMS_SoftwareUpdate.NumMissing}},
                            @{n = "Downloaded"; e = {$_.SMS_SoftwareUpdate.IsContentProvisioned}},
                            @{n = "Deployed"; e = {$_.SMS_SoftwareUpdate.IsDeployed}},
                            @{n = "Released or Revised"; e = {[System.Management.ManagementDateTimeConverter]::ToDateTime($_.SMS_SoftwareUpdate.DateRevised)}} |
                                Sort-Object "Netbios Name", "Released or Revised" | Out-GridView -Wait -Title $Title
    }
}
End {
    Write-Verbose "Completed."
}