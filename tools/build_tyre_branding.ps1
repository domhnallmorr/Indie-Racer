# Curved typographic sidewall marking, generated on a transparent canvas.
Add-Type -AssemblyName System.Drawing
$bitmap = New-Object Drawing.Bitmap 512,512
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$font = New-Object Drawing.Font 'Times New Roman',100,([Drawing.FontStyle]::Bold -bor [Drawing.FontStyle]::Italic),([Drawing.GraphicsUnit]::Pixel)
$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255,231,226,211))
$format = [Drawing.StringFormat]::GenericTypographic.Clone()
$format.Alignment = [Drawing.StringAlignment]::Center
foreach ($half in @(0,180)) {
    $word = 'Firestone'
    for ($i=0; $i -lt $word.Length; $i++) {
        $state = $graphics.Save()
        $graphics.TranslateTransform(256,256)
        $graphics.RotateTransform($half + ($i-4)*18.0)
        # Double the tangential size, but fit the height to the rubber sidewall.
        $graphics.TranslateTransform(0,-224)
        $graphics.ScaleTransform(1,0.6)
        $graphics.DrawString([string]$word[$i],$font,$brush,0,0,$format)
        $graphics.Restore($state)
    }
}
$outputPath = Join-Path $PSScriptRoot '../content/vehicles/open_wheel/liveries/tyre_firestone.png'
$bitmap.Save($outputPath,[Drawing.Imaging.ImageFormat]::Png)
$format.Dispose()
$brush.Dispose()
$font.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

