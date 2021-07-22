<# 
 
.SYNOPSIS
    Test-HybridDevicesInternetConnectivity V3.0 PowerShell script.

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

Function checkProxy{
    # Check Proxy settings
    Write-Host "Checking winHTTP proxy settings..." -ForegroundColor Yellow
    Write-Log -Message "Checking winHTTP proxy settings..."
    $global:ProxyServer="NoProxy"
    $winHTTP = netsh winhttp show proxy
    $Proxy = $winHTTP | Select-String server
    $global:ProxyServer=$Proxy.ToString().TrimStart("Proxy Server(s) :  ")
    $global:Bypass = $winHTTP | Select-String Bypass
    $global:Bypass=$global:Bypass.ToString().TrimStart("Bypass List     :  ")

    if ($global:ProxyServer -eq "Direct access (no proxy server)."){
        $global:ProxyServer="NoProxy"
        Write-Host "Access Type : DIRECT"
        Write-Log -Message "Access Type : DIRECT"
    }

    if ( ($global:ProxyServer -ne "NoProxy") -and (-not($global:ProxyServer.StartsWith("http://")))){
        Write-Host "      Access Type : PROXY"
        Write-Log -Message "      Access Type : PROXY"
        Write-Host "Proxy Server List :" $global:ProxyServer
        Write-Log -Message "Proxy Server List : $global:ProxyServer"
        Write-Host "Proxy Bypass List :" $global:Bypass
        Write-Log -Message "Proxy Bypass List : $global:Bypass"
        $global:ProxyServer = "http://" + $global:ProxyServer
    }

    $global:login= $global:Bypass.Contains("*.microsoftonline.com") -or $global:Bypass.Contains("login.microsoftonline.com")

    $global:device= $global:Bypass.Contains("*.microsoftonline.com") -or $global:Bypass.Contains("*.login.microsoftonline.com") -or $global:Bypass.Contains("device.login.microsoftonline.com")

    $global:enterprise= $global:Bypass.Contains("*.windows.net") -or $global:Bypass.Contains("enterpriseregistration.windows.net")

    #CheckwinInet proxy
    Write-Host ''
    Write-Host "Checking winInet proxy settings..." -ForegroundColor Yellow
    Write-Log -Message "Checking winInet proxy settings..."
    $winInet=RunPScript -PSScript "Get-ItemProperty -Path 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings'"
    if($winInet.ProxyEnable){Write-Host "    Proxy Enabled : Yes"; Write-Log -Message "    Proxy Enabled : Yes"}else{Write-Host "    Proxy Enabled : No";Write-Log -Message "    Proxy Enabled : No"}
    $winInetProxy="Proxy Server List : "+$winInet.ProxyServer
    Write-Host $winInetProxy
    Write-Log -Message $winInetProxy
    $winInetBypass="Proxy Bypass List : "+$winInet.ProxyOverride
    Write-Host $winInetBypass
    Write-Log -Message $winInetBypass
    $winInetAutoConfigURL="    AutoConfigURL : "+$winInet.AutoConfigURL
    Write-Host $winInetAutoConfigURL
    Write-Log -Message $winInetAutoConfigURL

    return $global:ProxyServer
}

Function Write-Log{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)]
        [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
        [String] $Level = "INFO",

        [Parameter(Mandatory=$True)]
        [string] $Message,

        [Parameter(Mandatory=$False)]
        [string] $logfile = "Test-DeviceRegConnectivity.log"
    )
    if ($Message -eq " "){
        Add-Content $logfile -Value " " -ErrorAction SilentlyContinue
    }else{
        #$Date= Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        $Date = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss.fff')
        Add-Content $logfile -Value "[$date] [$Level] $Message" -ErrorAction SilentlyContinue
    }
}

