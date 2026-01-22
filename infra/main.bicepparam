using './main.bicep'

// ============================================================================
// Logic App Standard Deployment Parameters
// ============================================================================

// Required: Name prefix for all resources
//param namePrefix = '12226logapp'
param namePrefix = 'fhp26logapp'
// Optional: Location (defaults to resource group location if not specified)
// param location = 'eastus'

// Optional: Custom resource names (will use defaults based on namePrefix if not specified)
// param logicAppName = 'my-custom-logicapp'
// param appServicePlanName = 'my-custom-asp'
// param storageAccountName = 'mycustomstorage'
// param applicationInsightsName = 'my-custom-appi'
// param logAnalyticsWorkspaceName = 'my-custom-law'

// App Service Plan Configuration
param appServicePlanSku = 'WS1'
param appServicePlanWorkerCount = 1
param zoneRedundant = false

// Storage Account Configuration
param storageAccountSku = 'Standard_LRS'

// Application Insights Configuration
param enableApplicationInsights = true
param applicationInsightsRetentionDays = 90

// Log Analytics Configuration
param logAnalyticsWorkspaceSku = 'PerGB2018'
param logAnalyticsRetentionDays = 30

// Logic App Configuration
param httpsOnly = true
param use32BitWorkerProcess = false
param alwaysOn = true

// VNet Integration (optional - leave empty if not using VNet)
param vnetIntegrationSubnetId = ''

// Tags
param tags = {
  Environment: 'Development'
  Project: 'LogicApp-Demo'
  ManagedBy: 'Bicep'
}
