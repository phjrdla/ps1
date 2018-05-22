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

.Example ImpdpSchema.ps1 -oracleSid orasolifefev -schema clv61dev -directory datatemp -dumpfilepath c:\
temp -dumpfileName dev -estimateOnly Y	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,
  [Parameter(Mandatory=$True) ] [string]$schemaOrg,  [Parameter(Mandatory=$True) ] [string]$schemaDes,  [int]$parallel = 4,  [string]$directory= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [string]$dumpfileName = 'expdp',
  [ValidateSet('N','Y')] [string]$disableArchiveLogging = 'Y',
  [ValidateSet('NONE','NOCOMPRESS','COMPRESS')] [string]$tableCompressionClause = 'NONE',
  [string]$playOnly = 'Y'
)

write-host "Parameters are :"
write-host "            connectStr is $connectStr"
write-host "             schemaOrg is $schemaOrg"
write-host "             schemaDes is $schemaDes"
write-host "             directory is $directory"
write-host "          dumpfileName is $dumpfileName"
write-host "              playOnly is $playOnly"
write-host " disableArchiveLogging is $disableArchiveLogging"
write-host "tableCompressionClause is $tableCompressionClause"

$thisSc
write-host "ThisScript is $thisScript" 
$tstamp = get-date -Format 'yyyyMMddTHHmm'
$cnx = "dp/dpclv@$connectStr"

$job_name = 'impdp_' + $schemaDes
$dumpfile = $dumpfileName + '.dmp'
$logfile  = $dumpfileName + '_2_' + $schemaDes + '.txt'
$parfile  = $dumpfileName + '_2_' + $schemaDes + '.par'
$sqlfile  = $dumpfileName + '_2_' + $schemaDes + '.sql'

Write-Output "$dumpfile"
Write-Output "job_name is $job_name"

If (Test-Path $parfile){
  Remove-Item $parfile
  Write-Host "Removed $parfile"
}

if ( $playOnly -eq 'N' ) {
  $parfile_txt = @"
JOB_NAME=impdp_$schemaDes
DIRECTORY=$directory
DUMPFILE=$dumpfile
CONTENT=$content
LOGFILE=$logfile
REMAP_SCHEMA=$schemaOrg`:$schemaDes
TABLE_EXISTS_ACTION=TRUNCATE
LOGTIME=ALL
METRICS=Y
TRANSFORM=DISABLE_ARCHIVE_LOGGING:$disableArchiveLogging
TRANSFORM=TABLE_COMPRESSION_CLAUSE:$tableCompressionClause
"@
}
else {
  $parfile_txt = @"
JOB_NAME=impdp_$schemaDes
DIRECTORY=$directory
DUMPFILE=$dumpfile
CONTENT=$content
SQLFILE=$sqlfile
LOGFILE=$logfile
REMAP_SCHEMA=$schemaOrg`:$schemaDes
LOGTIME=ALL
"@
}

write-host "parfile is $parfile"
$parfile_txt | Out-File $parfile -encoding ascii
write-host "impdp parameter file content"
gc $parfile
impdp $cnx parfile=$parfile

if ( $playOnly -eq 'N' ) {
  Write-Output "Recompute statistics for $schemaDes"
  $sql = @"
    set timing on
    execute dbms_stats.gather_schema_stats('$schemaDes', degree=>DBMS_STATS.DEFAULT_DEGREE, cascade=>DBMS_STATS.AUTO_CASCADE, options=>'GATHER', no_invalidate=>False );
"@
  $sql | sqlplus -S $cnx
}