################################################################################
# Content Processing Solution Accelerator - Deployment Script (PowerShell)
################################################################################
# This script automates the deployment of the Content Processing Solution
# to Azure using the Azure Developer CLI (azd).
#
# Deployment Configuration:
# - Tenant ID: 33ce68e6-c5a8-455c-8741-b3ebb73dcb06
# - Subscription ID: 7c8b2a60-04bf-498a-bbac-ce9ee669564a
# - Region: westus2
# - Deployment Type: Development/Testing (default configuration)
#
# Prerequisites:
# - Azure Developer CLI (azd) v1.18.0 or higher
# - Docker Desktop running
# - Verified Azure OpenAI quota availability
# - Owner permissions on Azure subscription
################################################################################

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Environment name for the deployment")]
    [string]$EnvName = "dashco",
    
    [Parameter(HelpMessage="Skip authentication step")]
    [switch]$SkipAuth,
    
    [Parameter(HelpMessage="Display help information")]
    [switch]$Help
)

# Configuration
$TENANT_ID = "33ce68e6-c5a8-455c-8741-b3ebb73dcb06"
$SUBSCRIPTION_ID = "7c8b2a60-04bf-498a-bbac-ce9ee669564a"
$LOCATION = "westus2"

$ErrorActionPreference = "Stop"

################################################################################
# Functions
################################################################################

function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$Color = "White"
    )
    
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    param([string]$Message)
    
    Write-Host ""
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Color Cyan
    Write-ColorOutput $Message -Color Cyan
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Color Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" -Color Green
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" -Color Red
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" -Color Yellow
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "ℹ $Message" -Color Cyan
}

function Show-Usage {
    @"
Usage: .\deploy.ps1 [OPTIONS]

Deploy the Content Processing Solution Accelerator to Azure.

Options:
    -EnvName <NAME>     Specify environment name (default: rg-dashco)
    -SkipAuth           Skip authentication step (if already authenticated)
    -Help               Display this help message

Examples:
    .\deploy.ps1                        # Standard deployment
    .\deploy.ps1 -EnvName my-env        # Deploy with custom environment name
    .\deploy.ps1 -SkipAuth              # Skip authentication

Configuration:
    Tenant ID:      $TENANT_ID
    Subscription:   $SUBSCRIPTION_ID
    Location:       $LOCATION

"@
}

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check azd
    try {
        $azdVersion = (azd version | Select-Object -First 1) -replace '.*(\d+\.\d+\.\d+).*', '$1'
        Write-Success "Azure Developer CLI version: $azdVersion"
    }
    catch {
        Write-Error "Azure Developer CLI (azd) is not installed"
        Write-Host "Please install azd from: https://aka.ms/install-azd"
        exit 1
    }
    
    # Check Docker
    try {
        $null = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker is running"
        }
        else {
            Write-Warning "Docker daemon is not running. Please start Docker Desktop."
        }
    }
    catch {
        Write-Warning "Docker is not installed or not in PATH"
        Write-Host "Docker is required for building containers. Install from: https://www.docker.com/products/docker-desktop/"
    }
    
    # Check Git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Success "Git is installed"
    }
    
    Write-Host ""
}

function Invoke-AzureAuthentication {
    Write-Header "Azure Authentication"
    
    Write-Info "Authenticating with Azure Developer CLI..."
    
    try {
        azd auth login --tenant-id $TENANT_ID
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Successfully authenticated with Azure"
        }
        else {
            throw "Authentication failed"
        }
    }
    catch {
        Write-Error "Authentication failed"
        exit 1
    }
    
    Write-Host ""
}

function New-AzdEnvironment {
    param([string]$EnvironmentName)
    
    Write-Header "Environment Setup"
    
    # Check if environment exists
    $existingEnvs = azd env list 2>&1 | Out-String
    
    if ($existingEnvs -match $EnvironmentName) {
        Write-Warning "Environment '$EnvironmentName' already exists"
        $response = Read-Host "Do you want to use the existing environment? (y/n)"
        
        if ($response -notmatch '^[Yy]$') {
            $EnvironmentName = Read-Host "Enter a new environment name"
        }
    }
    
    # Select or create environment
    if ($existingEnvs -match $EnvironmentName) {
        Write-Info "Selecting existing environment: $EnvironmentName"
        azd env select $EnvironmentName
    }
    else {
        Write-Info "Creating new environment: $EnvironmentName"
        azd env new $EnvironmentName
    }
    
    # Set environment variables
    Write-Info "Configuring environment variables..."
    azd env set AZURE_SUBSCRIPTION_ID $SUBSCRIPTION_ID
    azd env set AZURE_LOCATION $LOCATION
    
    Write-Success "Environment configured: $EnvironmentName"
    Write-Info "Subscription: $SUBSCRIPTION_ID"
    Write-Info "Location: $LOCATION"
    
    Write-Host ""
}

