<#	
.SYNOPSIS
ExpdpFullP.ps1 does a parallel Datapump export for specified database and schema
	
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

.Example ExpdpSchema.ps1 -oracleSid orasolifefev -schema clv61dev -directory datatemp -dumpfileName dev -estimateOnly Y	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,  [int]$parallel = 4,  [string]$directoryName= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [ValidateSet('LOW','MEDIUM','HIGH')] [string]$compressionAlgorithm = 'MEDIUM',
  [string]$dumpfileName = 'expdp',
  [ValidateSet('Y','N')] [string]$coherent = 'Y',
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
write-host " directoryName is $directoryName"
write-host "  dumpfileName is $dumpfileName"
write-host "      parallel is $parallel"
write-host "       content is $content"
write-host "      coherent is $coherent"
write-host "  estimateOnly is $estimateOnly"

$thisScript = $MyInvocation.MyCommand

write-host "ThisScript is $thisScript"
$tstamp = get-date -Format 'yyyyMMddTHHmm'
$cnx = "dp/dpclv@$connectStr"


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

#if ( $coherent -eq 'Y' ) {
  "FLASHBACK_TIME=systimestamp" >> $parfile_txt "FLASHBACK_TIME=systimestamp"
#}

write-host "parfile is $parfile"
$parfile_txt | Out-File $parfile -encoding ascii
Write-Host "`nexpdp parameter file content"
gc $parfile
#expdp $cnx parfile=$parfile

#expdp 2>&1 `'$cnx`' parfile=$parfile | %{ "$_" }
