// Initial Parameters and Variables
// Parameter values are saved in /Installer/parameters.json
targetScope = 'subscription'
@allowed([
  'Test'
  'Acceptance'
  'Production'
])
@description('Environment of the solution (Test, Acceptance, Production)')
param Environment string = 'Test'
@minLength(3)
@maxLength(10)
@description('Name of the project - all lowercase')
param ProjectName string
@description('Virtual Network Setup and Configurations')
param NetworkConfig object
@description('Tags to be embedded to all resources')
param DefaultTags object
@description('IP Address of Admin or Owner')
param AdminIp string = ''
@description('IP Address range of the Client')
param ClientIp string = ''
@allowed([
  'southeastasia'
])
@description('Regional Location of the project')
param Location string
@description('PFX File Password')
@secure()
param PfxPassword string
@description('App Gateway Firewall Rule')
param AppGatewayWafSettings object
@description('Storage account configuration')
param StorageAccountConfig object
@description('App Service Plan Sizes')
param AppServicePlanSizes object
@description('Username and Password for SFTP Server')
@secure()
param FtpConfig object
@description('List of Azure Portal IP Addresses, this is useful for resources with Private Endpoints')
param AzurePortalIpAddresses array = []
//For Compile Time PFX integration - This is constant 'endpoint-ssl' because bicep's loadFileAsBase64() needs to know the file before runtime
var pfxFilePath = '../Installer/certs/endpoint-ssl.pfx'


// Create Resource Group
var resourceGroupName = toLower('${ProjectName}-rg')
resource projectRg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resourceGroupName
  location: Location
}

// Create Virtual Network
var virtualNetworDnsZoneName = toLower('${ProjectName}-${Environment}-${uniqueString(subscription().subscriptionId)}-internal.appserviceenvironment.net')
var virtualNetworkName = toLower('${ProjectName}-${Environment}-vnet')
var virtualNetworkConfig = NetworkConfig
module virtualNetworkModule './Modules/virtualNetwork.bicep' = {
  scope: projectRg
  name: 'virtualNetworkDeploy'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkTags: DefaultTags
    virtualNetworkConfig: virtualNetworkConfig
    virtualNetworDnsZoneName: virtualNetworDnsZoneName
    location: Location
    clientIp: ClientIp
  }
}

// Initiate Application Gateway - HTTPS Public Endpoint
var applicationGatewayName = toLower('${ProjectName}-${Environment}-agw')
var appGatewayDomainNameLabel = toLower('${ProjectName}-${Environment}-public-gateway')
var appGatewayWafSettings = AppGatewayWafSettings
var initServicesFqdn = [
  '${webAppsPrefix}-python-1.${ (Environment=='Production') ? 'appserviceenvironment.net':'azurewebsites.net'}'
  '${webAppsPrefix}-node-1.${ (Environment=='Production') ? 'appserviceenvironment.net':'azurewebsites.net'}'
]
module appGatewayPublicIpModule './Modules/publicIp.bicep' = {
  scope: projectRg
  name: 'agwPipDeploy'
  params: {
    pipName: appGatewayDomainNameLabel
    location: Location
    pipTags: DefaultTags
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
    dnsLabel: appGatewayDomainNameLabel
  }
}
module applicationGateway 'Modules/applicationGateway.bicep' = { 
  scope: projectRg
  name: 'appGatewayDeploy'
  params:{
    applicationGatewayName: applicationGatewayName
    applicationGatewayTags: DefaultTags
    subnetId: virtualNetworkModule.outputs.network.virtualNetwork.subnets[0].id
    location: Location
    wafSettings: appGatewayWafSettings
    initServicesFqdn: initServicesFqdn
    pfxFile: loadFileAsBase64(pfxFilePath) //This will be provided via a Project Pipeline
    pfxPassword: PfxPassword
    publicIPAddress: {
      id: appGatewayPublicIpModule.outputs.id
      ipAddress: appGatewayPublicIpModule.outputs.ipAddress
      fqdn: appGatewayPublicIpModule.outputs.fqdn
    }
  }
}

