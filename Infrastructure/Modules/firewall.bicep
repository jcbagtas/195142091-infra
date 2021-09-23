@description('Firewall Name')
param firewallName string
@description('Regional location')
param location string = resourceGroup().location
@description('App Rule Collection - FQDNs')
param applicationRuleCollection array
@description('NAT Rule Collection - Inbound')
param natRuleCollection array
@description('Network Rule Collection')
param networkRuleCollection array = []
@description('Resource Tags')
param firewallTags object
@description('AzureFirewallSubnet ID')
param firewallSubnetId string
@description('Public IP resource')
param firewallPublicIp object

var defaultNetworkRuleCollection = []
var defaultApplicationRuleCollection = [
  {
    name: 'default-app-rule'
    properties: {
      priority: '1000'
      action: {
        type: 'Allow'
      }
      rules: [
        {
          name: 'default'
          description: 'default rules that allows access to app service and azurewebsites'
          sourceAddresses: [
            '*'
          ]
          protocols: [
            {
              protocolType: 'Http'
              port: 80
            }
            {
              protocolType: 'Https'
              port: 443
            }
          ]
          targetFqdns: [
            '*.appserviceenvironment.net'
            '*.azurewebsites.net'
          ]
        }
      ]
    }
  }
]

var defaultNatRuleCollection = []



var applicationRuleCollectionCombined = union(applicationRuleCollection, defaultApplicationRuleCollection)
var natRuleCollectionCombined = union(natRuleCollection, defaultNatRuleCollection)
var networkRuleCollectionCombined = union(networkRuleCollection, defaultNetworkRuleCollection)

resource firewall 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: firewallName
  location: location
  tags: firewallTags
  properties: {
    threatIntelMode: 'Alert'
    applicationRuleCollections: applicationRuleCollectionCombined
    natRuleCollections: natRuleCollectionCombined
    networkRuleCollections: networkRuleCollectionCombined
    ipConfigurations: [
      {
        name: '${firewallName}-default'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
  }
}

