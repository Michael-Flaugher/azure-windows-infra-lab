# health-check.ps1

$timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$reportFile  = "C:\HealthCheck\health-report.txt"
$services    = @("ADWS", "DNS", "Netlogon", "W32Time")
$diskWarning = 20
$report      = @()

$report += "============================="
$report += " Server Health Check Report"
$report += " $timestamp"
$report += "============================="
$report += ""

# Disk space
$report += "DISK SPACE"
$report += "----------"
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $total = $_.Used + $_.Free
    if ($total -gt 0) {
        $freePct = [math]::Round(($_.Free / $total) * 100, 1)
        $status  = if ($freePct -lt $diskWarning) { "WARNING" } else { "OK" }
        $report += "  Drive $($_.Name): $freePct% free [$status]"
    }
}
$report += ""

# Services
$report += "SERVICES"
$report += "--------"
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        $status = if ($s.Status -eq "Running") { "OK" } else { "WARNING" }
        $report += "  $svc`: $($s.Status) [$status]"
    } else {
        $report += "  $svc`: NOT FOUND"
    }
}
$report += ""

# System errors last 24 hours
$report += "SYSTEM ERRORS (last 24 hours)"
$report += "------------------------------"
$errors = Get-WinEvent -FilterHashtable @{
    LogName   = "System"
    Level     = 1, 2
    StartTime = (Get-Date).AddHours(-24)
} -ErrorAction SilentlyContinue
$report += "  Count: $($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | Select-Object -First 5 | ForEach-Object {
        $report += "  [$($_.TimeCreated)] $($_.Message.Split([char]10)[0])"
    }
}
$report += ""
$report += "============================="
$report += ""

$report | Out-File -FilePath $reportFile -Append -Encoding UTF8
