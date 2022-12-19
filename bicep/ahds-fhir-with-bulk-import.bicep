//Define parameters
param workspaceName string = 'ws${uniqueString(resourceGroup().id)}'
param fhirName string = 'fhir${uniqueString(resourceGroup().id)}'
param tenantId string = subscription().tenantId
param location string = resourceGroup().location
param isImportEnabled bool = false
param isInitialImportMode bool = false
param importStorageAcctName string = 'fhirimpsa${uniqueString(resourceGroup().id)}'
param bulkImportBlobContainerName string = 'bulkimportsrc'
param azcopyServicePrincipalObjectId string = ''

//Define variables
var fhirservicename = '${workspaceName}/${fhirName}'
var loginURL = environment().authentication.loginEndpoint
var authority = '${loginURL}${tenantId}'
var audience = 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'


// storage account
resource storageAcct 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  name: importStorageAcctName
  location: location
}

// blobservices
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  parent: storageAcct
  name: 'default'
}

// blob container 
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  parent: blobService
  name: bulkImportBlobContainerName
  properties: {
    publicAccess: 'Container'
  }
}

//Create a workspace
resource ahdsWorkspace 'Microsoft.HealthcareApis/workspaces@2022-06-01' = {
  name: workspaceName
  location: location
}

// create a fhir resource
resource fhirService 'Microsoft.HealthcareApis/workspaces/fhirservices@2022-06-01' = {
  name: fhirservicename
  location: location
  kind: 'fhir-R4'
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    ahdsWorkspace
  ]
  properties: {
    accessPolicies: []
    authenticationConfiguration: {
      authority: authority
      audience: audience
      smartProxyEnabled: false
    }
    importConfiguration: {
      enabled: isImportEnabled
      initialImportMode: isInitialImportMode
      integrationDataStore: storageAcct.name
    }
  }
}

// exisiting Storage Blob Data Contributor, reference: https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

// assign the fhir managed system identity with RBAC role of 'Storage Blob Data Contributor' to the storage acct
// note: name must be a guid
resource storageRoleAssignmentWithFhir 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, fhirService.id, storageBlobDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: fhirService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// assign the service prinicapl object Id with RBAC role of 'Storage Blob Data Contributor' to the storage acct so SP can perform azcopy 
// note: name must be a guid
resource storageRoleAssignmentWithSP 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(azcopyServicePrincipalObjectId)) {
  name: guid(subscription().id, azcopyServicePrincipalObjectId, storageBlobDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: azcopyServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}
