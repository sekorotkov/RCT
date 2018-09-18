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

    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

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

    $Updates = @(Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace)
    Write-Verbose "Updates count: $($Updates.Count)"

        if ($Updates.Count) {
            $LProp = ([WmiClass] "\\$($SiteServer)\$($Namespace):SMS_CI_LocalizedProperties").CreateInstance()
            $LProp.DisplayName = $SUGName
            $LProp.Description = "Updates required for the device CollectionID: $($CollectionID)"
            $LProp.LocaleID = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID

            # Create a new SMS_AuthorizationList instance
            $AuthArg = @{
                LocalizedInformation = [array]$LProp
            }
            try {
                $SUG = Set-WmiInstance -ComputerName $SiteServer -Namespace $Namespace -Class SMS_AuthorizationList -Arguments $AuthArg -ErrorAction Stop
                Write-Verbose -Message "Successfully created '$($SUGName)' software update group"
            }
            catch [System.Exception] {
                Write-Verbose -Message "Failed to create SUG: ""$($SUGName)"""
                [Microsoft.VisualBasic.Interaction]::MsgBox("Failed to create SUG:`n""$($SUGName)""", "OkOnly,SystemModal,Critical", "Error") | Out-Null
            }
            # Add list of CI_ID's to SUG
            if ($SUG) {
                try {
                    $SUG.Get()
                    $SUG.Updates = $Updates.CI_ID
                    $SUG.Put() | Out-String | Write-Verbose
                    Write-Verbose -Message "Successfully added ""$($Updates.CI_ID.Count)"" software updates to ""$($SUGName)"" software update group"
                    [Microsoft.VisualBasic.Interaction]::MsgBox("The SUG was created successfully:`n""$($SUGName)""", "OkOnly,SystemModal,Information", "Completed") | Out-Null
                }
                catch [System.Exception] {
                    [Microsoft.VisualBasic.Interaction]::MsgBox("Failed to fill SUG with updates:`n""$($SUGName)""", "OkOnly,SystemModal,Critical", "Error") | Out-Null
                }
            }
        }
        else {
            Write-Verbose "No Updates for collection members"
            [Microsoft.VisualBasic.Interaction]::MsgBox("No updates for collection members", "OkOnly,SystemModal,Information", "Completed") | Out-Null
        }
}
End {
    Write-Verbose "Completed."
}