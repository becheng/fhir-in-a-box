//Define parameters
param workspaceName string
param fhirName string
param tenantId string = subscription().tenantId
param location string = resourceGroup().location

//Define variables
var fhirservicename = '${workspaceName}/${fhirName}'
var loginURL = environment().authentication.loginEndpoint
var authority = '${loginURL}${tenantId}'
var audience = 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'

//Create a workspace
resource ahdsWorkspace 'Microsoft.HealthcareApis/workspaces@2021-06-01-preview' = {
  name: workspaceName
  location: location
}

// create a fhir resource
resource FHIRresource 'Microsoft.HealthcareApis/workspaces/fhirservices@2021-11-01' = {
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
  }
}


