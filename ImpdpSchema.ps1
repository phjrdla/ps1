<#	
.SYNOPSIS
ImpdpSchema.ps1 does a Datapump import for specified instance and schema
	
.DESCRIPTION
ImpdpSchema.ps1 uses Oracle 12c Datapump impdp utility  with an expdp dump. 
ImpdpSchema.ps1 can run on the server hosting the instance or from a remote server through SQL*NET. Dumps must be available on the instance server.

.Parameter connectStr
SQL*NET string to connect to instance. Mandatory.

.Parameter schema
Schema to import

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
dump root filename. Default is expdp.

.Parameter playOnly
to test the import. No data is imported. A sql file of the dump is created. Possible values are 'Y','N'. Default is 'Y'.

.INPUTS
expdp dump

.OUTPUTS
Log file in datapump directory
SQL file in datapump directory when run with playOnly = 'Y'

.Example 
ImpdpSchema -connectStr orcl -schema scott -dumpFilename orcl_scott -playOnly n	
	
.Example
ImpdpSchema -connectStr orcl -schema scott -directory DUMPTEMP -dumpFilename orcl_scott -content all -disableArchiveLogging Y -tableCompressionClause compress -playOnly n	

#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$connectStr,
  [Parameter(Mandatory=$True) ] [string]$schema,  [string]$directory= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [string]$dumpfileName = 'expdp',
  [ValidateSet('N','Y')] [string]$disableArchiveLogging = 'Y',
  [ValidateSet('NONE','NOCOMPRESS','COMPRESS')] [string]$tableCompressionClause = 'NONE',
  [ValidateSet('Y','N')] [string]$playOnly = 'Y'
)

write-host "Parameters are :"
write-host "    connectStr is $connectStr"
write-host "        schema is $schema"
write-host "     directory is $directory"
write-host "  dumpfileName is $dumpfileName"
write-host "      playOnly is $playOnly"

$thisScript = $MyInvocation.MyCommand
write-host "ThisScript is $thisScript"
$tstamp = get-date -Format 'yyyyMMddTHHmm'

# Connection to instance
$cnx = "dp/dpclv@$connectStr"

$job_name = 'impdp_' + $schema
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
JOB_NAME=$job_name
DIRECTORY=$directory
DUMPFILE=$dumpfile
CONTENT=$content
LOGFILE=$logfile
TABLE_EXISTS_ACTION=TRUNCATE
LOGTIME=ALL
METRICS=Y
TRANSFORM=DISABLE_ARCHIVE_LOGGING:$disableArchiveLogging
TRANSFORM=TABLE_COMPRESSION_CLAUSE:$tableCompressionClause
"@
}
else {
  $parfile_txt = @"
JOB_NAME=$job_name
DIRECTORY=$directory
DUMPFILE=$dumpfile
CONTENT=$content
SQLFILE=$sqlfile
LOGFILE=$logfile
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
    set echo on
    execute dbms_stats.gather_schema_stats('$schema', degree=>DBMS_STATS.DEFAULT_DEGREE, cascade=>DBMS_STATS.AUTO_CASCADE, options=>'GATHER', no_invalidate=>False );
"@
  $sql | sqlplus -S $cnx
}
