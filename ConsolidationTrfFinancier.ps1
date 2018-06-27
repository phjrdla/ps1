<#	
.SYNOPSIS
ConsolidationTrfFinancier.ps1 generates html ouput for reports on batch jobs

.DESCRIPTION
GenRapportsBatch.ps1 generates html ouput for reports on batch jobs


.Parameter oracleSid
oracleSid is used to setup Oracle environment variable ORACLE_SID.

.Parameter schema
schema : clv61xxx schema with which to run the reports

.Example  ConsolidationTrfFinancier -oracleSid orlsol08 -schema clv61in1	-reportOut d:\solife-db\html
#>

[CmdletBinding()] param(
  [Parameter(Mandatory=$True) ] [string]$oracleSid,
  [Parameter(Mandatory=$True) ] [string]$schema,
  [string]$reportDir = 'd:\solife-db\cvs'
)

##########################################################################################################
function consolidationTRFfinancier_Detailed  {
  param ( $cnx, $schema, $reportOut )

  $thisFunction = '{0}' -f $MyInvocation.MyCommand
  #write-output `n"This is function $thisFunction"
  #write-output "`List description for all batches"

  # Corruped blocks
  $sql = @"
set termout off
set echo off
set feedback off
alter session set current_schema=$schema
/
set feedback on
set pagesize 50
ttitle '$reportOut'
select 
      acc.ACC_NUMBER AS NOTRO_ACCOUNT, 
      m.AMOUNT as AMOUNT_VALUE,cu.ISO_CODE as CURRENCY, Case m.CRE_DEB when 1 then 'C' when -1 then 'D' END as DEBIT_CREDIT, 
      fo.POLICY_NUMBER as POLICY_NUMBER,
      ea.account_number as EXTERNAL_ACCOUNT,
      BT.EXTERNAL_ID
from CONSOLIDATED_MOVEMENT cm
join movement m on m.CONSOLIDATED_MOVEMENT_OID = cm.oid
join SUB_POSITION sp on sp.oid = m.SUB_POSITION_OID
join position p on p.oid = sp.POSITION_OID
join account acc on acc.oid = p.ACCOUNT_OID
join currency cu on cu.oid = cm.CURRENCY_OID
join BUSINESS_TRANSACTION bt on bt.oid =cm.BUSINESS_TRANSACTION_OID
inner join BUSINESS_TRANSACTION_TYPE BTT on bt.TRANSACTION_TYPE_OID = BTT.OID
join EXTERNAL_ACCOUNT ea on ea.oid = cm.EXTERNAL_ACCOUNT_OID
join ACCOUNTING_TRANSACTION atr on atr.oid = m.ACCOUNTING_TRANSACTION_OID
left join ACCOUNTABLE_IMPL ai on ai.oid = atr.ACCOUNTABLE_OID
left join client_order co on co.oid = atr.ACCOUNTABLE_OID
join FINANCIAL_OPERATION fo on (fo.EXTERNAL_ID = ai.GROUP_REF or fo.EXTERNAL_ID = co.GROUP_REF)
where BTT.HARD_TYPE = 79 AND BT.TRANSACTION_STATE = 8
order by BT.EXTERNAL_ID desc, amount asc, debit_credit asc
/
"@

  # Run sqlplus script
 $sql | sqlplus -S -MARKUP "HTML ON" $cnx

}
##########################################################################################################

##########################################################################################################
function consolidationTRFfinancier_Global  {
  param ( $cnx, $schema, $reportOut )

  $thisFunction = '{0}' -f $MyInvocation.MyCommand
  #write-output `n"This is function $thisFunction"
  #write-output "`List description for all batches"

  # Corruped blocks
  $sql = @"
set termout off
set echo off
set feedback off
alter session set current_schema=$schema
/
set feedback on
set pagesize 50
ttitle '$reportOut'
select 
    payer.account_number as SOURCE_ACCOUNT, 
    payee.account_number as TARGET_ACCOUNT, 
    eod.QUANTITY_OR_AMOUNT as amount, 
    co.EXECUTION_DATE as EXECUTION_DATE, 
    Case eod.DISPLAY when '1' then 'selected' else null END as SELECTED,
    BT.EXTERNAL_ID
from BUSINESS_TRANSACTION bt
join abstract_business_extension abe on abe.GENERIC_TRANSACTION_OID = bt.oid
join abstract_pc_wrapper apw on apw.CAPITAL_EXTENSION_OID = abe.oid
join GLOBAL_OPERATION go on go.GLOBAL_OP_STARTABLE_OID = apw.oid
join CUSTODIAN_INSTRUCTION ci on ci.GLOBAL_OPERATION_OID = go.oid
join CUSTODIAN_ORDER co on co.oid = ci.ORDER_OID
join ELEMENTARY_OPERATION_DETAIL eod on eod.ELEMENTARY_OPERATION_OID = ci.oid and eod.cid = 2226 -- CustodianInstructionDetail
join EXTERNAL_ACCOUNT payer on payer.oid = eod.PAYER_EXTERNAL_ACCOUNT_OID
join EXTERNAL_ACCOUNT payee on payee.oid = eod.PAYEE_EXTERNAL_ACCOUNT_OID
inner join BUSINESS_TRANSACTION_TYPE BTT on bt.TRANSACTION_TYPE_OID = BTT.OID
where
    BTT.HARD_TYPE = 79 AND BT.TRANSACTION_STATE = 8
and eod.AMOUNT_TYPE_CODEID not in (562,563)
order by external_id
/
"@

  # Run sqlplus script
 $sql | sqlplus -S -MARKUP "HTML ON" $cnx

}
##########################################################################################################

##########################################################################################################
function getReportName {
  param( $reportDir, $schema, $reportName, $timeStamp)
  $reportOut = $reportDir + '\' + $schema + '_' + $reportName + '_'  + $tstamp + '.html' 
  return $reportOut
}
##########################################################################################################

$thisScript = $MyInvocation.MyCommand
write-host "ThisScript is $thisScript"

$env:ORACLE_SID = $oracleSid
#Get-ChildItem Env:ORACLE_SID
write-host "schema is $schema"

# Check directory for reports exists
if ( ! (Test-Path $reportDir) ) {
  write-host "Please create directory $reportDir for reports"
  exit 1
}

$tstamp = get-date -Format 'yyyyMMddThhmmss'
#write-host "time is $tstamp"

# Connect as sys
$cnx = '/ as sysdba'

$reportOut = getReportName $reportDir $schema 'ListBatches' $tstamp 
write-host "$reportOut"
consolidationTRFfinancier_Detailed $cnx $schema $reportOut >  $reportOut

$reportOut = getReportName $reportDir $schema 'Valuation' $tstamp 
write-host "$reportOut"
consolidationTRFfinancier_Global $cnx $schema $reportOut >  $reportOut

exit 0
