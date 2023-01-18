@ECHO off

:: Detect: Run as Administrator
NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
	ECHO Administrator PRIVILEGES Detected!
) ELSE (
	ECHO This script must be run as administrator to work properly!
	PAUSE
	EXIT /b 1    
)

:: Set: Work folders
set _admincosole="%SMS_ADMIN_UI_PATH%\..\..\"
set _home=%~dp0

:: Unblock files
echo Unblock downlaoded content
powershell.exe -NoProfile -Command "Get-ChildItem '%_home%' -Recurse | Unblock-File"

:: Detect: SCCM console folder exist
IF NOT EXIST %_admincosole% (
	ECHO SCCM console does not exists!
	EXIT /b 1 
)

:: copy *.ps1 / *.xml files
ECHO Copy Powershell scripts:
XCOPY "%_home%Tools\*.ps1" %_admincosole% /S /I /F /Y

ECHO Copy XML configs:
XCOPY "%_home%Xml-RCT\*.xml" %_admincosole% /S /I /F /Y

:: Add SiteServer and Namespace to Special extension *.xml files
ECHO Add SiteServer and Namespace to Special extension *.xml files:
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Normal -ExecutionPolicy RemoteSigned -Command ". ""%_home%Install-SpecialExtension.ps1"""

PAUSE