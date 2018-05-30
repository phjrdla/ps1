<#	
.SYNOPSIS
expdpSchemaP.ps1 does a parallel Datapump export for specified instance and schema
	
.DESCRIPTION
expdpSchemaP.ps1 uses Oracle 12c Datapump export utility expdp in parallel mode. Produces p dumpfiles p being the number of parallel processes. 
expdpSchemaP.ps1 can run on the server hosting the instance or from a remote server through SQL*NET

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
Level of export dumps compression. Possible values are 'LOW','MEDIUM','HIGH'. Default is 'MEDIUM'.

.Parameter dumpfileName
dumps root filename. Default is expdp.

.Parameter estimateOnly
Estimates the datapump size. No data is dumped. Possible values are 'Y','N'. Default is 'Y'.

.Example 
expdpSchemaP -connectStr orcl -schema scott -dumpfileName orcl_scott -estimateOnly Y

.Example
expdpSchemaP -connectStr orcl -parallel 8 -schema scott -directory DUMPTEMP -dumpFilename orcl_scott -content all -compression high -estimateOnly n	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,
  [Parameter(Mandatory=$True) ] [string]$schema,  [ValidateRange(1,8)] [int]$parallel = 4,  [string]$directoryName= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [ValidateSet('LOW','MEDIUM','HIGH')] [string]$compressionAlgorithm = 'MEDIUM',
  [string]$dumpfileName = 'expdp',
  [ValidateSet('Y','N')] [string]$estimateOnly = 'Y'
)

##########################################################################################################
function getDirectoryPath {
  param( $cnx, $directoryName)


  $thisFunction = '{0}' -f $MyInvocation.MyCommand
  #write-output "`nThis is function $thisFunction"
  #write-output "`nFind DATAPUMP directory path"
  #Write-Output "`ndirectoryName is $directoryName"

  $sql = @"
set linesize 80
set pages 0
set feedback off
set heading off
set trimspool on
col directory_path format a80 trunc
select directory_path
  from dba_directories
 where directory_name = upper(`'$directoryName`')
/
"@
[string]$paf=($sql | sqlplus -S $cnx)
return $paf
}
##########################################################################################################

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
$cnx = "dp/dpclv@$connectStr"

<#
# Find DATAPUMP directory path 
[string]$directoryPath = getdirectoryPath $cnx $directoryName
Write-Host ("`ndirectoryPath is $directoryPath")

if ( $directoryPath.Length -eq 0 ) {
   Write-Host ("No directoryPath foind for $directoryName")
   exit
}
#>

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

write-host "parfile is $parfile"
$parfile_txt | Out-File $parfile -encoding ascii
Write-Host "`nexpdp parameter file content"
gc $parfile

expdp $cnx parfile=$parfile 

#expdp `'$cnx`' parfile=$parfile 2>&1 | % { "$_" }
