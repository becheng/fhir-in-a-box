param location string = resourceGroup().location
param storage_acct_name string = 'fhirimpsa${uniqueString(resourceGroup().id)}'
param blob_container_name string = 'importsrc'


// target storage account that will have a private endpoint blob
resource storage_acct 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  name: storage_acct_name
  location: location
}

// create a blobservices in the target storage acct - fyi, 'name' must be 'default'
resource blob_service 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  parent: storage_acct
  name: 'default'
}

// create a 'default' blob container 
resource blob_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  parent: blob_service
  name: blob_container_name
  properties: {
    publicAccess: 'Container'
  }
}
