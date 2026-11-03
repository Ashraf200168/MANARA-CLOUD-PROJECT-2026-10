param(
  [Parameter(Mandatory=$true)][string]$SourcePath,
  [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$source=[Drawing.Image]::FromFile([IO.Path]::GetFullPath($SourcePath))
$sizes=@(16,24,32,48,64,128,256)
$frames=New-Object 'Collections.Generic.List[byte[]]'
try {
  foreach($size in $sizes) {
    $bitmap=New-Object Drawing.Bitmap($size,$size)
    try {
      $graphics=[Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $ratio=[Math]::Min($size/[double]$source.Width,$size/[double]$source.Height)
        $width=[int][Math]::Round($source.Width*$ratio)
        $height=[int][Math]::Round($source.Height*$ratio)
        $target=New-Object Drawing.Rectangle([int](($size-$width)/2),[int](($size-$height)/2),$width,$height)
        $graphics.DrawImage($source,$target)
      } finally { $graphics.Dispose() }
      $memory=New-Object IO.MemoryStream
      $frame=New-Object IO.BinaryWriter($memory)
      try {
        $maskStride=[int]([Math]::Ceiling($size/32.0)*4)
        $frame.Write([int]40); $frame.Write([int]$size); $frame.Write([int]($size*2))
        $frame.Write([uint16]1); $frame.Write([uint16]32); $frame.Write([int]0)
        $frame.Write([int]($size*$size*4+$maskStride*$size))
        foreach($zero in 1..4){$frame.Write([int]0)}
        for($y=$size-1;$y -ge 0;$y--) {
          for($x=0;$x -lt $size;$x++) {
            $pixel=$bitmap.GetPixel($x,$y)
            $frame.Write([byte]$pixel.B); $frame.Write([byte]$pixel.G)
            $frame.Write([byte]$pixel.R); $frame.Write([byte]$pixel.A)
          }
        }
        $frame.Write((New-Object byte[] ($maskStride*$size)))
        $frame.Flush(); $frames.Add($memory.ToArray())
      } finally { $frame.Dispose(); $memory.Dispose() }
    } finally { $bitmap.Dispose() }
  }
} finally { $source.Dispose() }
New-Item -ItemType Directory -Force -Path (Split-Path ([IO.Path]::GetFullPath($OutputPath))) | Out-Null
$file=[IO.File]::Create([IO.Path]::GetFullPath($OutputPath))
$writer=New-Object IO.BinaryWriter($file)
try {
  $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
  $offset=6+16*$sizes.Count
  for($index=0;$index -lt $sizes.Count;$index++) {
    $dimension=if($sizes[$index] -eq 256){0}else{$sizes[$index]}
    $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
    $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32)
    $writer.Write([uint32]$frames[$index].Length); $writer.Write([uint32]$offset)
    $offset+=$frames[$index].Length
  }
  foreach($bytes in $frames){$writer.Write($bytes)}
} finally { $writer.Dispose(); $file.Dispose() }
$icon=New-Object Drawing.Icon([IO.Path]::GetFullPath($OutputPath))
$icon.Dispose()
Write-Output 'Manara icon generated: 16, 24, 32, 48, 64, 128, 256 pixels.'
