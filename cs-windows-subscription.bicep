targetScope = 'subscription' // or 'subscription' depending on your needs

@description('Policy assignment name')
param policyAssignmentName string = 'CS-Deploy-Falcon'

@description('Policy definition name')
param policyDefinitionName string = 'CS-Falcon-Windows'

@description('CrowdStrike Member CID')
param FalconCid string

@description('Install parameters for CrowdStrike Falcon')
param installParams string = '/install /quiet /noreboot'

@description('Effect for the policy assignment (DeployIfNotExists, AuditIfNotExists, Disabled)')
@allowed([
  'DeployIfNotExists'
  'AuditIfNotExists'
  'Disabled'
])
param policyEffect string = 'DeployIfNotExists'

@description('Location for policy assignment')
param location string

@secure()
param FalconClientId string
@secure()
param FalconClientSecret string

// Virtual Machine Contributor role definition ID
var vmRoleDefinitionId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'

// Create policy definition
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {
  name: policyDefinitionName
  properties: {
    displayName: 'Deploy CrowdStrike Falcon agent on Windows VMs'
    description: 'This policy deploys CrowdStrike Falcon agent on Windows VMs if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Security'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      FalconClientId: {
        type: 'String'
        metadata: {
          displayName: 'CrowdStrike Client ID'
          description: 'CrowdStrike API Client ID'
        }
      }
      FalconClientSecret: {
        type: 'String'  // Azure Policy doesn't support SecureString
        metadata: {
          displayName: 'CrowdStrike Client Secret'
          description: 'CrowdStrike API Client Secret'
        }
      }
      FalconCid: {
        type: 'String'
        metadata: {
          displayName: 'CrowdStrike Member CID'
          description: 'CrowdStrike Customer ID (CID)'
        }
      }
      installParams: {
        type: 'String'
        metadata: {
          displayName: 'Installation Parameters'
          description: 'Parameters for Falcon sensor installation'
        }
        defaultValue: '/install /quiet /noreboot'
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/osProfile.windowsConfiguration'
            exists: 'true'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Compute/virtualMachines/extensions'
          roleDefinitionIds: [
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
          ]
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'CustomScriptExtension'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Microsoft.Compute'
              }
              {
                field: 'name'
                like: 'CrowdStrikeFalconInstall*'
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  vmName: { type: 'string' }
                  location: { type: 'string' }
                  FalconClientId: { type: 'string' }
                  FalconClientSecret: { type: 'securestring' }
                  FalconCid: { type: 'string' }
                  installParams: { type: 'string' }
                }
                resources: [
                  {
                    name: '[concat(parameters(\'vmName\'), \'/CrowdStrikeFalconInstall\')]'
                    type: 'Microsoft.Compute/virtualMachines/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2021-11-01'
                    properties: {
                      publisher: 'Microsoft.Compute'
                      type: 'CustomScriptExtension'
                      typeHandlerVersion: '1.10'
                      autoUpgradeMinorVersion: true
                      settings: {
                        fileUris: [
                          'https://raw.githubusercontent.com/CrowdStrike/falcon-scripts/main/powershell/install/falcon_windows_install.ps1'
                        ]
                      }
                      protectedSettings: {
                        commandToExecute: '[concat(\'powershell.exe -ExecutionPolicy Unrestricted -File falcon_windows_install.ps1 -FalconClientId "\', parameters(\'FalconClientId\'), \'" -FalconClientSecret "\', parameters(\'FalconClientSecret\'), \'" -FalconCid "\', parameters(\'FalconCid\'), \'" -InstallParams "\', parameters(\'installParams\'), \'"\')]'
                      }
                    }
                  }
                ]
              }
              parameters: {
                vmName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
                FalconClientId: {
                  value: '[parameters(\'FalconClientId\')]'
                }
                FalconClientSecret: {
                  value: '[parameters(\'FalconClientSecret\')]'
                }
                FalconCid: {
                  value: '[parameters(\'FalconCid\')]'
                }
                installParams: {
                  value: '[parameters(\'installParams\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

// Create policy assignment with managed identity
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: policyDefinition.id
    displayName: 'Deploy CrowdStrike Falcon agent on Windows VMs'
    description: 'This policy ensures CrowdStrike Falcon agent is installed on all Windows VMs'
    parameters: {
      effect: {
        value: policyEffect
      }
      FalconClientId: {
        value: FalconClientId
      }
      FalconClientSecret: {
        value: FalconClientSecret
      }
      FalconCid: {
        value: FalconCid
      }
      installParams: {
        value: installParams
      }
    }
  }
}

// Create role assignment for the policy's managed identity
resource vmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignment.id, vmRoleDefinitionId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId))
  properties: {
    principalId: policyAssignment.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.id
output policyPrincipalId string = policyAssignment.identity.principalId
