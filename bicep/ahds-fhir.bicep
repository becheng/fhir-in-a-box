//Define parameters
param workspaceName string
param fhirName string
param tenantId string = subscription().tenantId
param location string = resourceGroup().location
param isImportEnabled bool = false
param isInitialImportMode bool = false
param importStorageAcctName string = '<storage-account-name>'

//Define variables
var fhirservicename = '${workspaceName}/${fhirName}'
var loginURL = environment().authentication.loginEndpoint
var authority = '${loginURL}${tenantId}'
var audience = 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'

//Create a workspace
resource ahdsWorkspace 'Microsoft.HealthcareApis/workspaces@2022-06-01' = {
  name: workspaceName
  location: location
}

// create a fhir resource
resource FHIRresource 'Microsoft.HealthcareApis/workspaces/fhirservices@2022-06-01' = {
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
      integrationDataStore: importStorageAcctName
    }
  }
}
