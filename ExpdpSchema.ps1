<#	
.SYNOPSIS
ExpdpSchema.ps1 does a parallel Datapump export for specified database and schema
	
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
  [Parameter(Mandatory=$True) ] [string]$oracleSid,
  [Parameter(Mandatory=$True) ] [string]$schema,  [string]$directoryName= 'DATAPUMP',
  [ValidateSet('ALL','DATA_ONLY','METADATA_ONLY')] [string]$content = 'ALL',
  [string]$dumpfileName = 'expdp',
  [string]$estimateOnly = 'Y',
  [string]$zipIt = 'N'
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
write-host "     oracleSid is $oracleSid"
write-host "        schema is $schema"
write-host " directoryName is $directoryName"
write-host "  dumpfileName is $dumpfileName"
write-host "       content is $content"
write-host "  estimateOnly is $estimateOnly"
write-host "         zipIt is $zipIt"

$thisScript = $MyInvocation.MyCommand

write-host "ThisScript is $thisScript"

$env:ORACLE_SID = $oracleSid
 
$tstamp = get-date -Format 'yyyyMMdd-hhmmss'

# Set-Location -Path D:\solife-DB\pb

$cnx = '/ as sysdba'

# Find DATAPUMP directory path 
[string]$directoryPath = getdirectoryPath $cnx $directoryName
Write-Host ("`ndirectoryPath is $directoryPath")

if ( $directoryPath.Length -eq 0 ) {
   Write-Host ("No directoryPath foind for $directoryName")
   exit
}

$job_name      = $schema
$dumpfile      = $dumpfileName + '.dmp'
$dumpfiles2zip = $directoryPath + '\' +$dumpfileName + '.dmp'
$zipfile       = $directoryPath + '\' + $dumpfileName + '.zip'
$logfile       = $dumpfileName + '.txt'
$parfile       = $directoryPath + '\' + $dumpfileName + '.par'

Write-Output "$dumpfile"
Write-Output "$dumpfiles2zip"
Write-Output "$zipfile"
Write-Output "$parfile"

If (Test-Path $parfile){
  Remove-Item $parfile
  Write-Host "Removed $parfile"
}

if ( $estimateOnly -eq 'N' ) {
  $parfile_txt = @"
JOB_NAME=$job_name
DIRECTORY=$directoryName
DUMPFILE=$dumpfile
CONTENT=$CONTENT
COMPRESSION=ALL
LOGFILE=$logfile
REUSE_DUMPFILES=Y
SCHEMAS=$schema
LOGTIME=ALL
KEEP_MASTER=NO
METRICS=N
"@
}
else {
  $parfile_txt = @"
JOB_NAME=$job_name
DIRECTORY=$directoryName
COMPRESSION=ALL
LOGFILE=$logfile
SCHEMAS=$schema
KEEP_MASTER=NO
METRICS=N
LOGTIME=ALL
ESTIMATE_ONLY=YES
"@
}

write-host "parfile is $parfile"
$parfile_txt | Out-File $parfile -encoding ascii
expdp `'$cnx`' parfile=$parfile
#expdp 2>&1 `'$cnx`' parfile=$parfile | %{ "$_" }

if ( $zipIt -eq 'Y' ) {
  If ( Test-Path $directoryPath\$dumpfile2zip ) { 
    write-host "Dump file set is zipped"
    zip -mv $zipfile $dumpfiles2zip
  }
}
