<#	
.SYNOPSIS
ImpdpSchema.ps1 does a parallel Datapump import in serial or parallel with a remap_schema for specified instance and schema
	
.DESCRIPTION
ImpdpSchema.ps1 uses Oracle 12c Datapump impdp utility in parallel mode with a set of p expdp dumps created by expdpSchemaP. 
ImpdpSchema.ps1 can run on the server hosting the instance or from a remote server through SQL*NET. Dumps must be available on the instance server.

.Parameter connectStr
SQL*NET string to connect to instance. Mandatory.

.Parameter schemaOrg
Schema remapped. Mandatory.

.Parameter schemaDes
Schema for remapping. Mandatory.

.Parameter parallel
number of parallel process for Datapump. Default is 4, min is 1, max is 8.
impdp runs in serial mode when parallel = 1

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
to test the import. No data is imported. A sql file of the dump is created. Possible values are 'Y','N'. Default is 'Y'.

.INPUTS
Set of p expdp dumps

.OUTPUTS
Log file in datapump directory
SQL file in datapump directory when run with playOnly = 'Y'

.Example 
ImpdpSchema -connectStr orcl -schemaOrg scott -schemaDes bernie -dumpFilename orcl_scott -playOnly n	
	
.Example
ImpdpSchema -connectStr orcl -parallel 8 -schemaOrg scott -schemaDes bernie -directory DUMPTEMP -dumpFilename orcl_scott -content all -disableArchiveLogging Y -tableCompressionClause compress -playOnly n	

#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [ValidateLength(4,12)] [ValidatePattern('^[a-zA-Z]+[a-zA-B0-9]+')] [string]$connectStr,
  [Parameter(Mandatory=$True) ] [ValidateLength(0,20)] [string]$schemaOrg,  [Parameter(Mandatory=$True) ] [ValidateLength(2,20)] [string]$schemaDes,  [ValidateRange(1,8)] [int]$parallel = 4,  [string]$directory= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [string]$dumpfileName = 'expdp',
  [ValidateSet('N','Y')] [string]$disableArchiveLogging = 'Y',
  [ValidateSet('NONE','NOCOMPRESS','COMPRESS','OLTP')] [string]$tableCompressionClause  = 'NONE',
  [ValidateSet('Y','N')] [string]$playOnly = 'Y'
)

write-host "Parameters are :"
write-host "    connectStr is $connectStr"
write-host "     schemaOrg is $schemaOrg"
write-host "     schemaDes is $schemaDes"
write-host "     directory is $directory"
write-host "  dumpfileName is $dumpfileName"
write-host "      parallel is $parallel"
write-host "      playOnly is $playOnly"

$thisScript = $MyInvocation.MyCommand
write-host "ThisScript is $thisScript"
$tstamp = get-date -Format 'yyyyMMddTHHmm'

# Connection to instance
$cnx = "dp/dpclv@$connectStr"

$job_name = 'impdp_' + $schemaDes

# dump filename when dumping in parallel
if ( $parallel -gt 1 ) {
  $dumpfile  = $dumpfileName + '_%u.dmp'
}
else {
  $dumpfile = $dumpfileName + '.dmp'
}

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
TRANSFORM=DISABLE_ARCHIVE_LOGGING:$disableArchiveLogging
"@
}

# Add PARALLEL to parameter file when needed
if ( $parallel -gt 1 ) {
  $parfile_txt = $parfile_txt + "`nPARALLEL=$parallel";
}

# ADD table compression clause 
if ( $tableCompressionClause -eq 'OLTP' ) {
  $parfile_txt = $parfile_txt + "`nTRANSFORM=TABLE_COMPRESSION_CLAUSE:`"ROW STORE COMPRESS ADVANCED`""
}
else {
  $parfile_txt = $parfile_txt + "`nTRANSFORM=TABLE_COMPRESSION_CLAUSE:$tableCompressionClause"
}

$parfile_txt | Out-File $parfile -encoding ascii
write-host "impdp parameter file content"
gc $parfile
#impdp $cnx parfile=$parfile

if ( $playOnly -eq 'N' ) {
  Write-Output "Recompute statistics for $schemaDes"
  $sql = @"
    set timing on
    set echo on
    execute dbms_stats.gather_schema_stats('$schemaDes', degree=>DBMS_STATS.DEFAULT_DEGREE, cascade=>DBMS_STATS.AUTO_CASCADE, options=>'GATHER AUTO', no_invalidate=>False );
"@
  $sql | sqlplus -S $cnx
}
