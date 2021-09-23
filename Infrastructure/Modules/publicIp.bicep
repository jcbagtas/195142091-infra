param pipName string
param location string = resourceGroup().location
param pipTags object
param skuName string = 'Standard'
param publicIPAllocationMethod string = 'Static'
param dnsLabel string = ''
var defaultTags = {
  resource: pipName
}
var tags = union(pipTags, defaultTags)
resource publicIp 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${pipName}-ip'
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
  }
}

output ipAddress string = publicIp.properties.ipAddress
output id string = publicIp.id
output fqdn string = publicIp.properties.dnsSettings.fqdn
