[CmdletBinding()]
param(
    [parameter(Mandatory = $true, HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, HelpMessage = "Namespace: root\sms\site_COD for examle")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace
)
Begin {
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"

    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

    Write-Verbose "SiteServer       = $SiteServer"
    Write-Verbose "Namespace        = $Namespace"
}
Process {
    $Query = @"
        SELECT Name, ID
        FROM SMS_ISVCatalogs
        WHERE SyncEnabled = 1
"@

    $ISVCatalogs = @(Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace)

    Write-Verbose "Count of active catalogs: $($ISVCatalogs.Count)"

    if (!$ISVCatalogs.Count) {
        [Microsoft.VisualBasic.Interaction]::MsgBox("No active catalogs found", "OkOnly,SystemModal,Information", "Completed") | Out-Null
        return 0
    }

    $Res = Invoke-WmiMethod -Namespace $Namespace -Class "SMS_ISVCatalogs" -ComputerName $SiteServer -Name "SyncCatalogs"
    if ($Res.StatusCode) {
        Write-Verbose "Invoke WMI Method error: $($Res.StatusCode)"
        [Microsoft.VisualBasic.Interaction]::MsgBox("The sync was invoked with errors.`nStatus Code = $($Res.StatusCode)", "OkOnly,SystemModal,Critical", "Error") | Out-Null
    } else {
        Write-Verbose "Invoke WMI Method Completed: $($Res.StatusCode)"
        [Microsoft.VisualBasic.Interaction]::MsgBox("The sync was invoked successfully.`nCheck the ""SMS_ISVUPDATES_SYNCAGENT.log"" for more details", "OkOnly,SystemModal,Information", "Completed") | Out-Null
    }
}
End {
    Write-Verbose "Completed."
}