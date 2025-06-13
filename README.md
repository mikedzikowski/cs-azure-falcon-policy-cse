# CrowdStrike Falcon Deployment via Azure Policy (Windows and Linux)

This Bicep template deploys CrowdStrike Falcon agent to Windows and Linux virtual machines across your Azure environment using Azure Policy and a Custom Script Extension. This solution is a community solution not directly supported by Crowdstrike.

## Overview

The template creates a custom Azure Policy definition that automatically installs the CrowdStrike Falcon agent on Windows and Linux VMs. It operates at either management group or subscription scope and creates all necessary resources for deployment including policy definitions, assignments, and role assignments.

## Prerequisites

- Azure subscription or management group access with permissions to create policies
- CrowdStrike Falcon API credentials (Client ID and Client Secret)
- CrowdStrike Customer ID (CID)

Ensure the following API scopes are enabled:

- Install:
  - **Sensor Download** [read]
  - **Sensor update policies** [read]
- Uninstall:
  - **Host** [write]
  - **Sensor update policies** [write]

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `policyAssignmentName` | Name for the policy assignment | `CS-Deploy-Falcon` |
| `policyDefinitionName` | Name for the policy definition | `CS-Falcon-Windows` |
| `FalconCid` | CrowdStrike Customer ID (CID) | (Required) |
| `installParams` | Falcon agent installation parameters | `/install /quiet /noreboot` |
| `policyEffect` | Policy enforcement effect | `DeployIfNotExists` |
| `location` | Azure region for policy resources | (Required) |
| `FalconClientId` | CrowdStrike API Client ID (secure) | (Required) |
| `FalconClientSecret` | CrowdStrike API Client Secret (secure) | (Required) |

## Deployment

### Windows Policy  - Management Group Scope

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fcs-windows.json/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fui.json)

### Linux Policy - Management Group Scope

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fcs-linux.json/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fui.json)

### Windows Policy  - Subscription Scope

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fcs-windows-subscription.json/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fui-subscription.json)

### Linux Policy - Subscription Scope

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fcs-linux-subscription.json/https%3A%2F%2Fraw.githubusercontent.com%2Fmikedzikowski%2Fcs-azure-falcon-policy-cse%2Fmain%2Fui-subscription.json)

### Azure CLI

```powershell
# Login to Azure
az login

# Deploy at management group scope
az deployment mg create \
  --name falcon-policy-deployment \
  --location eastus \
  --management-group-id YOUR_MGMT_GROUP_ID \
  --template-file cse-windows.bicep \
  --parameters FalconCid=YOUR_CID \
  --parameters FalconClientId=YOUR_CLIENT_ID \
  --parameters FalconClientSecret=YOUR_CLIENT_SECRET \
  --parameters location=eastus
```

### Azure PowerShell

```powershell
# Login to Azure
Connect-AzAccount

# Deploy at subscription scope
New-AzDeployment -Name falcon-policy-deployment `
  -Location eastus `
  -TemplateFile .\cse-windows.bicep `
  -FalconCid YOUR_CID `
  -FalconClientId YOUR_CLIENT_ID `
  -FalconClientSecret YOUR_CLIENT_SECRET `
  -location eastus

# Deploy at management group scope
New-AzManagementGroupDeployment -Name falcon-policy-deployment `
  -Location eastus `
  -ManagementGroupId YOUR_MGMT_GROUP_ID `
  -TemplateFile .\cse-windows.bicep `
  -FalconCid YOUR_CID `
  -FalconClientId YOUR_CLIENT_ID `
  -FalconClientSecret YOUR_CLIENT_SECRET `
  -location eastus
```

## How It Works

1. The template creates a custom policy definition that identifies Windows VMs without the Falcon agent installed
2. It then deploys a custom script extension that downloads and installs the Falcon agent using credentials provided
3. A managed identity is created and granted the "Virtual Machine Contributor" role to allow extension deployment
4. The policy is assigned to your subscription or management group

## Policy Effects

- **DeployIfNotExists**: Automatically installs the agent on non-compliant VMs (default)
- **AuditIfNotExists**: Reports non-compliant VMs but doesn't install the agent
- **Disabled**: Policy is inactive

## Result in Azure

![alt text](image.png)

![alt text](image-2.png)

## Verify Service is Running

```powershell

# Check if CrowdStrike service is running
$csService = Get-Service -Name "CSFalconService" -ErrorAction SilentlyContinue
if ($csService -and $csService.Status -eq 'Running') {
    Write-Host "CrowdStrike Falcon service is running" -ForegroundColor Green
} else {
    Write-Host "CrowdStrike Falcon service is not running or not installed" -ForegroundColor Red
}
```

![alt text](image-1.png)

## Troubleshooting

If deployment fails, check:

- Verify your CrowdStrike API credentials are valid
- Ensure the managed identity has appropriate permissions
- Check VM extension deployment logs for installation errors

## Notes

- The template uses the official CrowdStrike installation script from GitHub
- Newly created VMs will automatically receive the agent during provisioning
- Credentials are passed securely to the deployment

## References

- [CrowdStrike Falcon Documentation](https://falcon.crowdstrike.com/documentation/)
- [Azure Policy Documentation](https://docs.microsoft.com/en-us/azure/governance/policy/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
