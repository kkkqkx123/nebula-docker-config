# NebulaGraph Basic Function Test Script
# Test nebula-console connection and basic operations

Write-Host "Starting NebulaGraph basic function test..." -ForegroundColor Green

# Test nebula-console connection
Write-Host "`nTesting nebula-console connection..." -ForegroundColor Yellow

# Check if nebula-console exists
$consolePath = ""
if (Get-Command "nebula-console" -ErrorAction SilentlyContinue) {
    $consolePath = "nebula-console"
} elseif (Test-Path ".\nebula-console.exe") {
    $consolePath = ".\nebula-console.exe"
} else {
    Write-Host "Error: nebula-console not found" -ForegroundColor Red
    Write-Host "Please ensure nebula-console is installed and in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "Using nebula-console path: $consolePath" -ForegroundColor Gray

# Execute basic connection test
Write-Host "Executing connection test..." -ForegroundColor Gray
$connectionTest = & $consolePath -u root -p nebula --address=127.0.0.1 --port=9669 --eval="SHOW HOSTS;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Connection successful!" -ForegroundColor Green
    
    # Analyze results
    if ($connectionTest -match "storaged") {
        Write-Host "Storage service detected as running" -ForegroundColor Green
    }
    
    if ($connectionTest -match "metad") {
        Write-Host "Metadata service detected as running" -ForegroundColor Green
    }
    
    Write-Host "`nQuery results:" -ForegroundColor Cyan
    Write-Host $connectionTest -ForegroundColor White
    
} else {
    Write-Host "Connection failed!" -ForegroundColor Red
    Write-Host "Error information:" -ForegroundColor Red
    Write-Host $connectionTest -ForegroundColor Red
    exit 1
}

# Test space creation with proper vid_type
Write-Host "`nTesting test space creation..." -ForegroundColor Yellow
$createSpace = & $consolePath -u root -p nebula --address=127.0.0.1 --port=9669 --eval="CREATE SPACE IF NOT EXISTS test_space(partition_num=1, replica_factor=1, vid_type=fixed_string(30)); USE test_space; SHOW SPACES;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Space creation successful!" -ForegroundColor Green
    Write-Host $createSpace -ForegroundColor White
} else {
    Write-Host "Space creation failed!" -ForegroundColor Red
    Write-Host $createSpace -ForegroundColor Red
}

# Test tag creation
Write-Host "`nTesting tag creation..." -ForegroundColor Yellow
$createTag = & $consolePath -u root -p nebula --address=127.0.0.1 --port=9669 --eval="USE test_space; CREATE TAG IF NOT EXISTS person(name string, age int); SHOW TAGS;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Tag creation successful!" -ForegroundColor Green
    Write-Host $createTag -ForegroundColor White
} else {
    Write-Host "Tag creation failed!" -ForegroundColor Red
    Write-Host $createTag -ForegroundColor Red
}

# Test edge creation
Write-Host "`nTesting edge creation..." -ForegroundColor Yellow
$createEdge = & $consolePath -u root -p nebula --address=127.0.0.1 --port=9669 --eval="USE test_space; CREATE EDGE IF NOT EXISTS friend(relationship string); SHOW EDGES;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Edge creation successful!" -ForegroundColor Green
    Write-Host $createEdge -ForegroundColor White
} else {
    Write-Host "Edge creation failed!" -ForegroundColor Red
    Write-Host $createEdge -ForegroundColor Red
}

# Clean up
Write-Host "`nCleaning up test space..." -ForegroundColor Yellow
$cleanup = & $consolePath -u root -p nebula --address=127.0.0.1 --port=9669 --eval="DROP SPACE test_space;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Cleanup successful!" -ForegroundColor Green
} else {
    Write-Host "Cleanup failed (this is OK if space didn't exist)" -ForegroundColor Yellow
}

Write-Host "`nTest completed!" -ForegroundColor Green