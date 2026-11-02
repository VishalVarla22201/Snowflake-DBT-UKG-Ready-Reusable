# Export a PNG preview of the Diagram sheet (read-only copy of the workbook; Excel opens briefly).
#   powershell -ExecutionPolicy Bypass -File docs	ools\preview_erd.ps1 -Workbook docsRD_UKG_Ready.xlsx -Png preview.png
param([string]$Workbook, [string]$Png, [string]$Sheet = "Diagram")
$ErrorActionPreference = "Stop"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $true
$xl.DisplayAlerts = $false
try {
    $wb = $xl.Workbooks.Open((Resolve-Path $Workbook).Path, 0, $true)   # read-only
    $ws = $wb.Worksheets.Item($Sheet)
    $ws.Activate()
    $maxR = 1; $maxC = 1; $right = 0; $bottom = 0
    foreach ($s in $ws.Shapes) {
        $b = $s.BottomRightCell
        if ($b.Row -gt $maxR) { $maxR = $b.Row }
        if ($b.Column -gt $maxC) { $maxC = $b.Column }
        if ($s.Left + $s.Width -gt $right) { $right = $s.Left + $s.Width }
        if ($s.Top + $s.Height -gt $bottom) { $bottom = $s.Top + $s.Height }
    }
    $rng = $ws.Range($ws.Cells(1, 1), $ws.Cells($maxR + 2, $maxC + 2))
    $rng.CopyPicture(1, 2)
    $co = $ws.ChartObjects().Add(0, 0, $rng.Width, $rng.Height)
    $co.Chart.ChartArea.Format.Line.Visible = 0
    $co.Chart.Paste()
    [void]$co.Chart.Export($Png, "PNG")
    $co.Delete()
    $wb.Close($false)
    "shapes: $($ws.Shapes.Count); extent: $([int]$right) x $([int]$bottom) pt; exported $Png"
}
finally {
    $xl.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
