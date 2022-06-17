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
    $azuserobjectid,
    [string]
    $vmAdminUsername,
    [string]
    $trainerUserName,
    [string]
    $trainerUserPassword

)

Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt -Append
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 
$adminUsername = "demouser"

#Import Common Functions
$path = pwd
$path=$path.Path
$commonscriptpath = "$path" + "\cloudlabs-common\cloudlabs-windows-functions.ps1"
. $commonscriptpath

# Run Imported functions from cloudlabs-windows-functions.ps1
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 
Disable-InternetExplorerESC
Enable-IEFileDownload
Enable-CopyPageContent-In-InternetExplorer
InstallChocolatey
DisableServerMgrNetworkPopup
CreateLabFilesDirectory
DisableWindowsFirewall
CreateCredFile $AzureUserName $AzurePassword $AzureTenantID $AzureSubscriptionID $DeploymentID $azuserobjectid
Enable-CloudLabsEmbeddedShadow $vmAdminUsername $trainerUserName $trainerUserPassword

#Download and Install edge

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("http://go.microsoft.com/fwlink/?LinkID=2093437","C:\Packages\MicrosoftEdgeBetaEnterpriseX64.msi")
    sleep 5
    
    Start-Process msiexec.exe -Wait '/I C:\Packages\MicrosoftEdgeBetaEnterpriseX64.msi /qn' -Verbose 
    sleep 5
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Azure Portal.lnk")
    $Shortcut.TargetPath = """C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"""
    $argA = """https://make.powerapps.com"""
    $Shortcut.Arguments = $argA 
    $Shortcut.Save()

#Disable Welcome page of Microsoft Edge:

    Set-Location hklm:
    Test-Path .\Software\Policies\Microsoft
    New-Item -Path .\Software\Policies\Microsoft -Name MicrosoftEdge
    New-Item -Path .\Software\Policies\Microsoft\MicrosoftEdge -Name Main
    New-ItemProperty -Path .\Software\Policies\Microsoft\MicrosoftEdge\Main -Name PreventFirstRunPage -Value "1" -Type DWORD -Force -ErrorAction SilentlyContinue | Out-Null

#Setting up the edge browser as default

    Invoke-WebRequest 'https://experienceazure.blob.core.windows.net/templates/cloudlabs-common/SetUserFTA.zip' -OutFile 'C:\SetUserFTA.zip'
    Expand-Archive -Path 'C:\SetUserFTA.zip' -DestinationPath 'C:\' -Force
    cmd.exe /c C:\SetUserFTA\SetUserFTA.exe
    cmd.exe /c cd C:\SetUserFTA
    cmd.exe /c SetuserFTA http MSEdgeHTM
    cmd.exe /c SetuserFTA https MSEdgeHTM
    cmd.exe /c SetuserFTA .htm MSEdgeHTM
    Sleep 5
    Remove-Item -Path 'C:\SetUserFTA.zip'
    Remove-Item -Path 'C:\SetUserFTA' -Force -Recurse

# Download labfiles

New-Item -ItemType directory -Path C:\LabFiles
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/microsoft/Azure-Solution-Accelerator-Customer-Complaint-Management.git","C:\LabFiles\Azure-Solution-Accelerator-Customer-Complaint-Management-main.zip")
Expand-Archive -LiteralPath 'C:\LabFiles\Azure-Solution-Accelerator-Customer-Complaint-Management-main.zip' -DestinationPath 'C:\LabFiles\Azure-Solution-Accelerator-Customer-Complaint-Management-main' -Force

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://files.consumerfinance.gov/ccdb/complaints.csv.zip","C:\LabFiles\complaints.csv.zip")
Expand-Archive -LiteralPath 'C:\LabFiles\complaints.csv.zip' -DestinationPath 'C:\LabFiles\complaints.csv' -Force

Stop-Transcript
Restart-Computer -Force 
