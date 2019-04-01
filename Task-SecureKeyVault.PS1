#
# Enforce Key rotation for a Storage Account with a Key Vault (Both in the same resource Group)
# Author : Benoît SAUTIERE
# Version : 1.0 : Initial release
param(
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$resourcegroupName,

    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$StorageAccountname,

    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$KeyVaultName,

    [Parameter(Mandatory=$False)]
    [ValidateNotnullorEmpty()]
    [String]$StorageAccountKeyName = "key1",

    [Parameter(Mandatory=$False)]
    [ValidateNotnullorEmpty()]
    [String]$KeyRotationPeriod = 30
)
#
# Check Resource Group
# OK
$CheckResourceGroup = Get-AzureRmResourceGroup -Name $resourcegroupName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckResourceGroup) -eq $true)
{
    #
    # Resource Group does not exists
    # OK
    Write-Warning "[Task - SecureKeyVault] - Resource Group $CheckResourceGroup does not exists in current Azure Subscription."
    Exit
}
else {
    #
    # Resource group exists 
    # OK
    Write-Output "[Task - SecureKeyVault] - Resource Group $ResourceGroupName exists."
}
#
# Check KeyVault in resource group
#
$CheckKeyVault =  Get-AzurermResource -ResourceGroupName $resourcegroupName -ResourceType Microsoft.KeyVault/vaults -Name $KeyVaultName -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckKeyVault) -eq $true)
{
    #
    # Key Vault not found in previous resource group
    # OK
    Write-Warning "[Task - SecureKeyVault] - Key Vault named $KeyVaultName not found in Resource Group $resourcegroupName."
    Exit
}
else {
    #
    # Key Vault found in previous resource group
    # OK
    Write-output "[Task - SecureKeyVault] - Key Vault named $KeyVaultName found in Resource Group $resourcegroupName."    
}
#
# Check if Keyvault have Soft-Delete feature enabled
# OK
If ($CheckKeyVault.Properties.enableSoftDelete -eq $true)
{
    #
    # Soft-Delete feature is already enabled on Key Vault, no need to configure it
    # OK
    Write-Output "[Task - SecureKeyVault] - Key Vault named $KeyVaultName already have soft-delete feature enabled."
}
else {
    #
    # Update existing key-Vault to enable Soft-Delete Feature
    # OK
    Write-Output "[Task - SecureKeyVault] - Key Vault named $KeyVaultName is not yet configured with soft-delete feature enabled."
    ($resource = Get-AzurermResource -ResourceId (Get-AzurermKeyVault -VaultName $Keyvaultname).ResourceId).Properties | Add-Member -MemberType "NoteProperty" -Name "enableSoftDelete" -Value "true"
    Set-Azurermresource -resourceid $resource.ResourceId -Properties $resource.Properties -Force
    Write-Output "[Task - SecureKeyVault] - Key Vault named $KeyVaultName is now configured with soft-delete feature enabled."
}
#
# Check if Purge-protection feature is enabled on keyvault
# OK
If ($CheckKeyVault.Properties.EnablePurgeProtection -eq $true)
{
    #
    # Purge-protection feature is already enabled on Key Vault
    # OK
    Write-Output "[Task - SecureKeyVault] - Key Vault named $KeyVaultName already have purge protection feature enabled."
}
Else
{
    #
    # Purge-protection feature is not yet enabled on key Vault
    #
    Write-Output "[Task - SecureKeyVault] - Key Vault named $KeyVaultName is not yet configured with purge protection feature enabled."
    ($resource = Get-AzurermResource -ResourceId (Get-AzurermKeyVault -VaultName $Keyvaultname).ResourceId).Properties | Add-Member -MemberType "NoteProperty" -Name "EnablePurgeProtection" -Value "true"
    Set-Azurermresource -resourceid $resource.ResourceId -Properties $resource.Properties -Force
    Write-Output "[Task - SecureKeyVault] - Key Vault named $KeyVaultName is now configured with purge-protection feature enabled."
}
$CheckKeyVault =  Get-AzurermResource -ResourceGroupName $resourcegroupName -ResourceType Microsoft.KeyVault/vaults -Name $KeyVaultName -ErrorAction SilentlyContinue
#
# Check for Storage Account in resource Group
# OK
$CheckStorageAccount =  Get-AzurermResource -ResourceGroupName $resourcegroupName -ResourceType Microsoft.Storage/storageAccounts -Name $StorageAccountname -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($CheckStorageAccount) -eq $true)
{
    #
    # Required Storage Account does not existe in resource group
    # OK
    Write-Warning "[Task - SecureKeyVault] - Storage Account named $StorageAccountname not found in Resource Group $resourcegroupName."
    Exit
}
else {
    #
    # Required Storage Account exists in resource group
    #
    Write-output "[Task - SecureKeyVault] - Storage Account named $StorageAccountname found in Resource Group $resourcegroupName."    
}
#
# Check Storage Account for MSI enabled
#
# Revoir cette partie si fonctionne bien
$storageaccount = Get-AzureRmStorageAccount -ResourceGroupName $resourcegroupName -Name $StorageAccountname 
If([string]::IsNullOrEmpty($storageaccount.Identity) -eq $true)
{
    Write-Output "[Task - SecureKeyVault] - Storage Account $StorageAccountname does not have MSI enabled."
    $storageaccount = Set-AzureRmStorageAccount -ResourceGroupName $resourcegroupName -Name $StorageAccountname  -AssignIdentity    
    Start-Sleep -Seconds 60 # required to avoir issues with Azure AD replication
}
else {
    Write-Output "[Task - SecureKeyVault] - Storage Account $StorageAccountname already have MSI enabled."
}
Write-Output "[Task - SecureKeyVault] - Storage Account $StorageAccountname PrincipalID is $($storageaccount.Identity.PrincipalId)"
#
# Permission pour le stockage
# OK
Write-Output "[Task - SecureKeyVault] - Enforce key permisions for Storage account Principal ID."
Set-AzureRmKeyVaultAccessPolicy -VaultName $Keyvaultname -ObjectId $Storageaccount.Identity.PrincipalId -PermissionsToKeys wrapKey, unwrapKey, get
#
# Enforce permission on Storage Account for KeyVault Identity
# OK
Write-Output "[Task - SecureKeyVault] - Enforce Storage Account Key Operator Service role for Storage Account."
$KeyVaultServicePrincipal = Get-AzureRmADServicePrincipal | Where-Object {$_.displayname -like "Azure Key Vault"}
New-AzureRmRoleAssignment -ObjectId $KeyVaultServicePrincipal.id.Guid -RoleDefinitionName "Storage Account Key Operator Service Role" -Scope $Storageaccount.Id -ErrorAction SilentlyContinue
#
# Enforce permissions on KeyVault for connected user
# OK
Write-Output "[Task - SecureKeyVault] - Enforce storage permissions in Key Vault for connected user."
Set-AzureRmKeyVaultAccessPolicy -VaultName $Keyvaultname -ResourceGroupName $resourcegroupName -UserPrincipalName (Get-AzureRmContext).account.id -PermissionsToStorage set, get, regeneratekey, list, getsas, setsas
#
# Configure Key Rotation of Storage Account for Key1
#
Write-Output "[Task - SecureKeyVault] - Enforce Storage key rotation for $StorageAccountKeyName."
$RegenerationPeriod = [System.TimeSpan]::FromDays($KeyRotationPeriod)
$parameters = @{
    VaultName = $Keyvaultname
    AccountResourceId = $StorageAccount.Id
    AccountName = $StorageAccountname
    ActiveKeyName = $StorageAccountKeyName
    RegenerationPeriod = $RegenerationPeriod
}
Add-AzureKeyVaultManagedStorageAccount @Parameters
Write-Output "[Task - SecureKeyVault] - Storage key rotation enabled successfully for Storage Account $StorageAccountname for key $StorageAccountKeyName."
#
# Initiate a Key Rotation now
# OK
Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $storageAccountName | Where-Object {$_.Keyname -match $StorageAccountKeyName}
Write-Output "[Task - SecureKeyVault] - Initiate a Key rotation for Storage Account $StorageAccountname for key $StorageAccountKeyName."
Update-AzureKeyVaultManagedStorageAccountKey -VaultName $keyVaultName -AccountName $storageAccountName -KeyName $StorageAccountKeyName -Force
Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $storageAccountName | Where-Object {$_.Keyname -match $StorageAccountKeyName}