param([Parameter(Mandatory = $true)][string] $EncodedConfig)

$ErrorActionPreference = 'Stop'
$config = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedConfig)) | ConvertFrom-Json
$exe = [IO.Path]::GetFullPath($config.executable)
$directory = [IO.Path]::GetDirectoryName($exe)
$backup = "$exe.previous"
$next = "$exe.next-$([Guid]::NewGuid().ToString('N'))"
$replaced = $false
$canRelaunch = $false
$asset = $null
$zip = $null
$mutex = $null
$ownsLock = $false

function Start-Waystone {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $exe
    $start.WorkingDirectory = $directory
    $start.UseShellExecute = $false
    $start.Arguments = (@($config.arguments) | ForEach-Object {
        # Windows parses backslashes specially immediately before a quote.
        '"' + ([string]$_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
    }) -join ' '
    [Diagnostics.Process]::Start($start)
}

try {
    $mutexId = [IO.Path]::GetFileNameWithoutExtension([string]$config.failure)
    $mutex = New-Object Threading.Mutex($false, "Local\Waystone-$mutexId")
    try { $ownsLock = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsLock = $true }
    if (-not $ownsLock) { exit 1 }

    $old = Get-Process -Id ([int]$config.processId) -ErrorAction SilentlyContinue
    if ($old -and $old.Path -eq $exe -and -not $old.WaitForExit(30000)) {
        throw 'Waystone is still running.'
    }
    $canRelaunch = $true

    # Check the same open archive handle used for extraction. Deny other writers.
    $asset = [IO.File]::Open($config.asset, 'Open', 'Read', 'Read')
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = [BitConverter]::ToString($sha.ComputeHash($asset)).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
    if ($asset.Length -ne $config.size -or $digest -ne $config.sha256) {
        throw 'Release asset no longer matches the GitHub digest.'
    }
    $asset.Position = 0
    Add-Type -AssemblyName System.IO.Compression
    $zip = [IO.Compression.ZipArchive]::new($asset, [IO.Compression.ZipArchiveMode]::Read, $true)
    if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -cne 'Waystone.exe') {
        throw 'Unexpected Windows release archive layout.'
    }
    $entry = $zip.Entries[0]
    if ($entry.Length -lt 64 -or $entry.Length -gt 256MB) {
        throw 'Unexpected executable size.'
    }
    $source = $entry.Open()
    try {
        $target = [IO.File]::Open($next, 'CreateNew', 'Write', 'None')
        try {
            $buffer = New-Object byte[] 65536
            $written = 0L
            while (($read = $source.Read($buffer, 0, $buffer.Length)) -ne 0) {
                $written += $read
                if ($written -gt $entry.Length) { throw 'Executable exceeds its declared size.' }
                $target.Write($buffer, 0, $read)
            }
            if ($written -ne $entry.Length) { throw 'Executable is incomplete.' }
            $target.Flush($true)
        } finally {
            $target.Dispose()
        }
    } finally {
        $source.Dispose()
    }

    # One filesystem operation swaps the executables. Saves live outside the install.
    [IO.File]::Replace($next, $exe, $backup)
    $replaced = $true
    $child = Start-Waystone
    $child.Dispose()
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    try { [IO.File]::WriteAllText($config.failure, 'failed') } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
    }
    try {
        if ($replaced) { [IO.File]::Replace($backup, $exe, [NullString]::Value) }
        elseif (-not [IO.File]::Exists($exe) -and [IO.File]::Exists($backup)) {
            [IO.File]::Move($backup, $exe)
        }
        if ($canRelaunch) {
            $child = Start-Waystone
            $child.Dispose()
        }
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
    }
    exit 1
} finally {
    if ($zip) { $zip.Dispose() }
    if ($asset) { $asset.Dispose() }
    if ($ownsLock) {
        try {
            [IO.File]::Delete($next)
            [IO.File]::Delete($config.asset)
        } finally {
            $mutex.ReleaseMutex()
        }
    }
    if ($mutex) { $mutex.Dispose() }
}
