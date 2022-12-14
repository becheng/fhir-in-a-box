//Define parameters
param workspaceName string = 'ws${uniqueString(resourceGroup().id)}'
param fhirName string = 'fhir${uniqueString(resourceGroup().id)}'
param tenantId string = subscription().tenantId
param location string = resourceGroup().location
param isImportEnabled bool = false
param isInitialImportMode bool = false
param importStorageAcctName string = 'fhirimpsa${uniqueString(resourceGroup().id)}'
param bulkImportBlobContainerName string = 'bulkimportsrc'
param cicdServicePrincipalObjectId string = ''

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
resource storageRoleAssignmentToFhir 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAcct
  name: guid(subscription().id, fhirService.id, storageBlobDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: fhirService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// assign the service principal object Id with RBAC role of 'Storage Blob Data Contributor' to the storage acct so SP can perform azcopy 
// note: name must be a guid
resource storageRoleAssignmentToSP 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(cicdServicePrincipalObjectId)) {
  scope: storageAcct 
  name: guid(subscription().id, cicdServicePrincipalObjectId, storageBlobDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: cicdServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

// assign the service principal object Id with fhir importer role to the fhir service so SP can call its $import endpoint
// resource fhirImporterRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: subscription()
//   name: '4465e953-8ced-4406-a58e-0f6e3f3b530b'
//}
// assign the service principal object Id with 'fhir contributor role' to the fhir service so SP can call its $import endpoint
resource fhirContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '5a1fc7df-4bf1-4951-a576-89034ee01acd'
}
resource fhirRoleAssignmentToSP 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(cicdServicePrincipalObjectId)) {
  scope: fhirService 
  name: guid(subscription().id, cicdServicePrincipalObjectId, fhirContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: fhirContributorRoleDefinition.id
    principalId: cicdServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}
