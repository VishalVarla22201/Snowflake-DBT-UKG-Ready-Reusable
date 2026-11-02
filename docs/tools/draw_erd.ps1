# Draw (or update) the ER diagram on the "Diagram" sheet of the ERD workbook with native Excel shapes.
#
#   powershell -ExecutionPolicy Bypass -File docs\tools\draw_erd.ps1 -Workbook docs\ERD_UKG_Ready.xlsx -Spec spec.json
#
# Spec: see erd_layout.py (run it first so every table has x, y, w, h).
# One rectangle per table, named tbl_<TABLE>; one elbow connector per relationship, named
# rel_<PARENT>__<CHILD>__<COLUMN>, glued to the table shapes so the lines follow when a table is moved.
# Re-running is safe: existing tables keep the position and size the user gave them, only their text and
# colours are refreshed; tables no longer in the spec are deleted; connectors are rebuilt.
# If the spec relationships carry parent_column, basis, confidence and notes, the "Relationships" sheet is
# synced too (rows added, removed and rewritten; formatting of the existing rows is kept).
#
# -Dump prints the tables (name and text lines) and connector names currently on the sheet as JSON and
# changes nothing, so a caller can compare it with what the code says before deciding to redraw.
#
# IMPORTANT: never open and save this workbook with openpyxl: it drops Excel shapes. Edit it only through Excel.
# Needs Excel on this machine (COM). Optionally writes a PDF preview of the sheet with -PreviewPdf.
param(
    [Parameter(Mandatory = $true)][string]$Workbook,
    [string]$SpecPath = "",
    [string]$Sheet = "Diagram",
    [string]$PreviewPdf = "",
    [switch]$Dump
)
$ErrorActionPreference = "Stop"
if (-not $Dump) {
    if (-not $SpecPath) { throw "-SpecPath is required unless -Dump is used" }
    $spec = Get-Content -Raw -Encoding UTF8 $SpecPath | ConvertFrom-Json
}

