<#	
.SYNOPSIS
ExpdpSchemaP.ps1 does a parallel Datapump export for specified instance and schema
	
.DESCRIPTION
ExpdpSchemaP.ps1 uses Oracle 12c Datapump expdp utility in parallel mode. Produces p dumps, p being the parallel parameter. 
ExpdpSchemaP.ps1 can run on the server hosting the instance or from a remote server through SQL*NET

.Parameter connectStr
SQL*NET string to connect to instance. Mandatory.

.Parameter schema
Schema to dump. Mandatory.

.Parameter parallel
number of parallel process for Datapump. Default is 4, min is 1, max is 8.

.Parameter directory
Datapump directory. Default is DATAPUMP.

.Parameter content
Content to export. Possible values are 'ALL','DATA_ONLY','METADATA_ONLY'. Default is 'ALL'.

.Parameter compressionAlgorithm
Level of expdp dumps compression. Possible values are 'BASIC', 'LOW','MEDIUM','HIGH'. Default is 'MEDIUM'.

.Parameter dumpfileName
dumps root filename. Default is expdp.

.Parameter estimateOnly
Estimates the dump size. No data is dumped. Possible values are 'Y','N'. Default is 'Y'.

.INPUTS

.OUTPUTS
Log file in datapump directory
Set of p expdp dumps

.Example 
ExpdpSchemaP -connectStr orcl -schema scott -dumpfileName orcl_scott -estimateOnly Y

.Example
ExpdpSchemaP -connectStr orcl -parallel 8 -schema scott -directory DUMPTEMP -dumpFilename orcl_scott -content all -compression high -estimateOnly n	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,
  [Parameter(Mandatory=$True) ] [string]$schema,  [ValidateRange(1,8)] [int]$parallel = 4,  [string]$directoryName= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [ValidateSet('LOW','MEDIUM','HIGH')] [string]$compressionAlgorithm = 'MEDIUM',
  [string]$dumpfileName = 'expdp',
  [ValidateSet('Y','N')] [string]$estimateOnly = 'Y'
)

write-host "Parameters are :"
write-host "    connectStr is $connectStr"
write-host "        schema is $schema"
write-host " directoryName is $directoryName"
write-host "  dumpfileName is $dumpfileName"
write-host "      parallel is $parallel"
write-host "       content is $content"
write-host "  estimateOnly is $estimateOnly"

$thisScript = $MyInvocation.MyCommand
write-host "ThisScript is $thisScript"
$tstamp = get-date -Format 'yyyyMMddTHHmm'

# Connection to instance
$cnx = "dp/dpclv@$connectStr"

$job_name     = 'expdp_' + $schema
$dumpfileName = $dumpfileName + '_' + "$tstamp"
$dumpfile     = $dumpfileName + '_%u.dmp'
$logfile      = $dumpfileName + '.txt'
$parfile      = $dumpfileName + '.par'

Write-Output "$dumpfile"
Write-Output "$parfile"
Write-Output "job_name is $job_name"

If (Test-Path $parfile){
  Remove-Item $parfile
  Write-Host "Removed $parfile"
}

if ( $estimateOnly -eq 'N' ) {
  $parfile_txt = @"
JOB_NAME=$job_name
DIRECTORY=$directoryName
DUMPFILE=$dumpfile
PARALLEL=$parallel
CONTENT=$CONTENT
COMPRESSION=ALL
COMPRESSION_ALGORITHM=$compressionAlgorithm
FLASHBACK_TIME=systimestamp
LOGFILE=$logfile
REUSE_DUMPFILES=Y
SCHEMAS=$schema
LOGTIME=ALL
KEEP_MASTER=NO
METRICS=Y
"@
}
else {
  $parfile_txt = @"
JOB_NAME=$job_name
DIRECTORY=$directoryName
PARALLEL=$parallel
COMPRESSION=ALL
FLASHBACK_TIME=systimestamp
LOGFILE=$logfile
SCHEMAS=$schema
KEEP_MASTER=NO
METRICS=Y
LOGTIME=ALL
ESTIMATE_ONLY=YES
"@
}

$parfile_txt | Out-File $parfile -encoding ascii
Write-Host "`nexpdp parameter file content"
gc $parfile

expdp $cnx parfile=$parfile 

#expdp `'$cnx`' parfile=$parfile 2>&1 | % { "$_" }
