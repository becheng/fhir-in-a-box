//Define parameters
param workspaceName string = 'ws${uniqueString(resourceGroup().id)}'
param fhirName string = 'fhir${uniqueString(resourceGroup().id)}'
param tenantId string = subscription().tenantId
param location string = resourceGroup().location
param cicdServicePrincipalObjectId string = ''
param kvName string = 'kv${uniqueString(resourceGroup().id)}'
param fsUrl string = '' // e.g. https://ws35d75573-fhir35d75573.fhir.azurehealthcareapis.com
param fsTenantId string = ''
param fsClientId string = ''
@secure()
param fsClientSecret string = ''
param fsResource string = ''  // e.g. https://ws35d75573-fhir35d75573.fhir.azurehealthcareapis.com
param fhirLoaderServicePrincipalObjectId string = ''

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

// Note: deploy a key vault with the necessary secrets for the oss fhir loader
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

// create kv secret fhir service url 
resource fsUrlSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyvault
  name: 'FS-URL'
  properties: {
    value: fsUrl
  }
}

// create kv secret fhir tenant 
resource fsTenantSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyvault
  name: 'FS-TENANT-NAME'
  properties: {
    value: fsTenantId
  }
}

// create kv secret clientId 
resource fsClientIdSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyvault
  name: 'FS-CLIENT-ID'
  properties: {
    value: fsClientId
  }
}

// create kv secret clientSecret 
resource fsClientSecretSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyvault
  name: 'FS-SECRET'
  properties: {
    value: fsClientSecret
  }
}

// create kv secret clientSecret 
resource fsResourceSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyvault
  name: 'FS-RESOURCE'
  properties: {
    value: fsResource
  }
}

// reference: https://docs.microsoft.com/azure/role-based-access-control/built-in-roles
// assign the github app service principal object Id with 'fhir reader role' to the fhir service 
// Note: in production, becareful not to leak PHI to the logs
resource fhirReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4c8d0bbc-75d3-4935-991f-5f3c56d81508'
}
// create the role assignment
resource fhirRoleAssignmentToGPSP 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(cicdServicePrincipalObjectId)) {
  scope: fhirService 
  name: guid(subscription().id, cicdServicePrincipalObjectId, fhirReaderRoleDefinition.id)
  properties: {
    roleDefinitionId: fhirReaderRoleDefinition.id
    principalId: cicdServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

// assign the fhir-loader aad app service principal object Id with 'fhir contributor role' to the fhir service 
resource fhirContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '5a1fc7df-4bf1-4951-a576-89034ee01acd'
}
// create the role assignment
resource fhirRoleAssignmentToFHIRLoaderSP 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(cicdServicePrincipalObjectId)) {
  scope: fhirService 
  name: guid(subscription().id, fhirLoaderServicePrincipalObjectId, fhirContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: fhirContributorRoleDefinition.id
    principalId: fhirLoaderServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}
