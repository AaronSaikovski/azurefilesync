<#
Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment. 
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code,
provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded;
and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
*/
#>

##Original code taken from here:https://github.com/jbernec/AzurePowerShellAutomation/tree/master/AzureFileStorageCopy

#region Azure Logon

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint   $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
} 

#endregion

#set Azure subscription
Select-AzureRmSubscription -Subscriptionid "<SUBSCRIPTION_ID>"

#Initialize storage variables
$StorageAccountName = "demostorageaue01"
$DestStorageAccountName = "demostorageause01"
$SrcResourceGroupName = "demo-storage-poc"
$DestResourceGroupName = "demo-storage-poc"
$Store = Get-AzureRmStorageAccount -ResourceGroupName $SrcResourceGroupName -AccountName $StorageAccountName
$Shares = Get-AzureStorageShare -Context $Store.context
$Deststore = Get-AzureRmStorageAccount -ResourceGroupName $DestResourceGroupName -AccountName $DestStorageAccountName
$Items = @()

#region MAIN
foreach ($Share in $Shares) {
    $Directories = Get-AzureStorageFile -Share $Share

    foreach ($Directory in $Directories) {
        if ((Get-AzureStorageShare -Name $Share.Name -Context $Deststore.Context -ErrorAction SilentlyContinue) -eq $null) { 
            
            New-AzureStorageShare -Name $Share.Name -Context $Deststore.Context    
        }
        if ((Get-AzureStorageFile -ShareName $Share.Name -Context $Deststore.Context -Path $Directory.Name -ErrorAction SilentlyContinue) -eq $null) {
            New-AzureStorageDirectory -ShareName $Share.Name -Context $Deststore.Context -Path $Directory.Name               
                
        }
        $sourcefiles = Get-AzureStorageFile -ShareName $Share.Name -Context $Store.context -Path $Directory.Name | Get-AzureStorageFile        
        $destfiles = Get-AzureStorageFile -ShareName $Share.Name -Context $Deststore.Context -Path $Directory.Name -ErrorAction SilentlyContinue `
            | Get-AzureStorageFile
        if ($destfiles.count -eq 0) {
            foreach ($sourcefile in $sourcefiles) {
                Start-AzureStorageFileCopy -SrcShareName $Share.Name -SrcFilePath ($Directory.Name + "/" + $sourcefile.Name)  -Context $Store.Context `
                    -DestShareName $Share.Name -DestFilePath ($Directory.Name + "/" + $sourcefile.Name) -DestContext $Deststore.Context -ErrorAction SilentlyContinue
            }
        }
        else {
            foreach ($sourcefile in $sourcefiles) {
                $sourcefile.FetchAttributes()
                if ($sourcefile.Properties.LastModified.LocalDateTime -gt ((Get-Date).AddMinutes(-60)) ) {
                    Start-AzureStorageFileCopy -SrcShareName $Share.Name -SrcFilePath ($Directory.Name + "/" + $sourcefile.Name)  -Context $Store.Context `
                        -DestShareName $Share.Name -DestFilePath ($Directory.Name + "/" + $sourcefile.Name) -DestContext $Deststore.Context -Force -ErrorAction SilentlyContinue

                    $copyState = Get-AzureStorageFileCopyState -ShareName $Share.Name -FilePath ($Directory.Name + "/" + $sourcefile.Name) -Context $Deststore.Context `
                        -WaitForComplete -ErrorAction SilentlyContinue
                    $Items += $copyState
                }
            }
        }
    }
}
#endregion

'Done!'