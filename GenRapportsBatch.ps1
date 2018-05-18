<#	
.SYNOPSIS
GenRapportsBatch.ps1 generates html ouput for reports on batch jobs

.DESCRIPTION
GenRapportsBatch.ps1 generates html ouput for reports on batch jobs


.Parameters oracleSid
oracleSid is used to setup Oracle environment variable ORACLE_SID.
schema : clv61xxx schema with which to run the reports

.Example 	
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$oracleSid,
  [Parameter(Mandatory=$True) ] [string]$schema,
  [Parameter(Mandatory=$True) ] [int]$error_count_max 
)

$thisScript = $MyInvocation.MyCommand
#write-host "ThisScript is $thisScript"

$env:ORACLE_SID = $oracleSid
#Get-ChildItem Env:ORACLE_SID
#write-host "schema is $schema"
#write-host "error_count_max is $error_count_max"

$tstamp = get-date -Format 'yyyyMMdd-hhmmss'
#write-host "time is $tstamp"

# Connect as sys
$cnx = "/ as sysdba"

# build sqlplus script
$sql = @"
set serveroutput off
set heading off
set feedback off
set newpage 0
alter session set current_schema=$schema;
select noe2486 ( $error_count_max ) from dual;
-- Return error from plsql function execution
exit SQL.SQLCODE
"@

# Run sqlplus script
# [string]$code = $sql | sqlplus -S $cnx
[Int]$error_count_Sum = $sql | sqlplus -S $cnx


IF ( $error_count_Sum -gt $error_count_max ) { 
	Exit 90 
}
Else { 
	Exit 0 
}

