$block = {
    Param([string] $file)
    "[Do something]"
    Write-Host "this iz file $file"
    $cnx = 'clv61re7/CLV_61_RE7@orlsol05'
    $fin = split-path -path $file -Leaf
    $res = sqlplus $cnx @d:\solife-db\scripts\RUNCLV-209V2.sql $fin
    write-host $res
}

# Collect filenames
$files = Get-ChildItem u:\mycsv\splitlog*txt

#Remove all jobs
Get-Job | Remove-Job
$MaxThreads = 8

#Start the jobs. Max 4 jobs running simultaneously.
foreach($file in $files){
    While ($(Get-Job -state running).count -ge $MaxThreads){
        Start-Sleep -Milliseconds 5000
    }
    Start-Job -Scriptblock $Block -ArgumentList $file
}

#Wait for all jobs to finish.
While ($(Get-Job -State Running).count -gt 0){
    start-sleep 1
}

#Get information from each job.
foreach($job in Get-Job){
    $info= Receive-Job -Id ($job.Id)
}
#Remove all jobs created.
Get-Job | Remove-Job





