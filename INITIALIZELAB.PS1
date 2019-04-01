#
# Initialize variables
#
# C'est du Powershell ARM et pas du PowershellCore cause encore quelquesl particularités
# Préparer une version en Powershell Core
[Int]$Random = Get-Random -Minimum 1000 -Maximum 9999
[String]$resourcegroupName = "KeyVaultLab$Random"
[String]$StorageAccountname = $resourcegroupName.ToLower()
[String]$Keyvaultname = ("KeyVaultLab$Random").ToLower()
[String]$location = "WestEurope"
[String]$StorageSKU = "Standard_LRS"
[String]$StorageKind = "StorageV2"
#
# Initialize lab with random Storage Account & Key Vault into a dedicated Resource Group
#
New-AzureRmResourceGroup -Name $resourcegroupName -Location $location
New-AzureRmStorageAccount -ResourceGroupName $resourcegroupName -Name $StorageAccountname -Location $location -SkuName $StorageSKU -Kind $StorageKind
New-AzureRmKeyVault -ResourceGroupName $resourcegroupName -Name $Keyvaultname -Location $location
