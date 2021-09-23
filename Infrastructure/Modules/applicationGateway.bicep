@minLength(3)
@maxLength(20)
@description('Name of the project - all lowercase')
param applicationGatewayName string
@description('Tags to be embedded to all resources')
param applicationGatewayTags object
@description('Subnet ID where to put the AppGateWay')
param subnetId string
@description('WAF Settings')
param wafSettings object
@description('Regional location to provision the resources')
param location string = resourceGroup().location
@description('Base64 String of PFX File')
@secure()
param pfxFile string
@description('PFX File Password')
@secure()
param pfxPassword string
@description('Initial backend app service')
param initServicesFqdn array
@description('Public IP resource')
param publicIPAddress object
// @description('Host Names for Multisite')
// param hostNames array 



resource applicationGateway 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: applicationGatewayName
  location: location
  tags: applicationGatewayTags
  properties: {
    enableHttp2: true
    sslCertificates: [
      {
        name: 'frontend-ssl-cert'
        properties: {
          data: pfxFile
          password: pfxPassword
        }
      }
    ]
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      maxCapacity: 2
      minCapacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'gateway-ip-config-1'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [ //You can put more frontend IPs here if needed
      {
        name: 'frontend-ip-config-pub'
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'frontend-port-80'
        properties: {
          port: 80
        }
      }
      {
        name: 'frontend-port-443'
        properties: {
          port: 443
        }
      }
    ] 
    httpListeners: [
      {
        id: 'frontend-listener-80'
        name: 'frontend-listener-80'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'frontend-ip-config-pub')

          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'frontend-port-80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
      {
        id: 'frontend-listener-443'
        name: 'frontend-listener-443'
        properties: {
          hostNames: [
            publicIPAddress.fqdn
          ]
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'frontend-ip-config-pub')

          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'frontend-port-443')
          }
          protocol: 'Https'
          sslCertificate: { 
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', applicationGatewayName, 'frontend-ssl-cert')

          }
          requireServerNameIndication: false
        }
      }
    ]

    backendHttpSettingsCollection: [
      {
        id: 'backend-http-setting-ssl-terminated'
        name: 'backend-http-setting-ssl-terminated'
        properties: {
          port: 80 //Use 443 if you need End to end SSL, 80 for SSL Terminated connection. For demo purposes, both frontend80 and frontend443 will translate to backend80
          probeEnabled: false
          protocol: 'Http'
          requestTimeout: 60
          pickHostNameFromBackendAddress: true //Important if you are using PathBasedRouting
          path: '/' //Important if you are using PathBasedRouting 
        }
      }
    ]
    backendAddressPools: [
      {
        id: 'backend-pool-1'
        name: 'backend-pool-1'
        properties: {
          backendAddresses: [
            {
              fqdn: initServicesFqdn[0]
            }
          ] // Blank Backend Addresses because this is a cleanslate AGW for ASP/ASE
        }
      }
      {
        id: 'backend-pool-2'
        name: 'backend-pool-2'
        properties: {
          backendAddresses: [
            {
              fqdn: initServicesFqdn[1]
            }
          ] // Blank Backend Addresses because this is a cleanslate AGW for ASP/ASE
        }
      }
    ]  
    redirectConfigurations: [
      {
        id: 'frontend80-to-frontend443'
        name: 'frontend80-to-frontend443'
        properties: {
          includePath: true
          includeQueryString: true
          redirectType: 'Permanent'
          requestRoutingRules: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/requestRoutingRules', applicationGatewayName, 'frontend80-to-backend80-rule')
            }
          ]
          targetListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'frontend-listener-443')
          }
        }
      }
    ]
    urlPathMaps: [
      {
        id: 'frontend-url-path-map-443'
        name: 'frontend-url-path-map-443'
        properties: {
          defaultBackendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'backend-pool-1')
          }
          defaultBackendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'backend-http-setting-ssl-terminated')
          }
          pathRules: [
            {
              id: 'python-app-path-1'
              name: 'python-app-path'
              properties: {
                paths: [
                  '/python/*'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'backend-pool-1')
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'backend-http-setting-ssl-terminated')
                }
              }
            }
            {
              id: 'nonde-app-path-1'
              name: 'node-app-path'
              properties: {
                paths: [
                  '/node/*'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'backend-pool-2')
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'backend-http-setting-ssl-terminated')
                }
              }
            }
          ]
        }
      }
    ]

    requestRoutingRules: [ //This will send data from frontend port to backend translated port
      {
        name: 'frontend80-to-backend80-rule'
        properties: {
          priority: 200
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'frontend-listener-80')
          }
          redirectConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', applicationGatewayName, 'frontend80-to-frontend443')
          }
        }
      }
      {
        name: 'frontend443path-to-backend80-rule'
        properties: {
          priority: 100
          ruleType: 'PathBasedRouting'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'frontend-listener-443')
          }
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps', applicationGatewayName, 'frontend-url-path-map-443')
          }
        }
      }
    ]
    sslPolicy: {
      policyType: 'Custom'
      minProtocolVersion: 'TLSv1_1'
      cipherSuites: [
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA'
        'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA'
        'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA'
        'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA'
        'TLS_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_RSA_WITH_AES_128_GCM_SHA256'
        'TLS_RSA_WITH_AES_256_CBC_SHA256'
        'TLS_RSA_WITH_AES_128_CBC_SHA256'
        'TLS_RSA_WITH_AES_256_CBC_SHA'
        'TLS_RSA_WITH_AES_128_CBC_SHA'
      ]
    }
    webApplicationFirewallConfiguration: wafSettings
  }
}
