Param (
    [Parameter(Mandatory = $true)]
    [string]
    $AzureUserName,

    [string]
    $AzurePassword,

    [string]
    $AzureTenantID,

    [string]
    $AzureSubscriptionID,

    [string]
    $ODLID,

    [string]
    $DeploymentID,

    [string]
    $InstallCloudLabsShadow
)

Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt -Append
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 


#Download git repository
New-Item -ItemType directory -Path C:\AllFiles
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/microsoft/Azure-Solution-Accelerator-Customer-Complaint-Management.git","C:\LabFiles\Azure-Solution-Accelerator-Customer-Complaint-Management-main.zip")

#unziping folder
function Expand-ZIPFile($file, $destination)
{
$shell = new-object -com shell.application
$zip = $shell.NameSpace($file)
foreach($item in $zip.items())
{
$shell.Namespace($destination).copyhere($item)
}
}
Expand-ZIPFile -File "C:\LabFiles\Azure-Solution-Accelerator-Customer-Complaint-Management-main.zip" -Destination "C:\LabFiles\"


Function InstallAzPowerShellModule
{
    <#Install-PackageProvider NuGet -Force
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module Az -Repository PSGallery -Force -AllowClobber#>

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("https://github.com/Azure/azure-powershell/releases/download/v5.0.0-October2020/Az-Cmdlets-5.0.0.33612-x64.msi","C:\Packages\Az-Cmdlets-5.0.0.33612-x64.msi")
    sleep 5
    Start-Process msiexec.exe -Wait '/I C:\Packages\Az-Cmdlets-5.0.0.33612-x64.msi /qn' -Verbose 

}
InstallAzPowerShellModule

#Import Common Functions
$path = pwd
$path=$path.Path
$commonscriptpath = "$path" + "\cloudlabs-common\cloudlabs-windows-functions.ps1"
. $commonscriptpath

# Run Imported functions from cloudlabs-windows-functions.ps1
WindowsServerCommon

CreateCredFile $AzureUserName $AzurePassword $AzureTenantID $AzureSubscriptionID $DeploymentID


#Download power Bi desktop

$WebClient = New-Object System.Net.WebClient

$WebClient.DownloadFile("https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup_x64.exe","C:\LabFiles\PBIDesktop_x64.exe")


#INstall power Bi desktop

Start-Process -FilePath "C:\LabFiles\PBIDesktop_x64.exe" -ArgumentList '-quiet','ACCEPT_EULA=1'

[Environment]::SetEnvironmentVariable("PBI_enableWebView2Preview","0", "Machine")

sleep 10

#Create shorcut in desktop
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\StorageExplorer.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Microsoft Azure Storage Explorer\StorageExplorer.exe"
$Shortcut.Save()

#Copy PowerBI file to the Desktop
#$WebClient = New-Object System.Net.WebClient
#$WebClient.DownloadFile("https://raw.githubusercontent.com/microsoft/Azure-Solution-Accelerator-to-automate-COVID-19-Vaccination-Proof-and-Test-Verification-Forms/main/Deployment/PowerBI/TestingVaccineDashboard.pbix","C:\LabFiles\TestingVaccineDashboard.pbit")

Copy-Item -Path C:\LabFiles\TestingVaccineDashboard.pbit -Destination C:\Users\public\Desktop -Force


#Import creds

. C:\LabFiles\AzureCreds.ps1

$AzureUserName 
$AzurePassword 
$passwd = ConvertTo-SecureString $AzurePassword -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AzureUserName, $passwd


#deploy armtemplate

#Import-Module Az
#Connect-AzAccount -Credential $cred
#Select-AzSubscription -SubscriptionId $AzureSubscriptionID
#New-AzResourceGroupDeployment -ResourceGroupName "many-models" -TemplateUri https://experienceazure.blob.core.windows.net/templates/many-models/covid-19-vaccine-proof/deploy-01.json 

#storage copy
$userName = $AzureUserName
$password = $AzurePassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SpektraSystems/CloudLabs-Azure/master/azure-synapse-analytics-workshop-400/artifacts/setup/azcopy.exe" -OutFile "C:\labfiles\azcopy.exe"

$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Credential $cred | Out-Null

$rgName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "many*" }).ResourceGroupName
$storageAccounts = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Storage/storageAccounts"
$storageName = $storageAccounts | Where-Object { $_.Name -like 'syn*' }
$storage = Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageName.Name
$storageContext = $storage.Context

$srcUrl = $null
$rgLocation = (Get-AzResourceGroup -Name $rgName).Location
          

$srcUrl = "https://experienceazure.blob.core.windows.net/training?sp=racwdli&st=2022-05-12T08:30:50Z&se=2022-12-31T16:30:50Z&sv=2020-08-04&sr=c&sig=cQ8wPd8nHr7M0N1nr6BYLmrmoH6PJFl1frV%2B2XeeYzQ%3D"

           
$destContext = $storage.Context
$containerName = "training"
$resources = $null

$startTime = Get-Date
$endTime = $startTime.AddDays(2)
$destSASToken = New-AzStorageContainerSASToken  -Context $destContext -Container "training" -Permission rwd -StartTime $startTime -ExpiryTime $endTime
$destUrl = $destContext.BlobEndPoint + "training" + $destSASToken

$srcUrl 
$destUrl

C:\LabFiles\azcopy.exe copy $srcUrl $destUrl --recursive



#Enable Auto-Logon
$AutoLogonRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoAdminLogon" -Value "1" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultUsername" -Value "$($env:ComputerName)\demouser" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultPassword" -Value "Password.1!!" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoLogonCount" -Value "1" -type DWord



# Scheduled Task
$Trigger= New-ScheduledTaskTrigger -AtLogOn
$User= "$($env:ComputerName)\demouser"
$Action= New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe" -Argument "-executionPolicy Unrestricted -File C:\LabFiles\logon.ps1"
Register-ScheduledTask -TaskName "Setup" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest -Force
Set-ExecutionPolicy -ExecutionPolicy bypass -Force
