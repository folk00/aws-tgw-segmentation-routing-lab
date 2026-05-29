Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [string]$Region = "us-east-1"
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$terraformDir = Join-Path $repoRoot "terraform"

Set-Location $terraformDir

$raw = terraform output -json ssm_validation_commands | ConvertFrom-Json
$tests = $raw.PSObject.Properties

foreach ($test in $tests) {
    $name = $test.Name
    $sourceInstanceId = $test.Value.source_instance_id
    $targetPrivateIp = $test.Value.target_private_ip
    $expected = $test.Value.expected_result

    $payload = [ordered]@{
        DocumentName = "AWS-RunShellScript"
        InstanceIds  = @($sourceInstanceId)
        Parameters   = @{
            commands = @(
                "echo '${name}: expected $expected'",
                "ping -c 2 $targetPrivateIp || true",
                "curl -m 3 -sS http://$targetPrivateIp`:8080 || true"
            )
        }
    } | ConvertTo-Json -Depth 6

    $tmp = New-TemporaryFile
    Set-Content -LiteralPath $tmp -Value $payload -Encoding ASCII

    try {
        $commandId = aws ssm send-command `
            --region $Region `
            --cli-input-json "file://$tmp" `
            --query Command.CommandId `
            --output text
    }
    finally {
        Remove-Item -LiteralPath $tmp -Force
    }

    for ($i = 1; $i -le 30; $i++) {
        $invocation = aws ssm get-command-invocation `
            --region $Region `
            --command-id $commandId `
            --instance-id $sourceInstanceId `
            --output json | ConvertFrom-Json

        if ($invocation.Status -in @("Success", "Failed", "Cancelled", "TimedOut")) {
            break
        }

        Start-Sleep -Seconds 2
    }

    Write-Host "===== $name ($expected) status=$($invocation.Status) source=$sourceInstanceId target=$targetPrivateIp ====="
    Write-Host $invocation.StandardOutputContent

    if ($invocation.StandardErrorContent) {
        Write-Host "STDERR:"
        Write-Host $invocation.StandardErrorContent
    }
}
