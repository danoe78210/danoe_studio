param(
  [string]$Executable = (Join-Path $PSScriptRoot '..\..\build\windows\x64\runner\Debug\danoestudio.exe'),
  [string]$OutputDirectory = $PSScriptRoot,
  [int]$Width = 1600,
  [int]$Height = 1000,
  [int]$ReadyTimeoutSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NativeCapture {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }

  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);

  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);

  [StructLayout(LayoutKind.Sequential)]
  public struct POINT { public int X, Y; }

  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool SetWindowPos(
    IntPtr hWnd, IntPtr insertAfter, int x, int y, int width, int height,
    uint flags);
}
'@

$pages = @(
  @{ Index = 0; Name = '01-reglages' },
  @{ Index = 1; Name = '02-informations' },
  @{ Index = 2; Name = '03-organisation' },
  @{ Index = 3; Name = '04-correction' },
  @{ Index = 4; Name = '05-production' },
  @{ Index = 5; Name = '06-lecture' },
  @{ Index = 6; Name = '07-registre' },
  @{ Index = 7; Name = '08-contact' }
)

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$resolvedExecutable = (Resolve-Path $Executable).Path

function Get-ClientBounds([IntPtr]$windowHandle) {
  $rect = New-Object NativeCapture+RECT
  if (-not [NativeCapture]::GetClientRect($windowHandle, [ref]$rect)) {
    throw "Impossible de lire la surface client de la fenêtre ($windowHandle)."
  }
  $origin = New-Object NativeCapture+POINT
  if (-not [NativeCapture]::ClientToScreen($windowHandle, [ref]$origin)) {
    throw "Impossible de convertir les coordonnées de la fenêtre ($windowHandle)."
  }
  return @{ X = $origin.X; Y = $origin.Y; Width = $rect.Right - $rect.Left; Height = $rect.Bottom - $rect.Top }
}

function Set-ClientSize([IntPtr]$windowHandle, [int]$width, [int]$height) {
  $client = New-Object NativeCapture+RECT
  $window = New-Object NativeCapture+RECT
  if (-not [NativeCapture]::GetClientRect($windowHandle, [ref]$client) -or
      -not [NativeCapture]::GetWindowRect($windowHandle, [ref]$window)) {
    throw "Impossible de mesurer la fenêtre à redimensionner."
  }
  $outerWidth = ($window.Right - $window.Left) + $width - ($client.Right - $client.Left)
  $outerHeight = ($window.Bottom - $window.Top) + $height - ($client.Bottom - $client.Top)
  if (-not [NativeCapture]::SetWindowPos(
      $windowHandle, [IntPtr]::Zero, $window.Left, $window.Top,
      $outerWidth, $outerHeight, 0x0004)) {
    throw "Impossible de redimensionner la fenêtre."
  }
}

foreach ($page in $pages) {
  $process = $null
  $bitmap = $null
  $graphics = $null
  try {
    Write-Host "Capture $($page.Name)..."
    $process = Start-Process -FilePath $resolvedExecutable -ArgumentList "--demo-page=$($page.Index)" -PassThru
    $deadline = (Get-Date).AddSeconds($ReadyTimeoutSeconds)
    do {
      $process.Refresh()
      if ($process.HasExited) { throw "L'application s'est arrêtée avec le code $($process.ExitCode)." }
      if ($process.MainWindowHandle -ne [IntPtr]::Zero) { break }
      Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)

    if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
      throw "Fenêtre introuvable après $ReadyTimeoutSeconds secondes."
    }

    Set-ClientSize $process.MainWindowHandle $Width $Height
    Start-Sleep -Milliseconds 200
    $bounds = Get-ClientBounds $process.MainWindowHandle
    if ($bounds.Width -ne $Width -or $bounds.Height -ne $Height) {
      throw "Surface client inattendue : $($bounds.Width)x$($bounds.Height), attendu ${Width}x${Height}."
    }

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bitmap.Size)
    $bitmap.Save((Join-Path $OutputDirectory "$($page.Name).png"), [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
    if ($process -and -not $process.HasExited) {
      Stop-Process -Id $process.Id -Force
      $process.WaitForExit(5000)
    }
    if ($process) { $process.Dispose() }
  }
}

Write-Host "Captures terminées dans $OutputDirectory"