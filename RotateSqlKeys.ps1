# Install the SqlServer PS module FIRST!!!
# Use "Install-Module -Name SqlServer" as Administrator


# Set Variables
$serverName = "SQLTEST"
$databaseName = "AdventureWorks2019"
$certThumbprint = "712961905b5c2e1915b135384aa5e7c49ad9ff59"
$cmkName = "NewCMK1"
$cekName = "NewCEK1"


#Import the SQL Server PS module
Import-Module SqlServer


# Connect to DB
Write-Host "Connecting to $serverName - $databaseName"
$connStr = "Data Source=" + $serverName + ";Initial Catalog=" + $databaseName + ";Integrated Security=True;MultipleActiveResultSets=False;Connect Timeout=30;Column Encryption Setting=enabled;Encrypt=False;TrustServerCertificate=False;Packet Size=4096;Application Name=`"Microsoft SQL Server Management Studio`""
$database = Get-SqlDatabase -ConnectionString $connStr


# Create CMK and CEK based off thumbprint
Write-Host "Creating new CMK and CEK (which will error if they exist)" -ForegroundColor Green
$cmkSettings = New-SqlCertificateStoreColumnMasterKeySettings -CertificateStoreLocation "LocalMachine" -Thumbprint $certThumbprint
New-SqlColumnMasterKey -Name $cmkName -InputObject $database -ColumnMasterKeySettings $cmkSettings
New-SqlColumnEncryptionKey -Name $cekName  -InputObject $database -ColumnMasterKey $cmkName


Pause


# Get list of all CMK's that we'll rotate
$curKeys = Get-SqlColumnMasterKey -InputObject $database | Where {$_.Name -ne $cmkName}
$curKeys = $curKeys -replace '[[\]]',''
Write-Host "Current CMKs"  -ForegroundColor Green
Write-Host $curKeys


# Get list of all encrypted columns
Write-Host "Currently Encrypted Columns" -ForegroundColor Green
$tables = $database.Tables
for($i=0; $i -lt $tables.Count; $i++){
    $columns = $tables[$i].Columns
    for($j=0; $j -lt $columns.Count; $j++) {
        if($columns[$j].isEncrypted) {
            $threeColPartName = $tables[$i].Schema + "." + $tables[$i].Name + "." + $columns[$j].Name
            Write-Host $threeColPartName
        }
    }
}

# Start CMK Rotation
Write-Host "Starting CMK rotation to" $cmkName -ForegroundColor Green
ForEach ($curKey in $curKeys) {
    Invoke-SqlColumnMasterKeyRotation -SourceColumnMasterKeyName $curKey -TargetColumnMasterKeyName $cmkName -InputObject $database
    }

Write-Host "Key rotation invoked. Validate application before continuing" -ForegroundColor Green
Pause


# Complete CMK rotation
Write-Host "Completing CMK rotation to" $cmkName -ForegroundColor Green
ForEach ($curKey in $curKeys) {
    Complete-SqlColumnMasterKeyRotation -SourceColumnMasterKeyName $curKey -InputObject $database
    }

Write-Host "Key rotation complete" -ForegroundColor Green
