# TestDeviceRegConnectivity
Test-DeviceRegConnectivity PowerShell script helps to test the Internet connectivity to the following Microsoft resources under the system context to validate the connection status between the device that needs to be connected to Azure AD as hybrid Azure AD joined device and Microsoft resources that are used during device registration process:

  - https://login.microsoftonline.com
  - https://device.login.microsoftonline.com
  - https://enterpriseregistration.windows.net
 
 

Why is this script helpful?
  - You don’t need to rely on PS Exec tool to test the Internet connectivity under the system context, you need just to run it as administrator.
  - You don’t need to collect network trace during device registration and analyze it to verify the Internet connectivity.
  - You don’t need to check the Internet gateway (web proxy or firewall) to verify the Internet connectivity.


Using this script, Internet connectivity troubleshooting time will be reduced, and you need just to run it as administrator.
