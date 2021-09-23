@description('Storage Account Details')
param storageAccount object
@description('Regional location of the resources')
param location string = resourceGroup().location
@description('Tags of the Resources')
param storageAccountTags object
@description('Username for SFTP Server')
param sftpUser string
@description('Password for SFTP Server')
@secure()
param sftpPassword string
@description('Subnet ID to where the SFTP Server be created')
param sftpSubnnetId string
@description('VNet Rules comprised of Subnet IDs that are allowed to access this Storage Account')
param virtualNetworkRules array

resource storageAccountResource 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccount.name
  location: location
  tags: storageAccountTags
  kind: storageAccount.kind
  sku: {
    name: storageAccount.sku
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: virtualNetworkRules
      ipRules: []
      defaultAction: 'Allow'
    }
    routingPreference: {
      publishInternetEndpoints: false
      publishMicrosoftEndpoints: true
      routingChoice: 'MicrosoftRouting'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      } 
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
  parent: storageAccountResource
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-04-01' = {
  parent: storageAccountResource
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2021-04-01' = {
  parent: storageAccountResource
  name: 'default'
}
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2021-04-01' = {
  parent: storageAccountResource
  name: 'default'
}
resource fileShareResource 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  parent: fileService
  name: 'default'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5120
    enabledProtocols: 'SMB'
  }
}
var sftpContainerName = '${storageAccount.name}-sftp'
var sftpVolumeName = '${storageAccount.name}-sftp-volume'
var sftpContainerGroupName = '${storageAccount.name}-sftp-group'
var sftpContainerImage = 'atmoz/sftp:debian'
var sftpEnvVariable = '${sftpUser}:${sftpPassword}:1001'


// SFTP On Demand Container Group accessible via Firewall
resource sftpNetworkProfile 'Microsoft.Network/networkProfiles@2021-02-01' = {
  name: '${sftpContainerGroupName}-network-profile'
  location: location
  tags: storageAccountTags
  properties: {
    containerNetworkInterfaceConfigurations: [
      {
        id: '${sftpContainerGroupName}-nic'
        name: '${sftpContainerGroupName}-nic'
        properties: {
          ipConfigurations: [
            {
              name: sftpContainerGroupName
              properties: {
                subnet: {
                  id: sftpSubnnetId
                }
              }
            }
          ]
        }
      }
    ]
  }
}

resource sftpContainerGroup 'Microsoft.ContainerInstance/containerGroups@2021-03-01' = {
  name: sftpContainerGroupName
  location: location
  tags: storageAccountTags
  properties: {
    osType: 'Linux'
    networkProfile: {
      id: sftpNetworkProfile.id
    }
    restartPolicy: 'OnFailure'
    volumes: [
      {
        name: sftpVolumeName
        azureFile: {
          readOnly: false
          shareName: fileShareResource.name
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccountResource.listKeys().keys[0].value
          
        }
      }
    ]
    containers: [
      {
        name: sftpContainerName
        properties: {
          image: sftpContainerImage
          environmentVariables: [
            {
              name: 'SFTP_USERS'
              value: sftpEnvVariable
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          ports: [
            {
              port: 22
              protocol: 'TCP'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/home/${sftpUser}/upload'
              name: sftpVolumeName
              readOnly: false
            }
          ]
        }
      }
    ]
  }
}

output ftp object = {
  id: storageAccountResource.id
  name: storageAccountResource.name
  apiVersion: storageAccountResource.apiVersion
  sftpIp: sftpContainerGroup.properties.ipAddress.ip
  sftpContainerId: sftpContainerGroup.id
}

