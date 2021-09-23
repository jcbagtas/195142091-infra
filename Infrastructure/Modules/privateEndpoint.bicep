
@description('Virtual Network Object containing name and subnet id where the endpoint will be created')
param virtualNetwork object
@description('Regional location of the resources')
param location string = resourceGroup().location
@description('Array of resources connected to the private endpoint')
param connections array
@description('Tags for all resources')
param privateEndpointTags object


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: toLower('${virtualNetwork.name}-private-endpoint')
  location: location
  tags: privateEndpointTags
  properties: {
    privateLinkServiceConnections: connections
    subnet: {
      id: virtualNetwork.subnet.id
      properties: {
        addressPrefix: virtualNetwork.subnet.addressPrefix
        delegations: []
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }
  }
}

output privateendpoint object = {
  primaryPrivateIp: privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
}
