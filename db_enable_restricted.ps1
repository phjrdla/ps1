<#	
.SYNOPSIS
db_enable_restricted invokes pl/sql procedure solife_util.enable_restricted on specified database
	
.DESCRIPTION
db_enable_restricted invokes pl/sql procedure solife_util.enable_restricted
to kill user sessions and enable restricted mode on specified database

.Parameters oracleSid
oracleSid is used to setup Oracle environment variable ORACLE_SID. 
grantTo us used to specify to which account to grant 'restricted session'
mode is used to choose the type of run, 'FALSE' for a simulation, 'TRUE' for a live run


.Example db_enable_restricted -oracleSid orasolifedev -mode 'FALSE'		
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$oracleSid,
  [Parameter(Mandatory=$True) ] [string]$grantTo,
  [Parameter(Mandatory=$True) ] [ValidateSet('TRUE','FALSE')] [string]$mode = 'false' 
)

$thisScript = $MyInvocation.MyCommand
write-host "ThisScript is $thisScript"

$env:ORACLE_SID = $oracleSid
Get-ChildItem Env:ORACLE_SID
write-host "mode is $mode"

$tstamp = get-date -Format 'yyyyMMdd-hhmmss'
write-host "time is $tstamp"

# Connect as sys
$cnx = "/ as sysdba"

# build sqlplus script
$sql = @"
set serveroutput on
execute solife_util.enable_restricted('$grantTo', $mode);
-- Return error from plsql procedure execution
exit SQL.SQLCODE
"@

# Run sqlplus script
$sql | sqlplus -S $cnx

# Catch pl/sql return code propagated to LASTEXITCODE
$SQLRC = $LASTEXITCODE
write-host "SQLRC is $SQLRC"

$EcofCode = $SQLRC
if ( $EcofCode -eq 0 ) {
  $Ecoftxt = "Success"
}
else {
  $Ecoftxt = "Suspect"
}

# Return pl/sql return code to host
exit $EcofCode
