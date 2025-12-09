#!/bin/bash

################################################################################
# Content Processing Solution Accelerator - Deployment Script
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

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TENANT_ID="33ce68e6-c5a8-455c-8741-b3ebb73dcb06"
SUBSCRIPTION_ID="7c8b2a60-04bf-498a-bbac-ce9ee669564a"
LOCATION="centralus"
DEFAULT_ENV_NAME="rg-dashco"

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check azd version
    if ! command -v azd &> /dev/null; then
        print_error "Azure Developer CLI (azd) is not installed"
        echo "Please install azd from: https://aka.ms/install-azd"
        exit 1
    fi
    
    local azd_version=$(azd version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    print_success "Azure Developer CLI version: $azd_version"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed or not in PATH"
        echo "Docker is required for building containers. Install from: https://www.docker.com/products/docker-desktop/"
    else
        if docker info &> /dev/null; then
            print_success "Docker is running"
        else
            print_warning "Docker daemon is not running. Please start Docker Desktop."
        fi
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        print_success "Git is installed"
    fi
    
    echo ""
}

authenticate_azure() {
    print_header "Azure Authentication"
    
    print_info "Authenticating with Azure Developer CLI..."
    if azd auth login --tenant-id "$TENANT_ID"; then
        print_success "Successfully authenticated with Azure"
    else
        print_error "Authentication failed"
        exit 1
    fi
    
    echo ""
}

create_environment() {
    print_header "Environment Setup"
    
    local env_name="${1:-$DEFAULT_ENV_NAME}"
    
    # Check if environment already exists
    if azd env list | grep -q "$env_name"; then
        print_warning "Environment '$env_name' already exists"
        read -p "Do you want to use the existing environment? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter a new environment name: " env_name
        fi
    fi
    
    # Select or create environment
    if azd env list | grep -q "$env_name"; then
        print_info "Selecting existing environment: $env_name"
        azd env select "$env_name"
    else
        print_info "Creating new environment: $env_name"
        azd env new "$env_name"
    fi
    
    # Set environment variables
    print_info "Configuring environment variables..."
    azd env set AZURE_SUBSCRIPTION_ID "$SUBSCRIPTION_ID"
    azd env set AZURE_LOCATION "$LOCATION"
    
    print_success "Environment configured: $env_name"
    print_info "Subscription: $SUBSCRIPTION_ID"
    print_info "Location: $LOCATION"
    
    echo ""
}

deploy_solution() {
    print_header "Deploying to Azure"
    
    print_info "Starting deployment (this will take 4-6 minutes)..."
    print_warning "Do not interrupt the deployment process"
    
    echo ""
    
    if azd up; then
        print_success "Deployment completed successfully!"
    else
        print_error "Deployment failed"
        echo ""
        print_info "Troubleshooting steps:"
        echo "  1. Check the error message above"
        echo "  2. Verify quota availability: ./docs/quota_check.md"
        echo "  3. Review troubleshooting guide: ./docs/TroubleShootingSteps.md"
        echo "  4. Check Azure Portal for resource status"
        exit 1
    fi
    
    echo ""
}

display_post_deployment_steps() {
    print_header "Next Steps - Post Deployment Configuration"
    
    # Get the API endpoint from environment
    local api_endpoint=$(azd env get-values | grep SERVICE_API_URI | cut -d= -f2 | tr -d '"' | sed 's|https://||' | sed 's|/$||')
    
    if [ -z "$api_endpoint" ]; then
        print_warning "Could not retrieve API endpoint automatically"
        print_info "You can find the API endpoint in the Azure Portal or by running: azd env get-values"
        api_endpoint="<YOUR-API-ENDPOINT>"
    fi
    
    cat << EOF

${GREEN}✓ Deployment Complete!${NC}

${YELLOW}⚠️  IMPORTANT: Complete these steps before using the application:${NC}

${BLUE}Step 1: Register Schema Files${NC}
────────────────────────────────────────────────────────────────
cd src/ContentProcessorAPI/samples/schemas
./register_schema.sh https://${api_endpoint}/schemavault/ schema_info_sh.json

${BLUE}Step 2: Import Sample Data${NC}
────────────────────────────────────────────────────────────────
cd src/ContentProcessorAPI/samples

# Upload invoices (replace <INVOICE_SCHEMA_ID> with ID from Step 1)
./upload_files.sh https://${api_endpoint}/contentprocessor/submit ./invoices <INVOICE_SCHEMA_ID>

# Upload property claims (replace <CLAIM_SCHEMA_ID> with ID from Step 1)
./upload_files.sh https://${api_endpoint}/contentprocessor/submit ./propertyclaims <CLAIM_SCHEMA_ID>

${BLUE}Step 3: Configure Authentication${NC}
────────────────────────────────────────────────────────────────
Follow the guide: ./docs/ConfigureAppAuthentication.md
(Note: Authentication changes can take up to 10 minutes)

${BLUE}Useful Commands:${NC}
────────────────────────────────────────────────────────────────
View environment values:     azd env get-values
View deployment status:      azd show
Open Azure Portal:           azd show --output table
Clean up resources:          azd down

${BLUE}Documentation:${NC}
────────────────────────────────────────────────────────────────
Sample Workflow:             ./docs/SampleWorkflow.md
Customize Schemas:           ./docs/CustomizeSchemaData.md
API Documentation:           ./docs/API.md
Troubleshooting:             ./docs/TroubleShootingSteps.md

EOF
}

show_usage() {
    cat << EOF
Usage: ./deploy.sh [OPTIONS]

Deploy the Content Processing Solution Accelerator to Azure.

Options:
    -e, --env-name NAME     Specify environment name (default: $DEFAULT_ENV_NAME)
    -s, --skip-auth         Skip authentication step (if already authenticated)
    -h, --help              Display this help message

Examples:
    ./deploy.sh                          # Standard deployment
    ./deploy.sh -e my-env-name           # Deploy with custom environment name
    ./deploy.sh --skip-auth              # Skip authentication

Configuration:
    Tenant ID:      $TENANT_ID
    Subscription:   $SUBSCRIPTION_ID
    Location:       $LOCATION

EOF
}

################################################################################
# Main Script
################################################################################

main() {
    local env_name="$DEFAULT_ENV_NAME"
    local skip_auth=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env-name)
                env_name="$2"
                shift 2
                ;;
            -s|--skip-auth)
                skip_auth=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Display banner
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   Content Processing Solution Accelerator - Deployment Script        ║
║                                                                       ║
║   Microsoft - Azure AI                                                ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
    
    echo ""
    print_info "Starting deployment process..."
    echo ""
    
    # Run deployment steps
    check_prerequisites
    
    if [ "$skip_auth" = false ]; then
        authenticate_azure
    else
        print_info "Skipping authentication (--skip-auth specified)"
        echo ""
    fi
    
    create_environment "$env_name"
    deploy_solution
    display_post_deployment_steps
    
    print_success "Deployment script completed!"
    echo ""
}

# Run main function
main "$@"
