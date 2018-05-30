<#
.SYNOPSIS
ImpdpFullP.ps1 does a Datapump full import in parallel for specified instance.
	
.DESCRIPTION
ImpdpFullP.ps1 uses Oracle 12c Datapump impdp utility  with a set of p expdp dumps.
ImpdpFullP.ps1 can run on the server hosting the instance or from a remote server through SQL*NET. Dumps must be available on the instance server.

.Parameter connectStr
SQL*NET string to connect to instance. Mandatory.

.Parameter connectAsSys
to connect 'as SYS'. Only when script runs on database host. Possible values are 'Y','N'. Default is 'Y'. Mandatory.

.Parameter parallel
number of parallel process for Datapump. Default is 4, min is 1, max is 8.

.Parameter directory
Datapump directory. Default is DATAPUMP.

.Parameter content
Content to import. Possible values are 'ALL','DATA_ONLY','METADATA_ONLY'. Default is 'ALL'.

.Parameter disableArchiveLogging
To disable archive logging while import. Possible values are 'Y','N'. Default is 'Y'. 
Parameter has no effect if instance runs in'force logging' mode like Dataguard instances.

.Parameter tableCompressionClause
to compress tables being imported. Possible values are 'NONE','NOCOMPRESS','COMPRESS'. Default is 'NONE'.

.Parameter dumpfileName
dumps root filename. Default is expdp.

.Parameter playOnly
to test the import. No data is imported. A sql file of the dumps is created. Possible values are 'Y','N'. Default is 'Y'.

.INPUTS
Set of expdp dumps

.OUTPUTS
Log file in datapump directory
SQL file in datapump directory when run with playOnly = 'Y'

.Example 
ImpdpFullP -connectStr orcl -dumpFilename orcl_full -playOnly n	
	
.Example
ImpdpFullP -connectStr orcl -directory DUMPTEMP -dumpFilename orcl_full -content all -disableArchiveLogging Y -tableCompressionClause compress -playOnly n	
	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,  [string]$directory= 'DATAPUMP',
  [string]$dumpfileName = 'expdp',
  [ValidateSet('N','Y')] [string]$disableArchiveLogging = 'Y',
  [ValidateSet('NONE','NOCOMPRESS','COMPRESS')] [string]$tableCompressionClause = 'NONE',
  [string]$playOnly = 'Y',
  [Parameter(Mandatory=$True) ] [ValidateSet('Y','N')] [string]$connAsSys = 'N'
)

write-host "Parameters are :"
write-host "    connectStr is $connStr"
write-host "     directory is $directory"
write-host "  dumpfileName is $dumpfileName"
write-host "      playOnly is $playOnly"

write-host "ThisScript is $thisScript"
$tstamp = get-date -Format 'yyyyMMddTHHmm'
$cnx = "dp/dpclv@$connectStr"

$job_name      = 'impdpfull_' + $connStr
$dumpfile      = $dumpfileName + '.dmp'
$logfile       = $dumpfileName + '.txt'
$parfile       = $dumpfileName + '.par'
$sqlfile       = $dumpfileName + '.sql'

Write-Output "$dumpfile"
write-output "job_name is $job_name"

If (Test-Path $parfile){
  Remove-Item $parfile
  Write-Host "Removed $parfile"
}

if ( $playOnly -eq 'N' ) {
  $parfile_txt = @"
JOB_NAME=$job_name
FULL=Y
PARALLEL=$parallel
DIRECTORY=$directory
DUMPFILE=$dumpfile
LOGFILE=$logfile
FULL=Y
TABLE_EXISTS_ACTION=TRUNCATE
TRANSFORM=DISABLE_ARCHIVE_LOGGING:$disableArchiveLogging
TRANSFORM=TABLE_COMPRESSION_CLAUSE:$tableCompressionClause
LOGTIME=ALL
METRICS=Y
"@
}
else {
  $parfile_txt = @"
JOB_NAME=$job_name
FULL=Y
PARALLEL=$parallel
DIRECTORY=$directory
DUMPFILE=$dumpfile
SQLFILE=$sqlfile
LOGFILE=$logfile
FULL=Y
LOGTIME=ALL
"@
}

$parfile_txt | Out-File $parfile -encoding ascii
write-host "impdp parameter file content"
gc $parfile
impdp $cnx parfile=$parfile

if ( $playOnly -eq 'N' ) {
  Write-Output "Recompute statistics for $schema"
  $sql = @"
    set timing on
    execute dbms_stats.gather_data_stats(degree=>DBMS_STATS.DEFAULT_DEGREE, cascade=>DBMS_STATS.AUTO_CASCADE, options=>'GATHER', no_invalidate=>False );
"@
  $sql | sqlplus -S $cnx
}
