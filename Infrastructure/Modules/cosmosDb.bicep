@description('Account Name')
param cosmosDbAccountName string
@description('DB Name')
param cosmosDbDatabseName string
@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location

@description('The primary replica region for the Cosmos DB account.')
param primaryRegion string

@description('The secondary replica region for the Cosmos DB account.')
param secondaryRegion string

@description('Resource Tags')
param cosmosDbTags object

@description('The name for the first Mongo DB collection')
param cosmosDbInitCollection1Name string

@description('The name for the second Mongo DB collection')
param cosmosDbInitCollection2Name string

@description('Specifies the MongoDB server version to use.')
@allowed([
  '3.2'
  '3.6'
  '4.0'
])
param serverVersion string = '4.0'


@description('The default consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'
@description('Max stale requests. Required for BoundedStaleness. Valid ranges, Single Region: 10 to 1000000. Multi Region: 100000 to 1000000.')
@minValue(10)
@maxValue(2147483647)
param maxStalenessPrefix int = 100000
@description('Max lag time (seconds). Required for BoundedStaleness. Valid ranges, Single Region: 5 to 84600. Multi Region: 300 to 86400.')
@minValue(5)
@maxValue(86400)
param maxIntervalInSeconds int = 300
@description('Maximum throughput when using Autoscale Throughput Policy for the Database')
@minValue(4000)
@maxValue(1000000)
param autoscaleMaxThroughput int = 1000
param locations array = [
  {
    locationName: primaryRegion
    failoverPriority: 0
    isZoneRedundant: false
  }
  {
    locationName: secondaryRegion
    failoverPriority: 1
    isZoneRedundant: false
  }
]
@description('Virtual Network Rule of the CosmosDB Account')
param virtualNetworkRules array
@description('IP Range that will be allowed to access CosmosDB, this can be useful if you need to access data via Azure Portal')
param cosmosDbIpRules array = []

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}

resource cosmosDbAccountNameResource 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'MongoDB'
  tags: cosmosDbTags
  properties: {
    isVirtualNetworkFilterEnabled: true
    networkAclBypass: 'AzureServices'
    publicNetworkAccess: 'Disabled'
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    locations: locations
    databaseAccountOfferType: 'Standard'
    apiProperties: {
      serverVersion: serverVersion
    }
    virtualNetworkRules: virtualNetworkRules
    ipRules: cosmosDbIpRules
  }
}

resource cosmosDbDatabaseNameResource 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2021-04-15' = {
  parent: cosmosDbAccountNameResource
  name: cosmosDbDatabseName
  properties: {
    resource: {
      id: cosmosDbDatabseName
    }
    options: {
      autoscaleSettings: {
        maxThroughput: autoscaleMaxThroughput
      }
    }
  }
}

resource cosmosDbCollection1 'Microsoft.DocumentDb/databaseAccounts/mongodbDatabases/collections@2021-04-15' = {
  parent: cosmosDbDatabaseNameResource
  name: cosmosDbInitCollection1Name
  properties: {
    resource: {
      id: cosmosDbInitCollection1Name
      shardKey: {
        user_id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              '$**'
            ]
          }
        }
        {
          key: {
            keys: [
              'user_id'
              'user_address'
            ]
          }
          options: {
            unique: true
          }
        }
        {
          key: {
            keys: [
              '_ts'
            ]
          }
        }
      ]
    }
  }
}


resource cosmosDbCollection2 'Microsoft.DocumentDb/databaseAccounts/mongodbDatabases/collections@2021-04-15' = {
  parent: cosmosDbDatabaseNameResource
  name: cosmosDbInitCollection2Name
  properties: {
    resource: {
      id: cosmosDbInitCollection2Name
      shardKey: {
        company_id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              '$**'
            ]
          }
        }
        {
          key: {
            keys: [
              'company_id'
              'company_address'
            ]
          }
          options: {
            unique: true
          }
        }
        {
          key: {
            keys: [
              '_ts'
            ]
          }
        }
      ]
    }
  }
}

output cosmos object = {
  databaseAccountId: cosmosDbAccountNameResource.id
  databaseAccountName: cosmosDbAccountNameResource.name
  documentEndpoint: cosmosDbAccountNameResource.properties.documentEndpoint
}
