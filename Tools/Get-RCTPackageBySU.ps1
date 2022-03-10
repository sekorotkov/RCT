[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ParameterSetName = "BySUGCI_ID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [parameter(Mandatory = $true, ParameterSetName = "ByCI_ID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, ParameterSetName = "BySUGCI_ID", HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [parameter(Mandatory = $true, ParameterSetName = "ByCI_ID", HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    , [parameter(Mandatory = $true, ParameterSetName = "BySUGCI_ID", HelpMessage = "The unique ID of the software update group.")]
    [ValidateNotNullOrEmpty()]
    [string] $SUGCI_ID

    , [parameter(Mandatory = $true, ParameterSetName = "ByCI_ID", HelpMessage = "The unique ID of the Update.")]
    [ValidateNotNullOrEmpty()]
    [UInt32[]] $CI_ID

    , [parameter(Mandatory = $false, HelpMessage = "Title of GridView window.")]
    [string] $Title = "Updates downloaded to package"
)
Begin {
    #[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]"en-US"
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"

    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

    Write-Verbose "SiteServer   = $SiteServer"
    Write-Verbose "Namespace    = $Namespace"
    Write-Verbose "SUGCI_ID     = $SUGCI_ID"
    Write-Verbose "CI_ID        = $CI_ID"
    Write-Verbose "Title        = $Title"
}
Process {
    if ($psCmdlet.ParameterSetName -eq "BySUGCI_ID") {
        Write-Verbose "... running by ParameterSetName = ""$($psCmdlet.ParameterSetName)"""

        $QueryMembers = @"
        SELECT SMS_SoftwareUpdate.CI_ID
        FROM 
            SMS_SoftwareUpdate
            , SMS_CIRelation
        WHERE 
            SMS_CIRelation.FromCIID = $SUGCI_ID
            AND SMS_CIRelation.RelationType=1 AND SMS_SoftwareUpdate.CI_ID=SMS_CIRelation.ToCIID
"@
        $CI_ID = (Get-WmiObject -Query $QueryMembers -ComputerName $SiteServer -Namespace $Namespace).CI_ID
        Write-Verbose "SUGCI_ID = $($SUGCI_ID), member count = $($CI_ID.Count)"
    }
    if ($CI_ID.Count) {
        Write-Verbose "... running query for $($CI_ID.Count) CI_ID"
        $Query = @"
        SELECT DISTINCT
            SMS_SoftwareUpdatesPackage.PackageID
            , SMS_SoftwareUpdatesPackage.Name
            , SMS_SoftwareUpdatesPackage.PkgSourcePath
        FROM SMS_SoftwareUpdatesPackage
            JOIN SMS_PackageToContent
                on SMS_SoftwareUpdatesPackage.PackageID = SMS_PackageToContent.PackageID
            JOIN SMS_CIContentFiles
                on SMS_PackageToContent.ContentID = SMS_CIContentFiles.ContentID
            JOIN SMS_CIToContent
                on SMS_CIContentFiles.ContentID = SMS_CIToContent.ContentID
        WHERE SMS_CIToContent.CI_ID IN ({0})
"@ -f ($CI_ID -join ", ")

        Write-Verbose "Starting query: $($Query)"
        $Packages = @(Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace)

        Write-Verbose "Total items count: $($Packages.Count)"
        if (!$Packages.Count) {
            [Microsoft.VisualBasic.Interaction]::MsgBox("No packages found", "OkOnly,SystemModal,Information", "Completed") | Out-Null
            return 0
        }

        $Packages | Select-Object   @{n = "Package ID"; e = { $_.PackageID } },
                                    @{n = "Name"; e = { $_.Name } },
                                    @{n = "Source Path"; e = { $_.PkgSourcePath } } |
                    Sort-Object "Package ID" | 
                    Out-GridView -Wait -Title $Title
    }
    else { 
        [Microsoft.VisualBasic.Interaction]::MsgBox("No packages found", "OkOnly,SystemModal,Information", "Completed") | Out-Null
        return 0
    }
}
End {
    Write-Verbose "Completed."
}