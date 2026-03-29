# Azure Cloud Resume Challenge

[![Smoke Test](https://github.com/jhessig/Azure-CRC/actions/workflows/smoketest.yml/badge.svg?branch=test)](https://github.com/jhessig/Azure-CRC/actions/workflows/smoketest.yml)
[![Deploy](https://github.com/jhessig/Azure-CRC/actions/workflows/deploy.yml/badge.svg?branch=master)](https://github.com/jhessig/Azure-CRC/actions/workflows/deploy.yml)

A fully functional, Azure-hosted resume website built as part of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/). Infrastructure is managed with Terraform, the backend visitor counter runs on Azure Functions (Python), and CI/CD is handled by GitHub Actions.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Environment Variables](#environment-variables)
- [Setup & Deployment](#setup--deployment)
- [Running Tests](#running-tests)
- [Project Structure](#project-structure)
- [CI/CD Workflows](#cicd-workflows)
- [License](#license)

## Project Overview

| Layer | Technology |
|---|---|
| **Frontend** | Static HTML / CSS / JavaScript |
| **Backend** | Python 3 – Azure Functions (`function_app.py`) |
| **Database** | Azure Cosmos DB (Table API) |
| **IaC** | Terraform (AzureRM ~> 3.107, Cloudflare ~> 5) |
| **DNS / CDN** | Cloudflare |
| **CI/CD** | GitHub Actions |
| **E2E / API Tests** | Playwright (Node.js) |
| **Unit Tests** | Python `unittest` |
| **Package Manager** | npm (Playwright devDeps) / pip (Function App) |

## Architecture

1. **Static site** – HTML/CSS/JS hosted in an Azure Storage static website.
2. **Visitor counter API** – A Python Azure Function (`/api/visitor_count`) that increments and returns a visit count stored in Cosmos DB (Table API).
3. **Infrastructure** – Provisioned via Terraform: Resource Group, Storage Account, Function App, Cosmos DB, Cloudflare DNS records, Azure Monitor alerts, and more.
4. **CI/CD** – Three GitHub Actions workflows handle deployment, smoke testing, and teardown.

## Requirements

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.1.0
- [Node.js](https://nodejs.org/) (for Playwright tests)
- [Python 3](https://www.python.org/) (for the Azure Function and unit tests)
- An **Azure** account with a configured Service Principal
- A **Cloudflare** account (for DNS management)
- An existing **Azure Key Vault** containing required secrets

## Environment Variables

### Terraform Variables

| Variable | Description | Default |
|---|---|---|
| `domain_name` | Custom domain for the site | — (required) |
| `resource_group_name` | Base name for the resource group | `crc` |
| `azure_region` | Azure region for resources | `Central US` |
| `env_tag` | Environment tag (passed by workflow) | — (required) |
| `key_vault_name` | Name of the Azure Key Vault | — (required) |
| `key_vault_rg` | Resource group of the Key Vault | — (required) |
| `alert_email` | Email for Azure Monitor alerts | — (required) |
| `webhook_url` | Webhook URL for Monitor alerts | — (required) |
| `alert_sms` | Phone number for SMS alerts | — (required) |
| `cloudflare_api_token` | Cloudflare API token (sensitive) | — (required) |
| `cloudflare_zone_id` | Cloudflare zone ID (sensitive) | — (required) |

### Function App Runtime

| Variable | Description |
|---|---|
| `COSMOS_CONN_STRING` | Connection string for Azure Cosmos DB |

> GitHub Actions workflows expect these values to be stored as **GitHub Secrets** and passed at plan/apply time.

## Setup & Deployment

### 1. Clone the repository

```bash
git clone https://github.com/jhessig/Azure-CRC.git
cd Azure-CRC
```

### 2. Install Node.js dependencies (for tests)

```bash
npm install
npx playwright install --with-deps
```

### 3. Install Python dependencies (for the Function App)

```bash
pip install -r function-app/requirements.txt
```

### 4. Initialise Terraform

The backend is configured for Azure Storage (`backend "azurerm" {}`). Provide your backend config at init time:

```bash
terraform init \
  -backend-config="storage_account_name=<YOUR_STORAGE_ACCOUNT>" \
  -backend-config="container_name=<YOUR_CONTAINER>" \
  -backend-config="key=<YOUR_STATE_KEY>" \
  -backend-config="resource_group_name=<YOUR_RG>"
```

### 5. Plan & Apply

```bash
terraform plan  -var="domain_name=..." -var="env_tag=..." # ... (all required vars)
terraform apply -var="domain_name=..." -var="env_tag=..." -auto-approve
```

> **Tip:** In practice, deployments are driven automatically through the GitHub Actions workflows (see [CI/CD Workflows](#cicd-workflows)).

## Running Tests

### Playwright (E2E, API & Performance)

```bash
npx playwright test                         # run all projects
npx playwright test --project=chromium      # frontend tests – Chromium only
npx playwright test --project=api-tests     # API tests
npx playwright test --project=performance   # performance tests
```

### Python Unit Tests

```bash
pip install -r tests/python/test_requirements.txt
python -m pytest tests/python/
```

## Project Structure

```text
.
├── .github/workflows/
│   ├── deploy.yml              # Deploy infrastructure & site (master)
│   ├── smoketest.yml           # Smoke tests on PR / test branch
│   └── destroy.yml             # Tear down test environment
├── function-app/
│   ├── function_app.py         # Visitor counter Azure Function (Python)
│   ├── host.json               # Azure Functions host config
│   ├── local.settings.json     # Local dev settings
│   └── requirements.txt        # Python dependencies
├── static/
│   ├── index.html              # Resume page
│   ├── 404.html                # Custom 404 page
│   ├── resume.css              # Stylesheet
│   ├── resume.js               # Frontend JS (visitor counter fetch)
│   └── img/                    # Images
├── tests/
│   ├── playwright/
│   │   ├── api-tests.spec.js   # API endpoint tests
│   │   ├── frontend.spec.js    # Browser UI tests
│   │   └── performance.spec.js # Performance checks
│   └── python/
│       ├── test_visitor_counter.py  # Unit tests for the Function
│       └── test_requirements.txt    # Python test dependencies
├── reflections/                # Blog-style reflections on the challenge
├── backend.tf                  # Terraform remote backend config
├── data.tf                     # Data sources (Key Vault, archive)
├── main.tf                     # Core infrastructure resources
├── outputs.tf                  # Terraform outputs
├── providers.tf                # Provider configuration
├── terraform.tf                # Terraform & provider version pins
├── variables.tf                # Input variable declarations
├── playwright.config.js        # Playwright test configuration
├── package.json                # Node.js project metadata & devDeps
└── readme.md                   # ← You are here
```

## CI/CD Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| **deploy.yml** | Push to `master` | Terraform plan/apply, upload static site, run smoke tests |
| **smoketest.yml** | Push to `test` / PR | Deploy to test env, run Playwright smoke tests |
| **destroy.yml** | After smoke test / manual | Tear down the test environment |

## License

This project is **UNLICENSED** (private/proprietary). See `package.json` for details.
