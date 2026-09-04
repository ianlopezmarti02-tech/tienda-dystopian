param (
    [int]$Port = 8080,
    [string]$Directory = $PSScriptRoot
)

if (-not $Directory) {
    $Directory = (Get-Location).Path
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Error "Error starting HTTP listener on port $Port : $($_.Exception.Message)"
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Servidor local ejecutandose en:" -ForegroundColor Green
Write-Host "   $prefix" -ForegroundColor Yellow
Write-Host " Sirviendo archivos desde: $Directory" -ForegroundColor Cyan
Write-Host " Presiona Ctrl+C para detener el servidor" -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
    ".ttf"  = "font/ttf"
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $rawPath = [System.Uri]::UnescapeDataString($request.Url.AbsolutePath)
        $relPath = $rawPath.TrimStart('/')

        if ([string]::IsNullOrWhiteSpace($relPath) -or $relPath -eq "/") {
            $relPath = "index.html"
        }

        $targetFile = Join-Path $Directory $relPath

        # Security check to prevent directory traversal
        $fullPath = [System.IO.Path]::GetFullPath($targetFile)
        $baseDir = [System.IO.Path]::GetFullPath($Directory)

        if ($fullPath.StartsWith($baseDir, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $fullPath -PathType Leaf)) {
            $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
            $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }

            $bytes = [System.IO.File]::ReadAllBytes($fullPath)
            $response.ContentType = $contentType
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.AddHeader("Cache-Control", "no-cache")
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host " [200] $($request.HttpMethod) $rawPath" -ForegroundColor DarkGreen
        } else {
            $errorMsg = [System.Text.Encoding]::UTF8.GetBytes("<h1>404 Not Found</h1><p>Archivo no encontrado: $rawPath</p>")
            $response.ContentType = "text/html; charset=utf-8"
            $response.ContentLength64 = $errorMsg.Length
            $response.StatusCode = 404
            $response.OutputStream.Write($errorMsg, 0, $errorMsg.Length)
            Write-Host " [404] $($request.HttpMethod) $rawPath" -ForegroundColor Red
        }

        $response.OutputStream.Close()
    }
} catch {
    Write-Host "`nServidor detenido: $($_.Exception.Message)" -ForegroundColor Yellow
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