Function Test-DevRegConnectivity{
    $ProxyTestFailed=$false
    Write-Host
    Write-Host "Testing Internet Connectivity..." -ForegroundColor Yellow
    Write-Log -Message "Testing Internet Connectivity..."
    $ErrorActionPreference= 'silentlycontinue'
    $global:TestFailed=$false

    $global:ProxyServer = checkProxy
    Write-Host
    Write-Host "Testing Device Registration Endpoints..." -ForegroundColor Yellow
    Write-Log -Message "Testing Device Registration Endpoints..."
    if ($global:ProxyServer -ne "NoProxy"){
        Write-Host "Testing connection via winHTTP proxy..." -ForegroundColor Yellow
        Write-Log -Message "Testing connection via winHTTP proxy..."
        if ($global:login){
            $PSScript = "(Invoke-WebRequest -uri 'login.microsoftonline.com' -UseBasicParsing).StatusCode"
            $TestResult = RunPScript -PSScript $PSScript
        }else{
            $PSScript = "(Invoke-WebRequest -uri 'login.microsoftonline.com' -UseBasicParsing -Proxy $global:ProxyServer).StatusCode"
            $TestResult = RunPScript -PSScript $PSScript
        }
        if ($TestResult -eq 200){
            Write-Host ''
            Write-Host "Connection to login.microsoftonline.com .............. Succeeded." -ForegroundColor Green
            Write-Log -Message "Connection to login.microsoftonline.com .............. Succeeded."
        }else{
            $ProxyTestFailed=$true
        }

        if ($global:device){
            $PSScript = "(Invoke-WebRequest -uri 'device.login.microsoftonline.com' -UseBasicParsing).StatusCode"
            $TestResult = RunPScript -PSScript $PSScript
        }else{
            $PSScript = "(Invoke-WebRequest -uri 'device.login.microsoftonline.com' -UseBasicParsing -Proxy $global:ProxyServer).StatusCode"
            $TestResult = RunPScript -PSScript $PSScript
        }
        if ($TestResult -eq 200){
            Write-Host "Connection to device.login.microsoftonline.com ......  Succeeded." -ForegroundColor Green
            Write-Log -Message "Connection to device.login.microsoftonline.com ......  Succeeded."
        }else{
            $ProxyTestFailed=$true
        }

        if ($global:enterprise){
            $PSScript = "(Invoke-WebRequest -uri 'https://enterpriseregistration.windows.net/microsoft.com/discover?api-version=1.7' -UseBasicParsing -Headers @{'Accept' = 'application/json'; 'ocp-adrs-client-name' = 'dsreg'; 'ocp-adrs-client-version' = '10'}).StatusCode"
            $TestResult = RunPScript -PSScript $PSScript
        }else{
            $PSScript = "(Invoke-WebRequest -uri 'https://enterpriseregistration.windows.net/microsoft.com/discover?api-version=1.7' -UseBasicParsing -Proxy $global:ProxyServer -Headers @{'Accept' = 'application/json'; 'ocp-adrs-client-name' = 'dsreg'; 'ocp-adrs-client-version' = '10'}).StatusCode"
            $TestResult = RunPScript -PSScript $PSScript
        }
        if ($TestResult -eq 200){
            Write-Host "Connection to enterpriseregistration.windows.net ..... Succeeded." -ForegroundColor Green
            Write-Log -Message "Connection to enterpriseregistration.windows.net ..... Succeeded."
        }else{
            $ProxyTestFailed=$true
        }
    }
    
    if (($global:ProxyServer -eq "NoProxy") -or ($ProxyTestFailed -eq $true)){
        if($ProxyTestFailed -eq $true){
            Write-host "Connection failed via winHTTP, trying winInet..."
            Write-Log -Message "Connection failed via winHTTP, trying winInet..." -Level WARN
        }else{
            Write-host "Testing connection via winInet..." -ForegroundColor Yellow
            Write-Log -Message "Testing connection via winInet..."
        }
        $PSScript = "(Invoke-WebRequest -uri 'login.microsoftonline.com' -UseBasicParsing).StatusCode"
        $TestResult = RunPScript -PSScript $PSScript
        if ($TestResult -eq 200){
            Write-Host ''
            Write-Host "Connection to login.microsoftonline.com .............. Succeeded." -ForegroundColor Green
            Write-Log -Message "Connection to login.microsoftonline.com .............. Succeeded."
        }else{
            $global:TestFailed=$true
            Write-Host ''
            Write-Host "Connection to login.microsoftonline.com ................. failed." -ForegroundColor Red
            Write-Log -Message "Connection to login.microsoftonline.com ................. failed." -Level ERROR
        }
        $PSScript = "(Invoke-WebRequest -uri 'device.login.microsoftonline.com' -UseBasicParsing).StatusCode"
        $TestResult = RunPScript -PSScript $PSScript
        if ($TestResult -eq 200){
            Write-Host "Connection to device.login.microsoftonline.com ......  Succeeded." -ForegroundColor Green
            Write-Log -Message "Connection to device.login.microsoftonline.com ......  Succeeded."
        }else{
            $global:TestFailed=$true
            Write-Host "Connection to device.login.microsoftonline.com .......... failed." -ForegroundColor Red
            Write-Log -Message "Connection to device.login.microsoftonline.com .......... failed." -Level ERROR
        }

        $PSScript = "(Invoke-WebRequest -uri 'https://enterpriseregistration.windows.net/microsoft.com/discover?api-version=1.7' -UseBasicParsing -Headers @{'Accept' = 'application/json'; 'ocp-adrs-client-name' = 'dsreg'; 'ocp-adrs-client-version' = '10'}).StatusCode"
        $TestResult = RunPScript -PSScript $PSScript
        if ($TestResult -eq 200){
            Write-Host "Connection to enterpriseregistration.windows.net ..... Succeeded." -ForegroundColor Green
            Write-Log -Message "Connection to enterpriseregistration.windows.net ..... Succeeded."
        }else{
            $global:TestFailed=$true
            Write-Host "Connection to enterpriseregistration.windows.net ........ failed." -ForegroundColor Red
            Write-Log -Message "Connection to enterpriseregistration.windows.net ........ failed." -Level ERROR
        }
    }

    # If test failed
    if ($global:TestFailed){
        Write-Host ''
        Write-Host ''
        Write-Host "Test failed: device is not able to communicate with MS endpoints under system account" -ForegroundColor red -BackgroundColor Black
        Write-Log -Message "Test failed: device is not able to communicate with MS endpoints under system account" -Level ERROR
        Write-Host ''
        Write-Host "Recommended actions: " -ForegroundColor Yellow
        Write-Host "- Make sure that the device is able to communicate with the above MS endpoints successfully under the system account." -ForegroundColor Yellow
        Write-Host "- If the organization requires access to the internet via an outbound proxy, it is recommended to implement Web Proxy Auto-Discovery (WPAD)." -ForegroundColor Yellow
        Write-Host "- If you don't use WPAD, you can configure proxy settings with GPO by deploying WinHTTP Proxy Settings on your computers beginning with Windows 10 1709." -ForegroundColor Yellow
        Write-Host "- If the organization requires access to the internet via an authenticated outbound proxy, make sure that Windows 10 computers can successfully authenticate to the outbound proxy using the machine context." -ForegroundColor Yellow
        Write-Log -Message "Recommended actions:
        - Make sure that the device is able to communicate with the above MS endpoints successfully under the system account.
        - If the organization requires access to the internet via an outbound proxy, it is recommended to implement Web Proxy Auto-Discovery (WPAD).
        - If you don't use WPAD, you can configure proxy settings with GPO by deploying WinHTTP Proxy Settings on your computers beginning with Windows 10 1709.
        - If the organization requires access to the internet via an authenticated outbound proxy, make sure that Windows 10 computers can successfully authenticate to the outbound proxy using the machine context."
        Write-Host ''
        Write-Host ''
        Write-Host "Script completed successfully." -ForegroundColor Green -BackgroundColor Black
        Write-Log -Message "Script completed successfully."
        Write-Host ''
    }else{
        Write-Host ''
        Write-Host "Test passed: Device is able to communicate with MS endpoints successfully under system context" -ForegroundColor Green -BackgroundColor Black
        Write-Log -Message "Test passed: Device is able to communicate with MS endpoints successfully under system context"
        Write-Host ''
        Write-Host ''
        Write-Host "Script completed successfully." -ForegroundColor Green -BackgroundColor Black
        Write-Log -Message "Script completed successfully."
        Write-Host ''
    }
}

