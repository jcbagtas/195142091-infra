@description('Web Apps will have this prefix')
param webAppsPrefix string
@description('Regional location of the apps')
param location string
@description('Tags of the apps')
param webAppsTags object
@description('ID of the App Service Plan')
param appServicePlanId string
@description('IP of admin')
param adminIp string = ''
@description('Subnet ID from a virtual network')
param subnetId array

resource pythonWebApp 'Microsoft.Web/sites@2021-01-01' = {
  name: '${webAppsPrefix}-python-1'
  location: location
  kind: 'app'
  tags: webAppsTags
  properties: {
    serverFarmId: appServicePlanId
    virtualNetworkSubnetId: subnetId[2]
    httpsOnly: false //important for non-ASE deployment, to enable SSL Termination after AGW
    siteConfig: {
      appSettings: []
      linuxFxVersion: 'PYTHON|3.6'
      alwaysOn: true
      vnetRouteAllEnabled: true
      http20Enabled: true
    }
  }
}


resource nodeWebApp 'Microsoft.Web/sites@2021-01-01' = {
  name: '${webAppsPrefix}-node-1'
  location: location
  kind: 'app'
  tags: webAppsTags
  properties: {
    serverFarmId: appServicePlanId
    virtualNetworkSubnetId: subnetId[2]
    httpsOnly: false //important for non-ASE deployment, to enable SSL Termination after AGW
    siteConfig: {
      appSettings: []
      linuxFxVersion: 'NODE|12.9'
      alwaysOn: true
      vnetRouteAllEnabled: true
      http20Enabled: true
    }
  }
}

var adminIpRestrictionEntry = [
  {
    ipAddress: adminIp
    action: 'Allow'
    priority: 101
    name: 'AdminIp'
    description: 'Admin IP'
    headers: {}
  }
]

var subnetRestrictions = [
  {
    vnetSubnetResourceId: subnetId[0]
    action: 'Allow'
    tag: 'Default'
    priority: 100
    name: 'Default'
    description: 'Frontend Subnet'
    headers: {}
  }
  {
    vnetSubnetResourceId: subnetId[1]
    action: 'Allow'
    tag: 'Default'
    priority: 200
    name: 'Default'
    description: 'Management Subnet'
    headers: {}
  }
  {
    vnetSubnetResourceId: subnetId[2]
    action: 'Allow'
    tag: 'Default'
    priority: 300
    name: 'Default'
    description: 'Management Subnet'
    headers: {}
  }
  {
    vnetSubnetResourceId: subnetId[3]
    action: 'Allow'
    tag: 'Default'
    priority: 400
    name: 'Default'
    description: 'Database Subnet'
    headers: {}
  }
]
var ipSecurityRestrictions = (adminIp!='') ? union(subnetRestrictions, adminIpRestrictionEntry) : subnetRestrictions



resource pythonWebAppNetworkConfig  'Microsoft.Web/sites/config@2020-06-01' = {
  parent: pythonWebApp
  name: 'web'
  properties: {
    vnetRouteAllEnabled: true
    ipSecurityRestrictions: ipSecurityRestrictions
  }
}
resource nodeWebAppNetworkConfig  'Microsoft.Web/sites/config@2020-06-01' = {
  parent: nodeWebApp
  name: 'web'
  properties: {
    vnetRouteAllEnabled: true
    ipSecurityRestrictions: ipSecurityRestrictions
  }
}
