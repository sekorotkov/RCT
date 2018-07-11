@ECHO off

rem Detect: Run as Administrator
NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    ECHO Administrator PRIVILEGES Detected!
) ELSE (
    ECHO This script must be run as administrator to work properly!
	PAUSE
    EXIT /b 1    
)

rem Set: Work folders
set _admincosole="%SMS_ADMIN_UI_PATH%\..\..\"
set _home=%~dp0

rem Detect: SCCM console folder exist
IF NOT EXIST %_admincosole% (
	ECHO SCCM console does not exists!
    EXIT /b 1 
)
rem copy *.ps1 / *.xml files
XCOPY "%_home%*.ps1" %_admincosole% /S /I /F /Y
XCOPY "%_home%*.xml" %_admincosole% /S /I /F /Y
PAUSE