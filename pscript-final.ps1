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

New-Item -Path 'C:\Users\demouser\cloudlabs-common' -ItemType Directory

Copy-Item -Path C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.12\Downloads\0\cloudlabs-common\cloudlabs-windows-functions.ps1 -Destination C:\Users\demouser\cloudlabs-common -Force


#Download git repository
New-Item -ItemType directory -Path C:\AllFiles
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://codeload.github.com/microsoft/Azure-Solution-Accelerator-Customer-Complaint-Management/zip/refs/heads/main","C:\AllFiles\AllFiles.zip")

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
Expand-ZIPFile -File "C:\AllFiles\AllFiles.zip" -Destination "C:\AllFiles\"

Function InstallChocolatey
{   
    #[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
    #[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 
    $env:chocolateyUseWindowsCompression = 'true'
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -Verbose
    choco feature enable -n allowGlobalConfirmation
}

InstallChocolatey

choco install python --version=3.7.2 --force


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


sleep 10

#Import creds

. C:\LabFiles\AzureCreds.ps1

$AzureUserName 
$AzurePassword 
$passwd = ConvertTo-SecureString $AzurePassword -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AzureUserName, $passwd


#deploy armtemplate

$deployID = $DeploymentID 
$office365DisplayName=$AzureUserName 
Import-Module Az
Connect-AzAccount -Credential $cred
Select-AzSubscription -SubscriptionId $AzureSubscriptionID
New-AzResourceGroupDeployment -ResourceGroupName "many-models" -TemplateUri https://raw.githubusercontent.com/singhsupriya2819/Many-Models-CustomerComplaintManagement/main/deploy2.json -DeploymentID $deployID -office365DisplayName $$AzureUserName

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
$storageName = $storageAccounts | Where-Object { $_.Name -like 'pati*' }
$storage = Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageName.Name
$storageContext = $storage.Context

$srcUrl = $null
$rgLocation = (Get-AzResourceGroup -Name $rgName).Location
          

$srcUrl = "https://experienceazure.blob.core.windows.net/raw?sp=racwdli&st=2022-07-04T14:53:48Z&se=2022-10-28T22:53:48Z&spr=https&sv=2021-06-08&sr=c&sig=dIS%2BQIE%2BFGPUq71lCMVnlfF%2Bt9OGvy1Og1AS9LD%2BBDc%3D"

           
$destContext = $storage.Context
$containerName = "raw"
$resources = $null

$startTime = Get-Date
$endTime = $startTime.AddDays(2)
$destSASToken = New-AzStorageContainerSASToken  -Context $destContext -Container "raw" -Permission rwd -StartTime $startTime -ExpiryTime $endTime
$destUrl = $destContext.BlobEndPoint + "raw" + $destSASToken

$srcUrl 
$destUrl

C:\LabFiles\azcopy.exe copy $srcUrl $destUrl --recursive

$synapseAccount = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Synapse/workspaces"
$synapseName = $synapseAccount | Where-Object { $_.Name -like 'scm*' }


#download notebooks
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://raw.githubusercontent.com/microsoft/Azure-Solution-Accelerator-Customer-Complaint-Management/main/Deployment/Notebooks/00_prepare_data.ipynb","C:\LabFiles\00_preparedata.ipynb")
$WebClient.DownloadFile("https://raw.githubusercontent.com/microsoft/Azure-Solution-Accelerator-Customer-Complaint-Management/main/Deployment/Notebooks/01_train_deploy_model.ipynb","C:\LabFiles\01_train_deploy_model.ipynb")

#running the notebooks
(Get-Content -Path "C:\LabFiles\00_preparedata.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name", "$storageName"} | Set-Content -Path "C:\LabFiles\00_preparedata.ipynb"
(Get-Content -Path "C:\LabFiles\00_preparedata.ipynb") | ForEach-Object {$_ -Replace "file_system_name", "$containerName"} | Set-Content -Path "C:\LabFiles\00_preparedata.ipynb"

(Get-Content -Path "") | ForEach-Object {$_ -Replace "data_lake_account_name", "$storageName"} | Set-Content -Path "C:\LabFiles\00_preparedata.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb") | ForEach-Object {$_ -Replace "file_system_name", "$containerName"} | Set-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb") | ForEach-Object {$_ -Replace "subscription_id", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb") | ForEach-Object {$_ -Replace "resource_group", "$rgName"} | Set-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb") | ForEach-Object {$_ -Replace "workspace_name", "$synapseName"} | Set-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb") | ForEach-Object {$_ -Replace "workspace_region", "$rgLocation"} | Set-Content -Path "C:\LabFiles\01_train_deploy_model.ipynb"


#Download LogonTask
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/many-models/machine-learning-patient-risk-analyzer/script/logon.ps1","C:\LabFiles\logon.ps1")


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

