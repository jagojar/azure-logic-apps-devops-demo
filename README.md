# Logic App Standard DevOps Demo

This project demonstrates how to deploy a Logic App Standard with all required infrastructure using Bicep and Azure CLI.

## Project Structure

```
azure-logic-apps-devops-demo/
├── infra/                           # Infrastructure deployment files
│   ├── infra-deployment-script.ps1  # Infrastructure deployment script
│   ├── main.bicep                   # Bicep template for infrastructure
│   └── main.bicepparam              # Bicep parameters file
└── logicapp-ws/                     # Logic App workspace
    ├── azure-pipelines.yml          # Azure DevOps CI/CD pipeline
    ├── deploy-logicapp.ps1          # Logic App workflows deployment script
    ├── README.md                    # This documentation
    └── logic-app/                   # Logic App workflows
        ├── host.json                # Host configuration
        ├── connections.json         # API connections
        ├── local.settings.json      # Local development settings
        ├── Artifacts/               # Maps and Schemas
        │   ├── Maps/
        │   └── Schemas/
        ├── HelloWorld/              # Sample workflow
        │   └── workflow.json
        └── ProcessOrder/            # Order processing workflow
            └── workflow.json
```

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed and configured
- [Azure subscription](https://azure.microsoft.com/free/) with appropriate permissions
- PowerShell 5.1 or later

## Infrastructure Components

The Bicep template deploys the following resources:

| Resource | Description |
|----------|-------------|
| **Log Analytics Workspace** | Required for Application Insights |
| **Application Insights** | Monitoring and diagnostics |
| **Storage Account** | Required for Logic App runtime state |
| **App Service Plan** | WorkflowStandard tier (WS1/WS2/WS3) |
| **Logic App Standard** | With system-assigned managed identity |

## Deployment Steps

### Step 1: Login to Azure

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

### Step 2: Deploy Infrastructure

Run the infrastructure deployment script:

```powershell
.\script.ps1
```

Or deploy manually using Azure CLI:

```powershell
# Set variables
$rgName = "logapps-devops-demo-rg"
$location = "westus3"

# Create resource group with security tags
az group create --name $rgName --location $location --tags SecurityControl=Ignore SecurityContext=Ignore

# Deploy infrastructure
az deployment group create `
    --resource-group $rgName `
    --template-file main.bicep `
    --parameters main.bicepparam
```

### Step 3: Deploy Logic App Workflows

After the infrastructure is deployed, deploy the Logic App workflows:

```powershell
.\deploy-logicapp.ps1 -ResourceGroupName "logapps-devops-demo-rg" -LogicAppName "<your-logic-app-name>"
```

**Note:** Replace `<your-logic-app-name>` with the actual Logic App name from the infrastructure deployment output.

## Configuration

### Bicep Parameters

Edit `main.bicepparam` to customize the deployment:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namePrefix` | Prefix for all resource names | `logicapp-demo` |
| `appServicePlanSku` | App Service Plan SKU (WS1, WS2, WS3) | `WS1` |
| `storageAccountSku` | Storage Account SKU | `Standard_LRS` |
| `enableApplicationInsights` | Enable Application Insights | `true` |
| `zoneRedundant` | Enable zone redundancy | `false` |

### Sample Configuration

```bicep
using './main.bicep'

param namePrefix = 'mylogicapp'
param appServicePlanSku = 'WS1'
param storageAccountSku = 'Standard_LRS'
param enableApplicationInsights = true
param tags = {
  Environment: 'Production'
  Project: 'MyProject'
}
```

## Workflows

### HelloWorld

A simple HTTP-triggered workflow that returns a greeting message.

**Endpoint:** `POST /api/HelloWorld/triggers/When_a_HTTP_request_is_received/invoke`

**Request Body:**
```json
{
  "name": "John",
  "message": "Hello from Logic App!"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Hello, John! Welcome to Logic App Standard. Your message: Hello from Logic App!",
  "timestamp": "2026-01-22T18:00:00.000Z",
  "workflowName": "HelloWorld"
}
```

### ProcessOrder

An order processing workflow that calculates line totals and order total.

**Endpoint:** `POST /api/ProcessOrder/triggers/When_a_HTTP_request_is_received/invoke`

**Request Body:**
```json
{
  "orderId": "ORD-2026-001",
  "customerId": "CUST-12345",
  "items": [
    { "productId": "PROD-A100", "quantity": 2, "unitPrice": 29.99 },
    { "productId": "PROD-B200", "quantity": 1, "unitPrice": 49.99 },
    { "productId": "PROD-C300", "quantity": 3, "unitPrice": 15.50 }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "orderId": "ORD-2026-001",
  "customerId": "CUST-12345",
  "processedItems": [
    { "productId": "PROD-A100", "quantity": 2, "unitPrice": 29.99, "lineTotal": 59.98 },
    { "productId": "PROD-B200", "quantity": 1, "unitPrice": 49.99, "lineTotal": 49.99 },
    { "productId": "PROD-C300", "quantity": 3, "unitPrice": 15.50, "lineTotal": 46.50 }
  ],
  "orderTotal": 156.47,
  "processedAt": "2026-01-22T18:00:00.000Z",
  "status": "Processed"
}
```

## Testing Workflows

### Get Workflow Callback URL

Use Azure CLI to get the callback URL for a workflow:

```powershell
$subscriptionId = "<your-subscription-id>"
$resourceGroup = "logapps-devops-demo-rg"
$logicAppName = "<your-logic-app-name>"
$workflowName = "HelloWorld"  # or "ProcessOrder"

az rest --method post --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/$workflowName/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2022-03-01"
```

### Test with PowerShell

```powershell
# Get callback URL
$callbackResponse = az rest --method post --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/HelloWorld/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2022-03-01" | ConvertFrom-Json

# Test HelloWorld
$body = @{ name = "John"; message = "Testing!" } | ConvertTo-Json
Invoke-RestMethod -Uri $callbackResponse.value -Method POST -Body $body -ContentType "application/json"
```

### Check Workflow Health

```powershell
az rest --method get --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows?api-version=2022-03-01"
```

## Local Development

### Prerequisites for Local Development

- [Visual Studio Code](https://code.visualstudio.com/)
- [Azure Logic Apps (Standard) extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurelogicapps)
- [Azurite](https://docs.microsoft.com/azure/storage/common/storage-use-azurite) (for local storage emulation)
- [.NET 6.0 SDK](https://dotnet.microsoft.com/download/dotnet/6.0)

### Running Locally

1. Start Azurite for local storage emulation
2. Open the `logic-app` folder in VS Code
3. Press F5 to start debugging
4. The workflows will be available at `http://localhost:7071/api/{workflowName}`

## Cleanup

To delete all resources:

```powershell
az group delete --name logapps-devops-demo-rg --yes --no-wait
```

## Troubleshooting

### Common Issues

1. **Storage Account Access Error (403 Forbidden)**
   - Ensure `allowSharedKeyAccess: true` is set in the storage account configuration
   - This is required for Logic App Standard to access the storage account

2. **Workflow Not Found**
   - Wait a few seconds after deployment for workflows to be loaded
   - Check workflow health using the Azure CLI command above

3. **Self-Reference Variable Error**
   - Logic Apps Standard doesn't support self-referencing variables in `SetVariable` actions
   - Use `Compose` actions or `Select` with explicit calculations instead

## Resources

- [Azure Logic Apps Documentation](https://docs.microsoft.com/azure/logic-apps/)
- [Logic Apps Standard Overview](https://docs.microsoft.com/azure/logic-apps/single-tenant-overview-compare)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [Azure DevOps Pipelines](https://docs.microsoft.com/azure/devops/pipelines/)

## Azure DevOps Pipeline

This project includes an Azure DevOps pipeline (`azure-pipelines.yml`) for automated CI/CD deployment.

### Pipeline Stages

| Stage | Description |
|-------|-------------|
| **Validate** | Validates Bicep template syntax and runs what-if deployment |
| **DeployInfrastructure** | Creates resource group and deploys Bicep template |
| **DeployWorkflows** | Packages and deploys Logic App workflows |
| **SmokeTests** | Tests deployed workflows to verify functionality |

### Pipeline Setup

#### 1. Create Azure Service Connection

1. Go to your Azure DevOps project
2. Navigate to **Project Settings** > **Service connections**
3. Click **New service connection** > **Azure Resource Manager**
4. Select **Service principal (automatic)** or **Service principal (manual)**
5. Configure the connection:
   - **Subscription**: Select your Azure subscription
   - **Resource group**: Leave empty (for subscription-level access)
   - **Service connection name**: `Azure-Service-Connection`
6. Click **Save**

#### 2. Create Pipeline

1. Go to **Pipelines** > **New pipeline**
2. Select your repository source (Azure Repos Git, GitHub, etc.)
3. Select **Existing Azure Pipelines YAML file**
4. Choose `/azure-pipelines.yml`
5. Click **Run**

#### 3. Configure Pipeline Variables (Optional)

You can override the default variables in the pipeline:

| Variable | Description | Default |
|----------|-------------|---------|
| `azureServiceConnection` | Azure service connection name | `Azure-Service-Connection` |
| `resourceGroupName` | Target resource group | `logapps-devops-demo-rg` |
| `location` | Azure region | `westus3` |
| `namePrefix` | Resource name prefix | `logicapp-demo` |

### Pipeline Triggers

The pipeline triggers automatically on:
- Pushes to `main` or `develop` branches
- Changes to `newmain.bicep`, `newmain.bicepparam`, or `logic-app/**` files

### Manual Trigger

To run the pipeline manually:
1. Go to **Pipelines** > Select the pipeline
2. Click **Run pipeline**
3. Optionally modify variables
4. Click **Run**

### Pipeline Approval Gates

The pipeline uses Azure DevOps Environments for deployment approvals:
- Environment name: `production`
- Configure approvals in **Pipelines** > **Environments** > **production** > **Approvals and checks**
