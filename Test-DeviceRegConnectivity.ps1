<# 
 
.SYNOPSIS
    Test-HybridDevicesInternetConnectivity PowerShell script.

.DESCRIPTION
    Test-HybridDevicesInternetConnectivity is a PowerShell script that helps to test the Internet connectivity to the following Microsoft resources under the system context to validate the connection status between the device that needs to be connected to Azure AD as hybrid Azure AD joined device and Microsoft resources that are used during device registration process:

    https://login.microsoftonline.com
    https://device.login.microsoftonline.com
    https://enterpriseregistration.windows.net


.AUTHOR:
    Mohammad Zmaili

.EXAMPLE
    .\Test-DeviceRegConnectivity
    
#>

Function RunPScript([String] $PSScript){

$GUID=[guid]::NewGuid().Guid

$Job = Register-ScheduledJob -Name $GUID -ScheduledJobOption (New-ScheduledJobOption -RunElevated) -ScriptBlock ([ScriptBlock]::Create($PSScript)) -ArgumentList ($PSScript) -ErrorAction Stop

$Task = Register-ScheduledTask -TaskName $GUID -Action (New-ScheduledTaskAction -Execute $Job.PSExecutionPath -Argument $Job.PSExecutionArgs) -Principal (New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest) -ErrorAction Stop

$Task | Start-ScheduledTask -AsJob -ErrorAction Stop | Wait-Job | Remove-Job -Force -Confirm:$False

While (($Task | Get-ScheduledTaskInfo).LastTaskResult -eq 267009) {Start-Sleep -Milliseconds 150}

$Job1 = Get-Job -Name $GUID -ErrorAction SilentlyContinue | Wait-Job
$Job1 | Receive-Job -Wait -AutoRemoveJob 

Unregister-ScheduledJob -Id $Job.Id -Force -Confirm:$False

Unregister-ScheduledTask -TaskName $GUID -Confirm:$false
}


Function Test-DeviceRegConnectivity{
''
Write-Host "Checking Internet Connectivity..." -ForegroundColor Yellow
$TestResult = RunPScript -PSScript "(Test-NetConnection -ComputerName login.microsoftonline.com -Port 443).TcpTestSucceeded"
if ($TestResult -eq $true){
    Write-Host "Connection to login.microsoftonline.com .............. Succeeded." -ForegroundColor Green 
}else{
    Write-Host "Connection to login.microsoftonline.com ................. failed." -ForegroundColor Red 
}

$TestResult = RunPScript -PSScript "(Test-NetConnection -ComputerName device.login.microsoftonline.com -Port 443).TcpTestSucceeded"
if ($TestResult -eq $true){
    Write-Host "Connection to device.login.microsoftonline.com ......  Succeeded." -ForegroundColor Green 
}else{
    Write-Host "Connection to device.login.microsoftonline.com .......... failed." -ForegroundColor Red 
}


$TestResult = RunPScript -PSScript "(Test-NetConnection -ComputerName enterpriseregistration.windows.net -Port 443).TcpTestSucceeded"
if ($TestResult -eq $true){
    Write-Host "Connection to enterpriseregistration.windows.net ..... Succeeded." -ForegroundColor Green 
}else{
    Write-Host "Connection to enterpriseregistration.windows.net ........ failed." -ForegroundColor Red 
}
''
}

Test-DeviceRegConnectivity