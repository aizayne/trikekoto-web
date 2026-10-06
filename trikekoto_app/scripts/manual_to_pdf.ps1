# Renders docs/TrikeKoTo-User-Manual.docx to PDF for the thesis appendix.
#
#   powershell -ExecutionPolicy Bypass -File scripts/manual_to_pdf.ps1
#
# Run it AFTER scripts/build_user_manual.cjs, which writes the .docx this
# converts. The .docx stays the source of truth; this is one more rendering of
# it, the same way the Markdown copy is.
#
# Word does the conversion rather than a library, for one reason: the manual
# carries a field-based table of contents and field-based page numbers, and
# only a word processor that lays the document out can resolve them. A
# library that writes PDF directly would have to re-implement pagination to
# know what page section 6.4 lands on, and would get it subtly wrong.
#
# Needs Microsoft Word on the machine. It is not part of CI, and the PDF is
# committed so nobody without Word is blocked.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$docx = Join-Path $root 'docs\TrikeKoTo-User-Manual.docx'
$pdf  = Join-Path $root 'docs\TrikeKoTo-User-Manual.pdf'

if (-not (Test-Path $docx)) {
  Write-Error "No manual at $docx. Run: NODE_PATH=`"`$(npm root -g)`" node scripts/build_user_manual.cjs"
}

try {
  $word = New-Object -ComObject Word.Application
} catch {
  Write-Error 'Microsoft Word is required to render the PDF. The .docx and .md are already built; only this step needs it.'
}

$word.Visible = $false
# A hidden Word still raises dialogs, and a dialog nobody can see is a hang
# rather than an error. This turns them into decisions Word makes itself.
$word.DisplayAlerts = 0

try {
  # ReadOnly, so a conversion can never write back into the generated file.
  $doc = $word.Documents.Open($docx, $false, $true)

  # The table of contents and the page numbers are fields: without this they
  # render as the placeholder text they were written as.
  #
  # Fields.Update() alone. Updating the TablesOfContents object explicitly, or
  # asking for ComputeStatistics afterwards, hangs this invisible Word
  # indefinitely — it was tried on 2026-10-07 and had to be killed twice. The
  # field update resolves the contents and the page numbers anyway; the proof
  # is that page 2 of the PDF lists every section against a real page number.
  $doc.Fields.Update() | Out-Null

  $doc.SaveAs2($pdf, 17)   # 17 = wdFormatPDF
  $doc.Close($false)
  Write-Output ("wrote {0} ({1:N0} bytes)" -f $pdf, (Get-Item $pdf).Length)
} finally {
  $word.Quit()
}
