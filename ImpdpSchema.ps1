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
  [Parameter(Mandatory=$True) ] [string]$oracleSid,
  [Parameter(Mandatory=$True) ] [string]$schema,  [string]$directory= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [string]$dumpfileName = 'expdp',
  [string]$playOnly = 'Y'
)

write-host "Parameters are :"
write-host "     oracleSid is $oracleSid"
write-host "        schema is $schema"
write-host "     directory is $directory"
write-host "  dumpfileName is $dumpfileName"
write-host "      playOnly is $playOnly"

$thisSc
write-host "ThisScript is $thisScript"

$env:ORACLE_SID = $oracleSid
 
$tstamp = get-date -Format 'yyyyMMdd-hhmmss'

# Set-Location -Path D:\solife-DB\pb

$cnx = "'/ as sysdba'"

$job_name = $schemaDes
$dumpfile = $dumpfileName + '.dmp'
$logfile  = $dumpfileName + '.txt'
$parfile  = $dumpfileName + '.par'
$sqlfile  = $dumpfileName + '.sql'

Write-Output "$dumpfile"

If (Test-Path $parfile){
  Remove-Item $parfile
  Write-Host "Removed $parfile"
}

if ( $playOnly -eq 'N' ) {
  $parfile_txt = @"
JOB_NAME=impdp_$schema
DIRECTORY=$directory
DUMPFILE=$dumpfile
CONTENT=$content
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
CONTENT=$content
SQLFILE=$sqlfile
LOGFILE=$logfile
SCHEMAS=$schema
LOGTIME=ALL
"@
}

write-host "parfile is $parfile"

$parfile_txt | Out-File $parfile -encoding ascii
impdp $cnx parfile=$parfile
