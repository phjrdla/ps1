<#	
.SYNOPSIS
ExpdpFullP.ps1 does a parallel full Datapump export for specified instance and schema
	
.DESCRIPTION
ExpdpFullP.ps1 uses Oracle 12c Datapump expdp utility in parallel mode. Produces p dumps, p being the parallel parameter. 
ExpdpFullP.ps1 can run on the server hosting the instance or from a remote server through SQL*NET
Should be run on instance host, as sys, if a coherent expdp dump is necessary. 

.Parameter connectStr
SQL*NET string to connect to instance. Mandatory.

.Parameter connectAsSys
to connect 'as SYS'. Only when script runs on database host. Possible values are 'Y','N'. Default is 'Y'. Mandatory.

.Parameter coherent
To ensure expdp dump is coherent. Possible values are 'Y','N'. Default is 'Y'. 

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
Estimates the expdp dumps size. No data is dumped. Possible values are 'Y','N'. Default is 'Y'.

.INPUTS

.OUTPUTS
Log file in datapump directory
Set of p expdp dumps

.Example 
ExpdpFullP -connectStr orcl -connectAsSys N -coherent N -dumpfileName orcl_full -estimateOnly N

.Example 
ExpdpFullP -connectStr orcl -connectAsSys Y -coherent Y -dumpfileName orcl_full -estimateOnly N

.Example
ExpdpFullP -connectStr orcl -connectAsSys Y -coherent Y -parallel 8 -directory DUMPTEMP -dumpFilename orcl_full -content all -compression high -estimateOnly n	

#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,  [int]$parallel = 4,  [Parameter(Mandatory=$True) ] [string]$directoryName= 'DATAPUMP',
  [Parameter(Mandatory=$True) ] [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [ValidateSet('LOW','MEDIUM','HIGH')] [string]$compressionAlgorithm = 'MEDIUM',
  [Parameter(Mandatory=$True) ] [string]$dumpfileName = 'expdp',
  [ValidateSet('Y','N')] [string]$coherent = 'Y',
  [ValidateSet('Y','N')] [string]$estimateOnly = 'Y',
  [Parameter(Mandatory=$True) ] [ValidateSet('Y','N')] [string]$connAsSys = 'N'
)

write-host "Parameters are :"
write-host "    connectStr is $connectStr"
write-host " directoryName is $directoryName"
write-host "  dumpfileName is $dumpfileName"
write-host "      parallel is $parallel"
write-host "       content is $content"
write-host "      coherent is $coherent"
write-host "  estimateOnly is $estimateOnly"
write=host "  connectAsSys is $connectAsSys"

$thisScript = $MyInvocation.MyCommand

write-host "ThisScript is $thisScript"
$tstamp = get-date -Format 'yyyyMMddTHHmm'

# Define connect string to database
if ( $connAsSys -eq 'Y' ) {
  $env:ORACLE_SID = $connectStr
  $cnx = '''/ as sysdba'''
}
else {
  $cnx = "dp/dpclv@$connectStr"
}

$job_name     = 'expdpfull_' + $connectStr
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
LOGFILE=$logfile
REUSE_DUMPFILES=Y
FULL=Y
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
LOGFILE=$logfile
FULL=Y
KEEP_MASTER=NO
METRICS=Y
LOGTIME=ALL
ESTIMATE_ONLY=YES
"@
}

if ( $coherent -eq 'Y' ) {
  $parfile_txt = $parfile_txt + "`nFLASHBACK_TIME=systimestamp"
}

$parfile_txt | Out-File $parfile -encoding ascii
Write-Host "`nexpdp parameter file content"
gc $parfile
expdp "$cnx" parfile=$parfile

#expdp 2>&1 `'$cnx`' parfile=$parfile | %{ "$_" }
