//Define parameters
param workspaceName string = 'ws${uniqueString(resourceGroup().id)}'
param fhirName string = 'fhir${uniqueString(resourceGroup().id)}'
param tenantId string = subscription().tenantId
param location string = resourceGroup().location
param kvName string = 'kv${uniqueString(resourceGroup().id)}'
param cicdServicePrincipalObjectId string = ''

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
  }
}

// create key vault
resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: kvName
  location: location
  properties: {
    accessPolicies: [
      {
        objectId:  cicdServicePrincipalObjectId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'  
          ]
        }
        tenantId: tenantId
      }
    ]
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
  }
}

// assign the service principal object Id with 'fhir contributor role' to the fhir service 
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
