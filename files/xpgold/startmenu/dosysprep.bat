echo "SYSTEM IS BEGINNING SYSPREP PROCESS, PLEASE WAIT."

ping 1.1.1.1 -n 1 -w 3000 >nul

reg export "HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer" c:\settings\current_user_ie_settings2.reg"



reg export "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" c:\settings\current_user_ie_settings.reg"


reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" c:\settings\local_machine_ie_settings.reg"


reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" c:\settings\local_machine_winlogon_settings.reg"

c:\sysprep\sysprep.exe -quiet -reseal -mini -forceshutdown