Function PSasAdmin{
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$global:Bypass=""
$global:login=$false
$global:device=$false
$global:enterprise=$false

Write-Host ''
'====================================================='
Write-Host '        Test Device Registration Connectivity        ' -ForegroundColor Green 
'====================================================='

Add-Content ".\Test-DeviceRegConnectivity.log" -Value "===========================================================================" -ErrorAction SilentlyContinue
if($Error[0].Exception.Message -ne $null){
    if($Error[0].Exception.Message.Contains('denied')){
        Write-Host ''
        Write-Host "Was not able to create log file." -ForegroundColor Yellow
    }else{
        Write-Host ''
        Write-Host "Test-DeviceRegConnectivity log file has been created." -ForegroundColor Yellow -BackgroundColor black
    }
}else{
    Write-Host "Test-DeviceRegConnectivity log file has been created." -ForegroundColor Yellow -BackgroundColor black
    Write-Host ''
}
Add-Content ".\Test-DeviceRegConnectivity.log" -Value "===========================================================================" -ErrorAction SilentlyContinue
Write-Log -Message "Test-DeviceRegConnectivity 3.0 has started"
$msg="Device Name : " + (Get-Childitem env:computername).value
Write-Log -Message $msg
$msg="User Account: " + (whoami) +", UPN: "+(whoami /upn)
Write-Log -Message $msg

if (PSasAdmin){
    # PS running as admin.
    Test-DevRegConnectivity
}else{
    Write-Host ''
    Write-Host "PowerShell is NOT running with elevated privileges" -ForegroundColor Red -BackgroundColor Black
    Write-Log -Message "PowerShell is NOT running with elevated privileges" -Level ERROR
    Write-Host ''
    Write-Host "Recommended action: This test needs to be running with elevated privileges" -ForegroundColor Yellow -BackgroundColor Black
    Write-Log -Message "Recommended action: This test needs to be running with elevated privileges"
    Write-Host ''
    Write-Host ''
    Write-Host "Script completed successfully." -ForegroundColor Green -BackgroundColor Black
    Write-Log -Message "Script completed successfully."
    Write-Host ''
    exit
}
