<#
SUG - Software Update Group
SUP - Software Update Package
RMC - Right mouse click
logics:
- search for all expiried and supersisded Defender updates and remove from SUG, SUP.
#  SUGs with a filter by ExpiredOnly","SupersededOnly","ExpiredSuperseded

How to use:
- RMC on SUG_Root
- RMC on SUP_Root
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "By_ArticleID")]

param(
    [parameter( Mandatory = $true, ParameterSetName = "By_ArticleID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, ParameterSetName = "By_ArticleID", HelpMessage = "Namespace: root\sms\site_COD for examle.")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    , [parameter(Mandatory = $true, ParameterSetName = "By_ArticleID", HelpMessage = 'String of SMS_SoftwareUpdate.ArticleID, for example: "915597, 2267602, 2310138, 2461484"')]
    [ValidateNotNullOrEmpty()]
    [string] $ArticleID = '915597, 2267602, 2310138, 2461484'
    
    , [parameter(Mandatory = $false, HelpMessage = "Do not prompts you for confirmation before running the cmdlet.")]
    [switch] $Force
)

Begin {
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"
    
    $SUGChanged = @()    # Returned .put() SUG object (for statistic)
    $SUPChanged = @()    # Returned .RemoveContent() SU Packages object (for statistic)

    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

    Write-Verbose "SiteServer    = $SiteServer"
    Write-Verbose "Namespace     = $Namespace"
    Write-Verbose "ArticleID     = $ArticleID"
    Write-Verbose "Force         = $Force"

    $Message = "Remove Defender updates from all SUG and SUP?`nit can take a few minutes."

    if (!$force -and [Microsoft.VisualBasic.Interaction]::MsgBox($Message, "YesNo,SystemModal,Question,DefaultButton1", "Clear Defender Updates: Start confirmation") -ne 'Yes') {
        break 
    }
    
    ## Function for check if object is locked by other user/process
    $LockStateName = @{0 = "Unassigned"; 1 = "Assigned"; 2 = "Requested"; 3 = "PendingAssignment"; 4 = "TimedOut"; 5 = "NotFound"; }
    function Get-CCMSEDOState ($Namespace, $SiteServer, $CCMObject) {
        $Locked = Invoke-WmiMethod -Namespace $Namespace -Class SMS_ObjectLock -ComputerName $SiteServer -Name "GetLockInformation" -ArgumentList $CCMObject.__RELPATH
        Write-Verbose "LockState code = $($Locked.LockState): $($LockStateName.Item([int]$Locked.LockState))"
        return $Locked
    }

    ## Convert string of ArticleID to string with quotes ArticleID
    $ArticleID = ($ArticleID.Replace('"', '').Split(',').Trim() | ForEach-Object { "`"$_`"" }) -join ','
    Write-Verbose "Converted ArticleID = $($ArticleID)"
}

Process {
    ## Get all Defender updates with expiried or supersided updates

    $SoftwareUpdateQuery = @"
    SELECT 
        SMS_SoftwareUpdate.CI_ID,
        SMS_SoftwareUpdate.IsDeployed,
        SMS_SoftwareUpdate.IsContentProvisioned
    FROM SMS_SoftwareUpdate
    WHERE
        SMS_SoftwareUpdate.ArticleID IN ($ArticleID)
        AND (SMS_SoftwareUpdate.IsExpired = 1 OR SMS_SoftwareUpdate.IsSuperseded = 1)
"@
    Write-Verbose "SoftwareUpdateQuery query:`n$($SoftwareUpdateQuery)"

    $OldDefenderUpdates = @(Get-WmiObject -Query $SoftwareUpdateQuery -ComputerName $SiteServer -Namespace $Namespace)
    Write-Verbose "OldDefenderUpdates.CI_ID = $($OldDefenderUpdates.CI_ID)"
    Write-Verbose "OldDefenderUpdates.CI_ID.Count = $($OldDefenderUpdates.CI_ID.Count)"

    ## Clear SUG, if update exists
    if ($OldDefenderUpdates.Count) {
        Write-Verbose ''
        Write-Verbose "OldDefenderUpdates exists"
        ## Get all SUG with expiried and/or supersided updates
        $AuthorizationListQuery = @"
            SELECT SMS_AuthorizationList.CI_ID
            FROM
                SMS_AuthorizationList
            WHERE 
                SMS_AuthorizationList.ContainsExpiredUpdates = 1 OR SMS_AuthorizationList.ContainsSupersededUpdates = 1
"@
 
        $AllSUGs = @(Get-WmiObject -Query $AuthorizationListQuery -ComputerName $SiteServer -Namespace $Namespace)
        Write-Verbose "SUG count: $($AllSUGs.Count)"

        Write-Verbose "Get lazy propetries `"Updates`" for all SUG..."
        $AllSUGs | ForEach-Object { $_.get() }

        foreach ($SUG in $AllSUGs) {
            # $SUG = $AllSUGs[1]
            Write-Verbose ''
            Write-Verbose "Start processing SUG: ""$($SUG.LocalizedDisplayName)"""
            Write-Verbose "`$SUG.Updates = $($SUG.Updates)"
            Write-Verbose "`$SUG.Updates.Count = $($SUG.Updates.Count)"
            
            $ClearedSUGUpdates = $SUG.Updates | Where-Object { $OldDefenderUpdates.CI_ID -notcontains $_ }
            Write-Verbose "ClearedSUGUpdates count = $($ClearedSUGUpdates.Count)"

            if ($SUG.Updates.Count -gt $ClearedSUGUpdates.Count) {
                ## Check SEDO state
                $NextSug = $false
                while (!$NextSug -and [bool]($Locked = Get-CCMSEDOState -Namespace $Namespace -SiteServer $SiteServer -CCMObject $SUG).LockState) {
                    
                    $Text = "SUG: `"$($SUG.LocalizedDisplayName)`" locked by:$($Locked |
                    Format-List @{n = "Machine"; e = {$_.AssignedMachine}},
                                @{n = "User"; e = {$_.AssignedUser}},
                                @{n = "Lock"; e = {$LockStateName.Item([int]$_.LockState)}} | Out-String)Retry?"
                    Write-Verbose $Text
                    $Answer = [Microsoft.VisualBasic.Interaction]::MsgBox($Text, "AbortRetryIgnore,SystemModal,Question,DefaultButton2", "Clear Defender Updates: SEDO locked")

                    switch ($Answer) {
                        'Abort' { break }
                        'Ignore' { $NextSug = $true; continue }
                    }
                }

                if (!$Locked.LockState) {
                    ## Save cleared Updates CI_ID to SUG 
                    Write-Verbose "Set `$SUG.Updates: $ClearedSUGUpdates"

                    $SUG.Updates = $ClearedSUGUpdates
                    $SUGChanged += $SUG.Put()
                    Write-Verbose -Message "Successfully removed update from `"$($SUG.LocalizedDisplayName)`""
                }
            } else {
                Write-Verbose "No SUG.Updates.Count changed`n"
            }
        }
        Write-Verbose ($SUGChanged | Out-String)
    }

    ## Clear SUP, if update exists
    Write-Verbose ''
    Write-Verbose "Starting Remove content from SU Package"

    $IsContentProvisionedUpdates = @($OldDefenderUpdates | Where-Object IsContentProvisioned | Select-Object -Unique CI_ID -ExpandProperty CI_ID )
    if ($IsContentProvisionedUpdates.Count) {
    
        $ContentQuery = @"
            SELECT DISTINCT
                SMS_PackageToContent.ContentID,
                SMS_PackageToContent.PackageID 
            FROM 
                SMS_PackageToContent 
                JOIN SMS_CIToContent ON SMS_CIToContent.ContentID = SMS_PackageToContent.ContentID 
            WHERE
                SMS_CIToContent.CI_ID IN ($($IsContentProvisionedUpdates -join ','))
"@
        Write-Verbose "ContentQuery query:`n$($ContentQuery)"
            
        $Packages = @(Get-WmiObject -Query $ContentQuery -ComputerName $SiteServer -Namespace $Namespace)
        Write-Verbose "Total items count: $($Packages.Count)"
    
        $GroupByPackageIDs = $Packages | Select-Object PackageID, ContentID | Group-Object PackageID
        Write-Verbose "GroupByPackageIDs:$($GroupByPackageIDs | Out-String -Width 80)"
    
        foreach ($GroupByPackageID in $GroupByPackageIDs) {
            # $GroupByPackageID = $GroupByPackageIDs[-1]
            Write-Verbose ''
            Write-Verbose "Remove content from SUP: $($GroupByPackageID.Name)"
    
            $Package = [wmi]"\\$($SiteServer)\$($Namespace):SMS_SoftwareUpdatesPackage.PackageID='$($GroupByPackageID.Name)'"
            Write-Verbose "Package: $($Package | Select-Object PackageID,Name,PkgSourcePath | Out-String)"
    
            $SUPChanged += $Package.RemoveContent($GroupByPackageID.Group.ContentID, $true)
        }
    }
    Write-Verbose ($SUPChanged | Out-String)
}

End {
    $Text = if ($SUGChanged.Count -or $SUPChanged.Count) { "Modified SU Group: $($SUGChanged.Count)`nModified SU Package: $($SUPChanged.Count)`n`nPlease refresh the console." } else { "No changes made." }
    Write-Verbose $Text

    [Microsoft.VisualBasic.Interaction]::MsgBox($Text, "OkOnly,SystemModal,Information,DefaultButton1", "Clear Defender Updates: Completed") | Out-Null
}