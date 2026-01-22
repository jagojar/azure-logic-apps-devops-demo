# Logic App Standard Deployment Script
# This script deploys the Logic App workflows to Azure

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-logicapp",
    
    [Parameter(Mandatory=$false)]
    [string]$LogicAppName = "demo7960-logicapp"
)

$ErrorActionPreference = "Stop"

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logicAppDir = Join-Path $scriptDir "logic-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Logic App Standard Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Logic App Name: $LogicAppName" -ForegroundColor Yellow
Write-Host "Source Directory: $logicAppDir" -ForegroundColor Yellow
Write-Host ""

# Check if logic-app directory exists
if (-not (Test-Path $logicAppDir)) {
    Write-Error "Logic App directory not found: $logicAppDir"
    exit 1
}

# Create a zip file for deployment
$zipPath = Join-Path $env:TEMP "logic-app-deploy.zip"

Write-Host "Creating deployment package..." -ForegroundColor Green

# Remove existing zip if present
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Get files to include (respecting .funcignore)
$funcIgnorePath = Join-Path $logicAppDir ".funcignore"
$excludePatterns = @()
if (Test-Path $funcIgnorePath) {
    $excludePatterns = Get-Content $funcIgnorePath | Where-Object { $_ -and $_ -notmatch '^\s*#' }
}

# Create zip file
Push-Location $logicAppDir
try {
    # Create the zip preserving folder structure
    Compress-Archive -Path ".\*" -DestinationPath $zipPath -Force
    Write-Host "Deployment package created: $zipPath" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Deploy using Azure CLI
Write-Host ""
Write-Host "Deploying to Azure..." -ForegroundColor Green

# Deploy using zipdeploy
az webapp deployment source config-zip `
    --resource-group $ResourceGroupName `
    --name $LogicAppName `
    --src $zipPath

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Get the Logic App URL
    $logicAppUrl = az webapp show --resource-group $ResourceGroupName --name $LogicAppName --query "defaultHostName" -o tsv
    Write-Host "Logic App URL: https://$logicAppUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Workflows deployed:" -ForegroundColor Yellow
    Write-Host "  - HelloWorld (HTTP POST)" -ForegroundColor White
    Write-Host "  - ProcessOrder (HTTP POST)" -ForegroundColor White
    Write-Host ""
    Write-Host "To get the workflow callback URLs, go to Azure Portal or use:" -ForegroundColor Gray
    Write-Host "  az rest --method post --uri 'https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/{workflowName}/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2022-03-01'" -ForegroundColor Gray
}
else {
    Write-Host ""
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}

# Cleanup
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