function RGBc([int]$r, [int]$g, [int]$b) { return $r + 256 * $g + 65536 * $b }
$palette = @{
    DIM     = @{ line = (RGBc 47 93 138);  fill = (RGBc 234 241 248) }
    FACT    = @{ line = (RGBc 196 98 45);  fill = (RGBc 252 238 229) }
    MAPPING = @{ line = (RGBc 94 107 115); fill = (RGBc 238 240 241) }
}
$ink = RGBc 34 34 34
$grey = RGBc 85 85 85

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
    if ($Dump) {
        $wb = $xl.Workbooks.Open((Resolve-Path $Workbook).Path, 0, $true)   # read-only
        $ws = $wb.Worksheets.Item($Sheet)
        $tables = @(); $connectors = @()
        foreach ($s in $ws.Shapes) {
            if ($s.Name -like "tbl_*") {
                $tables += [pscustomobject]@{ name = $s.Name.Substring(4); lines = @($s.TextFrame2.TextRange.Text -split "
||
") }
            }
            elseif ($s.Name -like "rel_*") { $connectors += $s.Name }
        }
        $wb.Close($false)
        [pscustomobject]@{ tables = $tables; connectors = $connectors } | ConvertTo-Json -Depth 5
        return
    }
    $wb = $xl.Workbooks.Open((Resolve-Path $Workbook).Path)
    $ws = $wb.Worksheets.Item($Sheet)

    # connectors are rebuilt; tables that left the spec are removed
    $keep = @($spec.tables | ForEach-Object { "tbl_" + $_.name })
    for ($i = $ws.Shapes.Count; $i -ge 1; $i--) {
        $s = $ws.Shapes.Item($i)
        if ($s.Name -like "rel_*") { $s.Delete() }
        elseif ($s.Name -like "tbl_*" -and ($keep -notcontains $s.Name)) { $s.Delete() }
    }

    $byName = @{}
    foreach ($s in $ws.Shapes) { $byName[$s.Name] = $s }

    foreach ($t in $spec.tables) {
        $name = "tbl_" + $t.name
        $c = $palette[[string]$t.kind]
        $shape = $byName[$name]
        if (-not $shape) {
            $shape = $ws.Shapes.AddShape(1, [double]$t.x, [double]$t.y, [double]$t.w, [double]$t.h)
            $shape.Name = $name
            $byName[$name] = $shape
        }
        elseif ($shape.Height -lt [double]$t.h) {
            $shape.Height = [double]$t.h   # never shorter than the text needs, otherwise keep the user's size
        }
        $shape.Placement = 3               # free floating: does not move or resize with cells
        $shape.Fill.ForeColor.RGB = $c.fill
        $shape.Line.ForeColor.RGB = $c.line
        $shape.Line.Weight = 1.75

        $tf = $shape.TextFrame2
        $tf.WordWrap = 0
        $tf.AutoSize = 0
        $tf.VerticalAnchor = 1
        $tf.MarginLeft = 8; $tf.MarginRight = 8; $tf.MarginTop = 6; $tf.MarginBottom = 6
        $tr = $tf.TextRange
        $tr.Text = ($t.lines -join "`r")
        $tr.Font.Name = "Consolas"
        $tr.Font.Size = 8.5
        $tr.Font.Bold = 0
        $tr.Font.Fill.ForeColor.RGB = $ink
        $tr.ParagraphFormat.Alignment = 1
        $head = $tr.Paragraphs(1, 1)
        $head.Font.Size = 10
        $head.Font.Bold = -1
        $head.Font.Fill.ForeColor.RGB = $c.line
        $head.ParagraphFormat.Alignment = 2
        for ($i = 2; $i -le $t.lines.Count; $i++) {
            if ($t.lines[$i - 1].StartsWith("PK")) { $tr.Paragraphs($i, 1).Font.Bold = -1 }
        }
    }

    $n = 0
    foreach ($r in $spec.relationships) {
        $p = $byName["tbl_" + $r.parent]
        $ch = $byName["tbl_" + $r.child]
        if (-not $p -or -not $ch) { throw "Relationship $($r.parent) -> $($r.child): table shape missing" }
        # connection sites on a rectangle: 1 top, 2 left, 3 bottom, 4 right
        if ($ch.Top -ge ($p.Top + $p.Height)) { $ps = 3; $cs = 1 }
        elseif ($ch.Left -ge ($p.Left + $p.Width)) { $ps = 4; $cs = 2 }
        elseif (($ch.Left + $ch.Width) -le $p.Left) { $ps = 2; $cs = 4 }
        else { $ps = 3; $cs = 1 }
        $cn = $ws.Shapes.AddConnector(2, 0, 0, 10, 10)       # 2 = elbow
        $cn.ConnectorFormat.BeginConnect($p, $ps)
        $cn.ConnectorFormat.EndConnect($ch, $cs)
        $cn.Name = "rel_{0}__{1}__{2}" -f $r.parent, $r.child, $r.column
        $cn.Line.ForeColor.RGB = $grey
        $cn.Line.Weight = 1.25
        $cn.Line.EndArrowheadStyle = 3                        # open arrow at the child = many
        if ([string]$r.cardinality -like "0..1*") { $cn.Line.BeginArrowheadStyle = 6 } else { $cn.Line.BeginArrowheadStyle = 1 }  # circle at the parent = optional
        $cn.ZOrder(1)                                         # send to back
        # Route the horizontal run through the free band just below the parent's row, each line at its own
        # level, so lines do not run behind boxes of that row and do not merge into one line.
        if ($ps -eq 3 -and $cs -eq 1) {
            $rowBottom = 0
            foreach ($tn in $spec.tables) {
                $o = $byName["tbl_" + $tn.name]
                if ([Math]::Abs($o.Top - $p.Top) -lt 10 -and ($o.Top + $o.Height) -gt $rowBottom) { $rowBottom = $o.Top + $o.Height }
            }
            $startY = $p.Top + $p.Height
            $endY = $ch.Top
            $y = $rowBottom + 14 + ($n % 5) * 7
            if ($y -gt ($endY - 8)) { $y = $endY - 8 }
            if (($endY - $startY) -gt 20) { $cn.Adjustments.Item(1) = ($y - $startY) / ($endY - $startY) }
        }
        $n++
    }

    $first = @($spec.relationships)[0]
    if ($first -and ($first.PSObject.Properties.Name -contains "basis")) {
        $rs = $wb.Worksheets.Item("Relationships")
        $hdr = 0
        for ($row = 1; $row -le 10; $row++) { if ($rs.Cells($row, 2).Value2 -eq "PARENT_TABLE") { $hdr = $row; break } }
        if ($hdr -eq 0) { throw "Relationships sheet: header row with PARENT_TABLE not found" }
        $col = @{}
        for ($c = 2; $c -le 14; $c++) { $h = $rs.Cells($hdr, $c).Value2; if ($h) { $col[[string]$h] = $c } }
        $last = $rs.Cells($rs.Rows.Count, 2).End(-4162).Row            # last used row in column B (xlUp)
        if ($last -le $hdr) { throw "Relationships sheet needs at least one data row to copy formatting from" }
        $want = @($spec.relationships).Count
        while (($last - $hdr) -lt $want) { $rs.Rows($last).Insert() | Out-Null; $last++ }   # new row inherits the row above
        while (($last - $hdr) -gt $want) { $rs.Rows($last).Delete() | Out-Null; $last-- }
        $i = 0
        foreach ($r in $spec.relationships) {
            $row = $hdr + 1 + $i
            $rs.Cells($row, $col["PARENT_TABLE"]).Value2 = [string]$r.parent
            $rs.Cells($row, $col["PARENT_COLUMN"]).Value2 = [string]$r.parent_column
            $rs.Cells($row, $col["CHILD_TABLE"]).Value2 = [string]$r.child
            $rs.Cells($row, $col["CHILD_COLUMN"]).Value2 = [string]$r.column
            $rs.Cells($row, $col["CARDINALITY"]).Value2 = [string]$r.cardinality
            $rs.Cells($row, $col["BASIS"]).Value2 = [string]$r.basis
            $rs.Cells($row, $col["CONFIDENCE"]).Value2 = [string]$r.confidence
            $rs.Cells($row, $col["NOTES"]).Value2 = [string]$r.notes
            $i++
        }
    }

    if ($PreviewPdf) {
        $maxR = 1; $maxC = 1
        foreach ($s in $ws.Shapes) {
            $b = $s.BottomRightCell
            if ($b.Row -gt $maxR) { $maxR = $b.Row }
            if ($b.Column -gt $maxC) { $maxC = $b.Column }
        }
        try {
            $ps = $ws.PageSetup
            $ps.Orientation = 2
            $ps.Zoom = $false
            $ps.FitToPagesWide = 1
            $ps.FitToPagesTall = 1
            $ps.PrintArea = $ws.Range($ws.Cells(1, 1), $ws.Cells($maxR + 1, $maxC + 1)).Address()
        } catch { Write-Warning "Page setup skipped: $($_.Exception.Message)" }
        $ws.ExportAsFixedFormat(0, $PreviewPdf)
    }

    $ws.Activate()
    $wb.Save()
    $wb.Close($false)
    Write-Output ("{0} tables, {1} connectors drawn on sheet '{2}'" -f @($spec.tables).Count, $n, $Sheet)
}
finally {
    $xl.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