// Initiate Storage Account - SFTP Server
var storageAccountName = {
  name: toLower('${ProjectName}${Environment}sa')
}
var storageAccountConfig = union(storageAccountName,StorageAccountConfig)
module storageAccountModule './Modules/storageAccount.bicep' = {
  scope: projectRg
  name: 'storageAccountDeploy'
  params: {
    storageAccount: storageAccountConfig
    storageAccountTags: DefaultTags
    sftpUser: FtpConfig.username
    sftpPassword: FtpConfig.password
    sftpSubnnetId: virtualNetworkModule.outputs.network.virtualNetwork.subnets[4].id
    virtualNetworkRules: [
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[0].id
        action: 'Allow'
        state: 'Succeeded'
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[1].id
        action: 'Allow'
        state: 'Succeeded'
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[2].id
        action: 'Allow'
        state: 'Succeeded'
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[3].id
        action: 'Allow'
        state: 'Succeeded'
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[4].id
        action: 'Allow'
        state: 'Succeeded'
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[5].id
        action: 'Allow'
        state: 'Succeeded'
      }
    ]
  }
}

// Initiate App Service Plan based on Environment Type
var appServiceEnvName = toLower('${ProjectName}-${Environment}-${uniqueString(subscription().subscriptionId)}')
var appServicePlanName = toLower('${appServiceEnvName}-asp')
var appServiceVnet = {
  vnetId: virtualNetworkModule.outputs.network.virtualNetwork.id
  subnetId: virtualNetworkModule.outputs.network.virtualNetwork.subnets[2].id
}
var appServicePlanSizes = AppServicePlanSizes

module appServiceModule './Modules/appService.bicep' = {
  scope: projectRg
  name: 'appServiceDeploy'
  params: {
    appServiceEnvironment: Environment
    appServiceEnvName: appServiceEnvName
    appServicePlanName: appServicePlanName
    appServiceTags: DefaultTags
    appServiceVnet: appServiceVnet
    location: Location
    appServiceConfig: appServicePlanSizes[Environment]
  }
}


// The Collection of Sample Web Apps are declared inside this module
var webAppsPrefix = toLower('${ProjectName}-${Environment}-internal-webapp')
module webApps './Modules/Application/WebApps/webApps.bicep' = {
  scope: projectRg
  name: 'webAppsDeploy'
  params: {
    webAppsPrefix: webAppsPrefix
    webAppsTags: DefaultTags
    appServicePlanId: appServiceModule.outputs.servicePlanId
    subnetId: [
      virtualNetworkModule.outputs.network.virtualNetwork.subnets[0].id
      virtualNetworkModule.outputs.network.virtualNetwork.subnets[1].id
      virtualNetworkModule.outputs.network.virtualNetwork.subnets[2].id
      virtualNetworkModule.outputs.network.virtualNetwork.subnets[3].id
      virtualNetworkModule.outputs.network.virtualNetwork.subnets[4].id
      virtualNetworkModule.outputs.network.virtualNetwork.subnets[5].id
    ]
    // adminIp: AdminIp
    location: Location
  }
}

// Create Private Endpoint for Database Subnet
module privateEndpoint './Modules/privateEndpoint.bicep' = {
  scope: projectRg
  name: 'privateEndpointDeploy'
  params: {
    privateEndpointTags: DefaultTags
    location: Location
    virtualNetwork: {
      name: virtualNetworkModule.outputs.network.virtualNetwork.name
      subnet: {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[3].id //Database subnet
        addressPrefix: virtualNetworkModule.outputs.network.virtualNetwork.subnets[3].properties.addressPrefix //Database subnet
      } 
    }
    connections: [
      {
        id: guid(cosmosDbModule.outputs.cosmos.databaseAccountName)
        name: guid(cosmosDbModule.outputs.cosmos.databaseAccountName)
        properties: {
          groupIds: [
            'MongoDB'
          ]
          privateLinkServiceId: cosmosDbModule.outputs.cosmos.databaseAccountId
        }
      }
    ]
  }
}

// Create CosmosDB API for MongoDB
var cosmosDbAccountName = toLower('${ProjectName}-${Environment}-account')
var cosmosDbDatabseName = toLower('${ProjectName}-${Environment}-mongodb')
var primaryRegion = Location
var secondaryRegion = 'Eastasia'
var cosmosDbInitCollection1Name = 'TempCollection1'
var cosmosDbInitCollection2Name = 'TempCollection2'
var serverVersion = '4.0'
var defaultConsistencyLevel = 'Session'
var maxStalenessPrefix = 100000
var maxIntervalInSeconds = 300
var autoscaleMaxThroughput = 4000
var cosmosDbAllowedIpAddresses = union(AzurePortalIpAddresses,[
    {
        ipAddressOrRange: firewallPublicIpModule.outputs.ipAddress
    }
    {
        ipAddressOrRange: appGatewayPublicIpModule.outputs.ipAddress
    }
  ])
