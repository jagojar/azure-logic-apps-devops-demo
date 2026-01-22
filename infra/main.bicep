// ============================================================================
// Logic App Standard Deployment
// This Bicep template deploys a Logic App Standard with all required resources:
// - App Service Plan (Workflow Standard tier)
// - Storage Account (required for Logic App runtime)
// - Application Insights (optional but recommended)
// - Log Analytics Workspace (required for Application Insights)
// - Logic App Standard
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name prefix for all resources')
param namePrefix string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Logic App')
param logicAppName string = '${namePrefix}-logicapp'

@description('Name of the App Service Plan')
param appServicePlanName string = '${namePrefix}-asp'

@description('Name of the Storage Account (must be globally unique, lowercase, max 24 chars)')
@maxLength(24)
param storageAccountName string = toLower(replace('${namePrefix}st', '-', ''))

@description('Name of the Application Insights instance')
param applicationInsightsName string = '${namePrefix}-appi'

@description('Name of the Log Analytics Workspace')
param logAnalyticsWorkspaceName string = '${namePrefix}-law'

@description('SKU for the App Service Plan')
@allowed([
  'WS1'
  'WS2'
  'WS3'
])
param appServicePlanSku string = 'WS1'

@description('Number of workers for the App Service Plan')
@minValue(1)
@maxValue(10)
param appServicePlanWorkerCount int = 1

@description('Enable zone redundancy for the App Service Plan')
param zoneRedundant bool = false

@description('Storage Account SKU')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
])
param storageAccountSku string = 'Standard_LRS'

@description('Enable Application Insights')
param enableApplicationInsights bool = true

@description('Retention period in days for Application Insights')
@allowed([
  30
  60
  90
  120
  180
  270
  365
  550
  730
])
param applicationInsightsRetentionDays int = 90

@description('Log Analytics Workspace SKU')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
  'PerNode'
])
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Log Analytics Workspace retention in days')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionDays int = 30

@description('Enable HTTPS only for Logic App')
param httpsOnly bool = true

@description('Tags to apply to all resources')
param tags object = {}

@description('Use 32-bit worker process')
param use32BitWorkerProcess bool = false

// Security tags that will be merged with user-provided tags
var securityTags = {
  SecurityControl: 'Ignore'
  SecurityContext: 'Ignore'
}

// Merge user tags with security tags
var allTags = union(tags, securityTags)

@description('Always On setting for the Logic App')
param alwaysOn bool = true

@description('Enable VNet integration subnet resource ID (optional)')
param vnetIntegrationSubnetId string = ''

// ============================================================================
// Variables
// ============================================================================

var logicAppKind = 'functionapp,workflowapp'

// ============================================================================
// Resources
// ============================================================================

// Log Analytics Workspace (required for Application Insights)
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (enableApplicationInsights) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: allTags
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
    retentionInDays: logAnalyticsRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Storage Account (required for Logic App Standard)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: allTags
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true  // Required for Logic App Standard to access storage
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Blob Services for Storage Account
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// File Services for Storage Account
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Queue Services for Storage Account
resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// Table Services for Storage Account
resource tableServices 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (enableApplicationInsights) {
  name: applicationInsightsName
  location: location
  tags: allTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: applicationInsightsRetentionDays
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan (Workflow Standard tier for Logic App Standard)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: allTags
  sku: {
    name: appServicePlanSku
    tier: 'WorkflowStandard'
    size: appServicePlanSku
    capacity: appServicePlanWorkerCount
  }
  kind: 'elastic'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: zoneRedundant
  }
}

// Logic App Standard
resource logicApp 'Microsoft.Web/sites@2023-01-01' = {
  name: logicAppName
  location: location
  tags: allTags
  kind: logicAppKind
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: httpsOnly
    virtualNetworkSubnetId: !empty(vnetIntegrationSubnetId) ? vnetIntegrationSubnetId : null
    siteConfig: {
      netFrameworkVersion: 'v6.0'
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      use32BitWorkerProcess: use32BitWorkerProcess
      alwaysOn: alwaysOn
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: false
      }
      appSettings: concat([
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(logicAppName)
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowapp'
        }
      ], enableApplicationInsights ? [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
      ] : [])
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The name of the Logic App')
output logicAppName string = logicApp.name

@description('The resource ID of the Logic App')
output logicAppId string = logicApp.id

@description('The default hostname of the Logic App')
output logicAppDefaultHostname string = logicApp.properties.defaultHostName

@description('The principal ID of the Logic App managed identity')
output logicAppPrincipalId string = logicApp.identity.principalId

@description('The name of the App Service Plan')
output appServicePlanName string = appServicePlan.name

@description('The resource ID of the App Service Plan')
output appServicePlanId string = appServicePlan.id

@description('The name of the Storage Account')
output storageAccountName string = storageAccount.name

@description('The resource ID of the Storage Account')
output storageAccountId string = storageAccount.id

@description('The name of the Application Insights instance')
output applicationInsightsName string = enableApplicationInsights ? applicationInsights.name : ''

@description('The resource ID of the Application Insights instance')
output applicationInsightsId string = enableApplicationInsights ? applicationInsights.id : ''

@description('The instrumentation key of the Application Insights instance')
output applicationInsightsInstrumentationKey string = enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''

@description('The connection string of the Application Insights instance')
output applicationInsightsConnectionString string = enableApplicationInsights ? applicationInsights.properties.ConnectionString : ''

@description('The name of the Log Analytics Workspace')
output logAnalyticsWorkspaceName string = enableApplicationInsights ? logAnalyticsWorkspace.name : ''

@description('The resource ID of the Log Analytics Workspace')
output logAnalyticsWorkspaceId string = enableApplicationInsights ? logAnalyticsWorkspace.id : ''
