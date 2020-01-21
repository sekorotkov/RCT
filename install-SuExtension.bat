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

:: This code is:
:: (gci "$($ENV:SMS_ADMIN_UI_PATH)\..\Microsoft.ConfigurationManagement.exe").VersionInfo.FileVersion
:: For decode base64 sting use powershell command:
:: $encodedCommand = 'KABnAGMAaQAgACIAJAAoACQARQBOAFYAOgBTAE0AUwBfAEEARABNAEkATgBfAFUASQBfAFAAQQBUAEgAKQBcAC4ALgBcAE0AaQBjAHIAbwBzAG8AZgB0AC4AQwBvAG4AZgBpAGcAdQByAGEAdABpAG8AbgBNAGEAbgBhAGcAZQBtAGUAbgB0AC4AZQB4AGUAIgApAC4AVgBlAHIAcwBpAG8AbgBJAG4AZgBvAC4ARgBpAGwAZQBWAGUAcgBzAGkAbwBuAA=='
:: [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($encodedCommand))
::

for /f %%a in ('powershell.exe -NoProfile -encodedCommand "KABnAGMAaQAgACIAJAAoACQARQBOAFYAOgBTAE0AUwBfAEEARABNAEkATgBfAFUASQBfAFAAQQBUAEgAKQBcAC4ALgBcAE0AaQBjAHIAbwBzAG8AZgB0AC4AQwBvAG4AZgBpAGcAdQByAGEAdABpAG8AbgBNAGEAbgBhAGcAZQBtAGUAbgB0AC4AZQB4AGUAIgApAC4AVgBlAHIAcwBpAG8AbgBJAG4AZgBvAC4ARgBpAGwAZQBWAGUAcgBzAGkAbwBuAA=="') do set "_ver=%%a"
echo Console version is: %_ver%


:: Detect: SCCM folder extension for console exist
IF NOT EXIST "%_home%Xml-SuExtension\%_ver%" (
	ECHO SCCM extension for console version %_ver% does not exists!
	PAUSE
	EXIT /b 1 
)

echo "Extension for console version %_ver% exists..."

rem copy *.ps1 / *.xml files
ECHO Copy Powershell scripts:
XCOPY "%_home%Tools\*.ps1" %_admincosole% /S /I /F /Y

ECHO Copy XML configs:
XCOPY "%_home%Xml-SuExtension\%_ver%\*.xml" %_admincosole% /S /I /F /Y
PAUSE