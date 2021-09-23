@minLength(3)
@maxLength(20)
@description('Name of the project - all lowercase')
param virtualNetworkName string

@description('Tags to be embedded to all resources')
param virtualNetworkTags object

@description('Virtual Network Settings and Cofiguration')
param virtualNetworkConfig object

@description('App Service Environment private URL')
param virtualNetworDnsZoneName string

@description('Regional Location')
param location string = resourceGroup().location

@description('IP Address range of the Client')
param clientIp string = ''

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'app-gateway'
  location: location
  properties: {
    securityRules: [
      {
        name: 'agw-default-rule'
        properties: {
          description: 'Allow Client IP.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: clientIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: virtualNetworkName
  location: location
  tags: virtualNetworkTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkConfig.CidrVnet
      ]
    }
    subnets: [
      {
        name: 'Frontend'
        properties: {
          addressPrefix: virtualNetworkConfig.CidrAppGatewaySubnet
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.Web'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
      {
        name: 'Management'
        properties: {
          addressPrefix: virtualNetworkConfig.CidrPublicSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Web'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
      {
        name: 'Application'
        properties: {
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          addressPrefix: virtualNetworkConfig.CidrAppSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Web'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
          delegations: [
            {
              name: 'app-service-plan'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'Database'
        properties: {
          addressPrefix: virtualNetworkConfig.CidrDatabaseSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Web'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
      {
        name: 'Containers'
        properties: {
          addressPrefix: virtualNetworkConfig.CidrContainersSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Web'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
          delegations: [
            {
              name: 'coontainer-group'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: virtualNetworkConfig.CidrFirewallSubnet
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Web'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: virtualNetworDnsZoneName
  location: 'global'
  tags: virtualNetworkTags
  properties: {}
  resource virtualNetworkLink 'virtualNetworkLinks@2020-06-01' = {
    name: virtualNetworDnsZoneName
    location: 'global'
    tags: virtualNetworkTags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}



output network object = {
  virtualNetwork: {
    id: virtualNetwork.id
    name: virtualNetwork.name
    subnets: virtualNetwork.properties.subnets
  }
  privateDnsZone: {
    id: privateDnsZone.id
    properties: privateDnsZone.properties
  }
}
