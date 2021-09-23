
@description('Name of the App Service Environment')
param appServiceEnvName string
@description('Tags of the Resources')
param appServiceTags object
@description('Regional location of the App Service Environment')
param location string = resourceGroup().location
@description('Virtual Network Details')
param appServiceVnet object
@description('Name of the App Service Plan')
param appServicePlanName string
@allowed([
  'Test'
  'Acceptance'
  'Production'
])
@description('Environment of the solution (Test, Acceptance, Production)')
param appServiceEnvironment string
@description('Config per environment (Test, Acceptance, Production)')
param appServiceConfig object


// Limitation: Free Accounts can't try this. Time of Provisioning is about 2 hours.
resource appServiceEnvironmentResource 'Microsoft.Web/hostingEnvironments@2020-12-01' = if(appServiceEnvironment=='Production') {
  name: appServiceEnvName
  location: location
  tags: appServiceTags
  properties: {
    internalLoadBalancingMode: appServiceConfig.internalLoadBalancingMode
    virtualNetwork: {
      id: appServiceVnet.vnetId
      subnet: appServiceVnet.subnetId
    }
    multiSize: appServiceConfig.multiSize
  }
}



resource appServicePlan 'Microsoft.Web/serverfarms@2019-08-01' = {
  name: appServicePlanName
  location: location
  tags: appServiceTags
  kind: appServiceConfig.appServicePlanKind
  properties: {
    maximumElasticWorkerCount: appServiceConfig.maximumElasticWorkerCount
    reserved: true
    hostingEnvironmentProfile: (appServiceEnvironment=='Production') ? {
      id: appServiceEnvironmentResource.id
    } : null

  }
  sku: {
    name: appServiceConfig.appServicePlanSku.name
  }
}





output serviceEnvironmentId string = (appServiceEnvironment=='Production') ? appServiceEnvironmentResource.id : ''
output servicePlanId string = appServicePlan.id
