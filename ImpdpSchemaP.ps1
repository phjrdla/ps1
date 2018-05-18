<#	
.SYNOPSIS
ImpdpSchema.ps1 does q Datapump export for specified database and schema
	
.DESCRIPTION
ImpdpSchema uses Oracle utility Datapump to perform aschema dump and to zip it. 

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

.Parameter playOnly
To run impdp without creating anything. Default is Y.

.Example ImpdpSchema.ps1 -oracleSid orasolifefev -schema clv61dev -directory datatemp -dumpfileName dev -estimateOnly Y	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,
  [Parameter(Mandatory=$True) ] [string]$schema,  [int]$parallel = 4,  [string]$directory= 'DATAPUMP',
  [string]$dumpfileName = 'expdp',
  [string]$playOnly = 'Y'
)

write-host "Parameters are :"
write-host "    connectStr is $connStr"
write-host "        schema is $schema"
write-host "     directory is $directory"
write-host "  dumpfileName is $dumpfileName"
write-host "      parallel is $parallel"
write-host "      playOnly is $playOnly"

write-host "ThisScript is $thisScript"
$tstamp = get-date -Format 'yyyyMMddThhmmss'
$cnx = "dp/dpclv@$connectStr"

$job_name = 'impdp_' + $schema
$dumpfile = $dumpfileName + '_%u.dmp'
$logfile  = $dumpfileName + '.txt'
$parfile  = $dumpfileName + '.par'
$sqlfile  = $dumpfileName + '.sql'

Write-Output "$dumpfile"
write-output "job_name is $job_name"

If (Test-Path $parfile){
  Remove-Item $parfile
  Write-Host "Removed $parfile"
}

if ( $playOnly -eq 'N' ) {
  $parfile_txt = @"
JOB_NAME=$job_name
DIRECTORY=$directory
DUMPFILE=$dumpfile
PARALLEL=$parallel
LOGFILE=$logfile
SCHEMAS=$schema
TABLE_EXISTS_ACTION=TRUNCATE
LOGTIME=ALL
"@
}
else {
  $parfile_txt = @"
JOB_NAME=impdp_$schema
DIRECTORY=$directory
DUMPFILE=$dumpfile
PARALLEL=$parallel
SQLFILE=$sqlfile
LOGFILE=$logfile
SCHEMAS=$schema
LOGTIME=ALL
"@
}

write-host "parfile is $parfile"
$parfile_txt | Out-File $parfile -encoding ascii
write-host "impdp parameter file content"
gc $parfile
impdp $cnx parfile=$parfile

  $sql = @"
execute dbms_stats.gather_schema_stats('$schema', options => 'GATHER AUTO', degree=>dbms_stats.default_degree, cascade=>dbms_stats.auto_cascade);
"@