module cosmosDbModule './Modules/cosmosDb.bicep' = {
  scope: projectRg
  name: 'cosmosDbDeploy'
  params: {
    cosmosDbAccountName: cosmosDbAccountName
    cosmosDbDatabseName: cosmosDbDatabseName
    location: Location
    primaryRegion: primaryRegion
    secondaryRegion: secondaryRegion
    cosmosDbTags: DefaultTags
    cosmosDbInitCollection1Name: cosmosDbInitCollection1Name
    cosmosDbInitCollection2Name: cosmosDbInitCollection2Name
    serverVersion: serverVersion
    defaultConsistencyLevel: defaultConsistencyLevel
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
    autoscaleMaxThroughput: autoscaleMaxThroughput
    locations: [
      {
        locationName: primaryRegion
        failoverPriority: 0
        isZoneRedundant: false
      }
      // { // Limitation due to free account
      //   locationName: secondaryRegion
      //   failoverPriority: 0
      //   isZoneRedundant: false
      // }
    ]
    cosmosDbIpRules: cosmosDbAllowedIpAddresses
    virtualNetworkRules: [
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[0].id
        ignoreMissingVNetServiceEndpoint: true
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[1].id
        ignoreMissingVNetServiceEndpoint: true
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[2].id
        ignoreMissingVNetServiceEndpoint: true
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[3].id
        ignoreMissingVNetServiceEndpoint: true
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[4].id
        ignoreMissingVNetServiceEndpoint: true
      }
      {
        id: virtualNetworkModule.outputs.network.virtualNetwork.subnets[5].id
        ignoreMissingVNetServiceEndpoint: true
      }
    ]
  }  
}

// Create Azure Firewall - Backend Access such as SFTP Server and MongoDB
var firewallName = toLower('${ProjectName}-fw')
var natRuleCollection = [
  {
    name: 'sftp-nat-rules'
    properties: {
      priority: '1000'
      action: {
        type: 'Dnat'
      }
      rules: [
        {
          name: 'sftp-inbound-rule'
          description: 'Allow SFTP Connection from source to container group SFTP Container IP'
          sourceAddresses: [
            AdminIp
          ]
          destinationAddresses: [
            firewallPublicIpModule.outputs.ipAddress
          ]
          destinationPorts: [
            '2222' //default port 22 is prone to attacks 
          ]
          protocols: [
            'TCP'
          ]
          translatedAddress: storageAccountModule.outputs.ftp.sftpIp
          translatedPort: 22
        }
      ]
    }
  }
  {
    name: 'mongodb-nat-rules'
    properties: {
      priority: '1100'
      action: {
        type: 'Dnat'
      }
      rules: [
        {
          name: 'mongodb-inbound-rule'
          description: 'Allow MongoDB Connection via Public Firewall.'
          sourceAddresses: [
            AdminIp
          ]
          destinationAddresses: [
            firewallPublicIpModule.outputs.ipAddress
          ]
          destinationPorts: [
            '10255' //default port by MS 
          ]
          protocols: [
            'TCP'
          ]
          translatedAddress: privateEndpoint.outputs.privateendpoint.primaryPrivateIp
          translatedPort: 10255
        }
      ]
    }
  }
]
module firewallPublicIpModule './Modules/publicIp.bicep' = {
  scope: projectRg
  name: 'firewallPipDeploy'
  params: {
    pipName: '${ProjectName}-${Environment}-fw-backend'
    location: Location
    pipTags: DefaultTags
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
    dnsLabel: toLower('${ProjectName}-${Environment}-fw-backend')
  }
}

module firewallModule './Modules/firewall.bicep' = {
  scope: projectRg
  name: 'firewallDeploy'
  params: {
    firewallName: firewallName
    applicationRuleCollection: []
    natRuleCollection: natRuleCollection
    networkRuleCollection: []
    firewallSubnetId: virtualNetworkModule.outputs.network.virtualNetwork.subnets[5].id
    firewallTags: DefaultTags
    firewallPublicIp: {
      id: firewallPublicIpModule.outputs.id
      ipAddress: firewallPublicIpModule.outputs.ipAddress
    }    
  }
}
