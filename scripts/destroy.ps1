Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$terraformDir = Join-Path $repoRoot "terraform"

Set-Location $terraformDir

Write-Host "Destroying AWS TGW segmentation lab from: $terraformDir"
Write-Host "This uses the local terraform.tfstate file. Do not delete state before destroy."

terraform destroy

