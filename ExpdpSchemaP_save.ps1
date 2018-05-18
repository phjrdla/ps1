<#	
.SYNOPSIS
ExpdpSchemaP.ps1 does a parallel Datapump export for specified database and schema
	
.DESCRIPTION
ExpdpSchema uses Oracle utility Datapump to perform aschema dump and to zip it. 

.Parameter oracleSid
oracleSid is mandatatory

.Parameter schema
Oracle Schema to dump; Mandatory

.Parameter directory
Datapump directory. Default is DATAPUMP

.Parameter directoryPath
Oracle datapump directory path. Default is Q:\Oracle

.Parameter dumpfileName
Oracle datapump dump filename. Default is expdp.

.Parameter estimateOnly
To estimate schema dump size. Default is Y.

.Example ExpdpSchema.ps1 -oracleSid orasolifefev -schema clv61dev -directory datatemp -dumpfilepath c:\
temp -dumpfileName dev -estimateOnly Y	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$oracleSid,
  [Parameter(Mandatory=$True) ] [string]$schema,  [int]$parallel = 3,  [string]$directory= 'DATAPUMP',
  [string]$directoryPath='Q:\Oracle',
  [string]$dumpfileName = 'expdp',
  [string]$estimateOnly = 'Y'
)

write-host "Parameters are :"
write-host "     oracleSid is $oracleSid"
write-host "        schema is $schema"
write-host "     directory is $directory"
write-host " directoryPath is $directoryPath"
write-host "  dumpfileName is $dumpfileName"
write-host "  estimateOnly is $estimateOnly"

$thisScript = $MyInvocation.MyCommand

write-host "ThisScript is $thisScript"

$env:ORACLE_SID = $oracleSid
 
$tstamp = get-date -Format 'yyyyMMdd-hhmmss'

# Set-Location -Path D:\solife-DB\pb

$cnx = "'/ as sysdba'"

$job_name      = $schema
$dumpfile      = $dumpfileName + '_%u.dmp'
$dumpfiles4zip = $dumpfileName + '_*.dmp'
$zipfile       = $dumpfileName + '.zip'
$logfile       = $dumpfileName + '.txt'
$parfile       = $dumpfileName + '.par'

Write-Output "$dumpfile"
Write-Output "$zipfile"

If (Test-Path $parfile){
  Remove-Item $parfile
  Write-Host "Removed $parfile"
}

if ( $estimateOnly -eq 'N' ) {
  $parfile_txt = @"
JOB_NAME=$job_name
DIRECTORY=$directory
DUMPFILE=$dumpfile
PARALLEL=$parallel
CONTENT=ALL
COMPRESSION=ALL
LOGFILE=$logfile
REUSE_DUMPFILES=Y
SCHEMAS=$schema
LOGTIME=ALL
KEEP_MASTER=NO
METRICS=N
STATUS=60
"@
}
else {
  $parfile_txt = @"
DIRECTORY=$directory
PARALLEL=$parallel
CONTENT=ALL
COMPRESSION=ALL
LOGFILE=$logfile
SCHEMAS=$schema
KEEP_MASTER=NO
METRICS=N
LOGTIME=ALL
ESTIMATE_ONLY=YES
"@
}

write-host "parfile is $parfile"
$parfile_txt | Out-File $parfile -encoding ascii
expdp $cnx parfile=$parfile

If ( Test-Path $directoryPath\$dumpfile4zip ) { 
  zip -mv $directoryPath\$zipfile $directoryPath\$dumpfiles4zip
}

$EcofCode=0
exit $EcofCode
