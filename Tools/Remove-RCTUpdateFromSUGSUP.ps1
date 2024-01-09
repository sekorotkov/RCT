<#
SUG - Software Update Group
SUP - Software Update Package

logics:
- search for all SUGs with a filter by ExpiredOnly","SupersededOnly","ExpiredSuperseded
- you can immediately remove overdue items from SUG
- but you need a list of expired (if such an operation is ordered) and downloaded files to remove from SUP

- By_SUG_Root
-   By_SUG_CI_ID
- By_SUP_Root
-   By_SUP_CI_ID

#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "By_SUG_Root")]

param(
    [parameter( Mandatory = $true, ParameterSetName = "By_SUG_Root", HelpMessage = "Site server where the SMS Provider is installed.")]
    [parameter( Mandatory = $true, ParameterSetName = "By_SUP_Root", HelpMessage = "Site server where the SMS Provider is installed.")]
    [parameter( Mandatory = $true, ParameterSetName = "By_ArticleID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, ParameterSetName = "By_SUG_Root", HelpMessage = "Namespace: root\sms\site_COD for examle.")]
    [parameter(Mandatory = $true, ParameterSetName = "By_SUP_Root", HelpMessage = "Namespace: root\sms\site_COD for examle.")]
    [parameter(Mandatory = $true, ParameterSetName = "By_ArticleID", HelpMessage = "Namespace: root\sms\site_COD for examle.")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    # , [parameter(Mandatory = $true, ParameterSetName = "By_SUG_CI_ID", HelpMessage = "SMS_AuthorizationList.CI_ID - SUG ID.")]
    # [ValidateNotNullOrEmpty()]
    # [uint32] $SUG_CI_ID

    # , [parameter(Mandatory = $true, ParameterSetName = "By_SUP_CI_ID", HelpMessage = "SMS_AuthorizationList.CI_ID - SUG ID.")]
    # [ValidateNotNullOrEmpty()]
    # [uint32] $SUP_CI_ID

    , [parameter(Mandatory = $true, ParameterSetName = "By_ArticleID", HelpMessage = "SMS_AuthorizationList.CI_ID - SUG ID.")]
    [ValidateNotNullOrEmpty()]
    [uint32[]] $ArticleID = @(4052623, 915597, 2267602)

    , [parameter(Mandatory = $true, HelpMessage = "Select an option to clean either ExpiredOnly, SupersededOnly or ExpiredSuperseded Software Updates from each Software Update Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("ExpiredOnly", "SupersededOnly", "ExpiredSuperseded")]
    [string] $Option

    , [parameter(Mandatory = $false, HelpMessage = "Remove the content for those Software Updates that will be removed from a Software Upgrade Group")]
    [ValidateNotNullOrEmpty()]
    [switch] $RemoveContent

    , [parameter(Mandatory = $false, HelpMessage = "Do not prompts you for confirmation before running the cmdlet.")]
    [switch] $Force
)

Begin {
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"
    
    $Removed_CI_ID = @() # Update IDs removed from SUG (for remove from SUG)
    $SUGChanged = @()    # Returned .put() SUG object (for remove from SUG)
    $SUPChanged = @()    # Returned .RemoveContent() SU Packages object (for remove from SUP)

    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

    Write-Verbose "SiteServer    = $SiteServer"
    Write-Verbose "Namespace     = $Namespace"
    Write-Verbose "SUG_CI_ID     = $SUG_CI_ID"
    Write-Verbose "SUP_CI_ID     = $SUP_CI_ID"
    Write-Verbose "Option        = $Option"
    Write-Verbose "RemoveContent = $RemoveContent"
    Write-Verbose "Force         = $Force"

    $Message = "Remove selected updates from all SUG{0}?" -f $(if ($RemoveContent) { " and SUP" })

    if (!$force -and [Microsoft.VisualBasic.Interaction]::MsgBox($Message, "YesNo,SystemModal,Question,DefaultButton1", "Start confirmation") -ne 'Yes') {
        break 
    }
    
    # Function for check if object is locked by other user/process
    $LockStateName = @{0 = "Unassigned"; 1 = "Assigned"; 2 = "Requested"; 3 = "PendingAssignment"; 4 = "TimedOut"; 5 = "NotFound"; }
    function Get-CCMSEDOState ($Namespace, $SiteServer, $CCMObject) {
        $Locked = Invoke-WmiMethod -Namespace $Namespace -Class SMS_ObjectLock -ComputerName $SiteServer -Name "GetLockInformation" -ArgumentList $CCMObject.__RELPATH
        Write-Verbose "LockState code = $($Locked.LockState): $($LockStateName.Item([int]$Locked.LockState))"
        return $Locked
    }

    # Filters for Querys. First for "SMS_AuthorizationList" (SUG), second for SMS_SoftwareUpdate (SU ID)
    $OptionFilter = @{
        ExpiredOnly       = @('SMS_AuthorizationList.ContainsExpiredUpdates = 1', 'SMS_SoftwareUpdate.IsExpired = 0')
        SupersededOnly    = @('SMS_AuthorizationList.ContainsSupersededUpdates = 1','SMS_SoftwareUpdate.IsSuperseded = 0')
        ExpiredSuperseded = @('SMS_AuthorizationList.ContainsExpiredUpdates = 1 OR SMS_AuthorizationList.ContainsSupersededUpdates = 1', 'SMS_SoftwareUpdate.IsExpired = 0 AND SMS_SoftwareUpdate.IsSuperseded = 0')
    }
}

Process {
    # Get all SUG with expiried and/or supersided updates
    $AuthorizationListQuery = @"
    SELECT SMS_AuthorizationList.CI_ID
    FROM
        SMS_AuthorizationList
    WHERE 
        ({0}) 
"@ -f $OptionFilter[$Option][0]

    if ($PSCmdlet.ParameterSetName -eq 'By_ArticleID') {
        # Add search only for specific ArticleID
    }
 
    $AllSUGs = @(Get-WmiObject -Query $AuthorizationListQuery -ComputerName $SiteServer -Namespace $Namespace)
    Write-Verbose "SUG count: $($AllSUGs.Count)"

    if (!$AllSUGs.Count) {
        [Microsoft.VisualBasic.Interaction]::MsgBox("No expired and/or supersided updates are found", "OkOnly,SystemModal,Information", "Completed") | Out-Null
        return 0
    }

    Write-Verbose "Get lazy propetries `"Updates`" for all SUG..."
    $AllSUGs | ForEach-Object { $_.get() }

    foreach ($SUG in $AllSUGs) { ## $SUG = $AllSUGs[-1]
        Write-Verbose "Start processing SUG: ""$($SUG.LocalizedDisplayName)"""
        Write-Verbose "`$SUG.Updates.Count = $($SUG.Updates.Count)"
        Write-Verbose "`$SUG.Updates = $($SUG.Updates)"

        $SoftwareUpdateQuery = @"
        SELECT SMS_SoftwareUpdate.CI_ID FROM SMS_SoftwareUpdate
        WHERE 
            {0}
            AND SMS_SoftwareUpdate.CI_ID IN ($($SUG.Updates -join ","))
"@ -f $OptionFilter[$Option][1]
        Write-Verbose "SoftwareUpdateQuery query:`n$($SoftwareUpdateQuery)"

        $ClearSUGUpdates = @(Get-WmiObject -Query $SoftwareUpdateQuery -ComputerName $SiteServer -Namespace $Namespace | Select-Object -ExpandProperty CI_ID)
        Write-Verbose "ClearSUGUpdates = $ClearSUGUpdates"

        if ($ClearSUGUpdates.Count -lt $SUG.Updates.Count) {
            Write-Verbose "Count change exist"
            # Check SEDO state
            $NextSug = $false
            while (!$NextSug -and [bool]($Locked = Get-CCMSEDOState -Namespace $Namespace -SiteServer $SiteServer -CCMObject $SUG).LockState) {
                $Text = "SUG: ""$($SUG.LocalizedDisplayName)"" locked by:$($Locked |
                    Format-List @{n = "Machine"; e = {$_.AssignedMachine}},
                                @{n = "User"; e = {$_.AssignedUser}},
                                @{n = "Lock"; e = {$LockStateName.Item([int]$_.LockState)}} | Out-String)Retry?"
                Write-Verbose $Text
                $Answer = [Microsoft.VisualBasic.Interaction]::MsgBox($Text, "AbortRetryIgnore,SystemModal,Question,DefaultButton2", "SEDO locked")
                switch ($Answer) {
                    'Abort' { break }
                    'Ignore' { $NextSug = $true; continue }
                }
            }
            if (!$Locked.LockState) {
                Write-Verbose "RemoveContent = $RemoveContent"
                if ($RemoveContent) {                    
                    # Save supersided and/or expired CI-ID for remove content later
                    $Removed_CI_ID += $SUG.Updates | Where-Object { $ClearSUGUpdates -notcontains $_ }
                    Write-Verbose "Removed_CI_ID = $Removed_CI_ID"
                }
                
                # Save cleared Updates CI_ID to SUG
                Write-Verbose "Set `$SUG.Updates: $ClearSUGUpdates"
                $SUG.Updates = $ClearSUGUpdates
                $SUGChanged += $SUG.Put()
                Write-Verbose ($SUGChanged | Out-String)
                Write-Verbose -Message "Successfully removed update from ""$($SUG.LocalizedDisplayName)"""                
            }
        }
    }
}

End {
    if ($RemoveContent -and $Removed_CI_ID.Count) { ## Clear SU Package
        $Removed_CI_ID = $Removed_CI_ID | Select-Object -Unique

        $ContentQuery = @"
        SELECT DISTINCT
            SMS_PackageToContent.ContentID,
            SMS_PackageToContent.PackageID 
        FROM 
            SMS_PackageToContent 
            JOIN SMS_CIToContent ON SMS_CIToContent.ContentID = SMS_PackageToContent.ContentID 
        WHERE SMS_CIToContent.CI_ID IN ($($Removed_CI_ID -join ','))
"@
        Write-Verbose "ContentQuery query:`n$($ContentQuery)"
        
        $Packages = @(Get-WmiObject -Query $ContentQuery -ComputerName $SiteServer -Namespace $Namespace)
        Write-Verbose "Total items count: $($Packages.Count)"

        $GroupByPackageIDs = $Packages | Select-Object PackageID, ContentID | Group-Object PackageID
        Write-Verbose "GroupByPackageIDs:$($GroupByPackageIDs | Out-String -Width 80)"

        foreach ($GroupByPackageID in $GroupByPackageIDs) { ## $GroupByPackageID = $GroupByPackageIDs[-1]
            $Package = [wmi]"\\$($SiteServer)\$($Namespace):SMS_SoftwareUpdatesPackage.PackageID='$($GroupByPackageID.Name)'"
            Write-Verbose ($Package | Out-String)
            $SUPChanged += $Package.RemoveContent($GroupByPackageID.Group.ContentID, $true)
        }
        $Text = if ($SUGChanged.Count) { "Number of modified SU Group: $($SUGChanged.Count)`nNumber of modified SU Package: $($SUPChanged.Count)`n`nPlease refresh the console." } else { "No changes made." }
        Write-Verbose $Text
        [Microsoft.VisualBasic.Interaction]::MsgBox($Text, "OkOnly,SystemModal,Information,DefaultButton1", "Completed") | Out-Null
    }
}