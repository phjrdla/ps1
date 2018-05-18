function getTrigrammes {
  param ( $userCsvFile )

  $thisFunction = '{0}' -f $MyInvocation.MyCommand
  write-output `n"This is function $thisFunction"
  write-host "userCsvfile is $userCsvFile"

  # Load csv file
  $csvImport = import-Csv $userCsvFile 
  $trigrammes = ''
  # Loop on records 
  ForEach ($item in $csvImport) {
    #$first_name = $item.first_name
    #$last_name  = $item.last_name
    $trigramme  = $item.trigramme
    $trigrammes = $trigrammes + ':' + $trigramme
  }
  $trigrammes.Substring(1)
}

getTrigrammes trigrammes.csv