function Invoke-Deployment {
    Write-Header "Deploying to Azure"
    
    Write-Info "Starting deployment (this will take 4-6 minutes)..."
    Write-Warning "Do not interrupt the deployment process"
    
    Write-Host ""
    
    try {
        azd up
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Deployment completed successfully!"
        }
        else {
            throw "Deployment failed"
        }
    }
    catch {
        Write-Error "Deployment failed"
        Write-Host ""
        Write-Info "Troubleshooting steps:"
        Write-Host "  1. Check the error message above"
        Write-Host "  2. Verify quota availability: .\docs\quota_check.md"
        Write-Host "  3. Review troubleshooting guide: .\docs\TroubleShootingSteps.md"
        Write-Host "  4. Check Azure Portal for resource status"
        exit 1
    }
    
    Write-Host ""
}

function Show-PostDeploymentSteps {
    Write-Header "Next Steps - Post Deployment Configuration"
    
    # Get API endpoint
    try {
        $envValues = azd env get-values | Out-String
        $apiEndpoint = if ($envValues -match 'SERVICE_API_URI="([^"]+)"') {
            $matches[1] -replace 'https://', '' -replace '/$', ''
        }
        else {
            "<YOUR-API-ENDPOINT>"
            Write-Warning "Could not retrieve API endpoint automatically"
        }
    }
    catch {
        $apiEndpoint = "<YOUR-API-ENDPOINT>"
        Write-Warning "Could not retrieve API endpoint automatically"
    }
    
    Write-ColorOutput "`n✓ Deployment Complete!" -Color Green
    
    Write-Host ""
    Write-ColorOutput "⚠️  IMPORTANT: Complete these steps before using the application:" -Color Yellow
    Write-Host ""
    
    Write-ColorOutput "Step 1: Register Schema Files" -Color Cyan
    Write-Host "────────────────────────────────────────────────────────────────"
    Write-Host "cd src\ContentProcessorAPI\samples\schemas"
    Write-Host ".\register_schema.ps1 https://$apiEndpoint/schemavault/ .\schema_info_ps1.json"
    Write-Host ""
    
    Write-ColorOutput "Step 2: Import Sample Data" -Color Cyan
    Write-Host "────────────────────────────────────────────────────────────────"
    Write-Host "cd src\ContentProcessorAPI\samples"
    Write-Host ""
    Write-Host "# Upload invoices (replace <INVOICE_SCHEMA_ID> with ID from Step 1)"
    Write-Host ".\upload_files.ps1 https://$apiEndpoint/contentprocessor/submit .\invoices <INVOICE_SCHEMA_ID>"
    Write-Host ""
    Write-Host "# Upload property claims (replace <CLAIM_SCHEMA_ID> with ID from Step 1)"
    Write-Host ".\upload_files.ps1 https://$apiEndpoint/contentprocessor/submit .\propertyclaims <CLAIM_SCHEMA_ID>"
    Write-Host ""
    
    Write-ColorOutput "Step 3: Configure Authentication" -Color Cyan
    Write-Host "────────────────────────────────────────────────────────────────"
    Write-Host "Follow the guide: .\docs\ConfigureAppAuthentication.md"
    Write-Host "(Note: Authentication changes can take up to 10 minutes)"
    Write-Host ""
    
    Write-ColorOutput "Useful Commands:" -Color Cyan
    Write-Host "────────────────────────────────────────────────────────────────"
    Write-Host "View environment values:     azd env get-values"
    Write-Host "View deployment status:      azd show"
    Write-Host "Open Azure Portal:           azd show --output table"
    Write-Host "Clean up resources:          azd down"
    Write-Host ""
    
    Write-ColorOutput "Documentation:" -Color Cyan
    Write-Host "────────────────────────────────────────────────────────────────"
    Write-Host "Sample Workflow:             .\docs\SampleWorkflow.md"
    Write-Host "Customize Schemas:           .\docs\CustomizeSchemaData.md"
    Write-Host "API Documentation:           .\docs\API.md"
    Write-Host "Troubleshooting:             .\docs\TroubleShootingSteps.md"
    Write-Host ""
}

################################################################################
# Main Script
################################################################################

function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    # Display banner
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   Content Processing Solution Accelerator - Deployment Script        ║
║                                                                       ║
║   Microsoft - Azure AI                                                ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
"@
    
    Write-Host ""
    Write-Info "Starting deployment process..."
    Write-Host ""
    
    # Run deployment steps
    Test-Prerequisites
    
    if (-not $SkipAuth) {
        Invoke-AzureAuthentication
    }
    else {
        Write-Info "Skipping authentication (--SkipAuth specified)"
        Write-Host ""
    }
    
    New-AzdEnvironment -EnvironmentName $EnvName
    Invoke-Deployment
    Show-PostDeploymentSteps
    
    Write-Success "Deployment script completed!"
    Write-Host ""
}

# Run main function
Main
