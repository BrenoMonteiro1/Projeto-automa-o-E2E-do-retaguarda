[CmdletBinding()]
param(
    [string]$ShortcutPath = "$env:USERPROFILE\Desktop\GestaoConfig.exe - Atalho.lnk",
    [Parameter(Mandatory = $true)]
    [string]$User,
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [int]$WaitAfterSeconds = 3,
    [int]$LoginReadyDelaySeconds = 8,
    [int]$PasswordSettleDelaySeconds = 3,
    [int]$TypingDelayMilliseconds = 120,
    [int]$WindowTimeoutSeconds = 45,
    [int]$FocusRetries = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public class RetaguardaWindowInfo {
    public IntPtr Handle { get; set; }
    public bool Visible { get; set; }
    public bool Enabled { get; set; }
    public string Class { get; set; }
    public string Text { get; set; }
    public int Left { get; set; }
    public int Top { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
}

public static class RetaguardaNative {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    public static List<RetaguardaWindowInfo> GetWindowsForProcess(int targetProcessId) {
        var windows = new List<RetaguardaWindowInfo>();

        EnumWindows((hWnd, lParam) => {
            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);

            if (processId == (uint)targetProcessId) {
                AddWindowInfo(windows, hWnd);

                EnumChildWindows(hWnd, (childHwnd, childParam) => {
                    uint childProcessId;
                    GetWindowThreadProcessId(childHwnd, out childProcessId);

                    if (childProcessId == (uint)targetProcessId) {
                        AddWindowInfo(windows, childHwnd);
                    }

                    return true;
                }, IntPtr.Zero);
            }

            return true;
        }, IntPtr.Zero);

        return windows;
    }

    private static void AddWindowInfo(List<RetaguardaWindowInfo> windows, IntPtr hWnd) {
        var rect = new RECT();
        GetWindowRect(hWnd, out rect);

        var text = new StringBuilder(512);
        var className = new StringBuilder(512);
        GetWindowText(hWnd, text, text.Capacity);
        GetClassName(hWnd, className, className.Capacity);

        windows.Add(new RetaguardaWindowInfo {
            Handle = hWnd,
            Visible = IsWindowVisible(hWnd),
            Enabled = IsWindowEnabled(hWnd),
            Class = className.ToString(),
            Text = text.ToString(),
            Left = rect.Left,
            Top = rect.Top,
            Width = rect.Right - rect.Left,
            Height = rect.Bottom - rect.Top
        });
    }
}
"@

function Test-ItecProcess {
    param([System.Diagnostics.Process]$Process)

    try {
        return $Process.Path -like "C:\Itec\*"
    }
    catch {
        return $false
    }
}

function Get-GestaoConfigWindow {
    $gestao = Get-Process -Name "GestaoConfig" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Sort-Object Id -Descending |
        Select-Object -First 1

    if ($gestao) {
        return $gestao
    }

    return Get-Process |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and (
                $_.ProcessName -like "*Gestao*" -or
                $_.MainWindowTitle -like "*GestaoConfig*" -or
                (Test-ItecProcess $_)
            )
        } |
        Sort-Object Id -Descending |
        Select-Object -First 1
}

function Fechar-Retaguarda-Se-Aberto {
    $processes = @(Get-Process -Name "GestaoConfig", "atualiza" -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        return
    }

    foreach ($process in $processes) {
        try {
            if ($process.MainWindowHandle -ne 0) {
                [void]$process.CloseMainWindow()
            }
        }
        catch {
        }
    }

    $deadline = (Get-Date).AddSeconds(8)
    do {
        Start-Sleep -Milliseconds 250
        $remaining = @(Get-Process -Name "GestaoConfig", "atualiza" -ErrorAction SilentlyContinue)
    } while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

    foreach ($process in @(Get-Process -Name "GestaoConfig", "atualiza" -ErrorAction SilentlyContinue)) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        catch {
        }
    }

    Start-Sleep -Seconds 1
}

function Get-WindowBounds {
    param([System.Diagnostics.Process]$Process)

    $rect = New-Object RECT
    [void][RetaguardaNative]::GetWindowRect($Process.MainWindowHandle, [ref]$rect)

    return [pscustomobject]@{
        Left = $rect.Left
        Top = $rect.Top
        Width = $rect.Right - $rect.Left
        Height = $rect.Bottom - $rect.Top
    }
}

function Restore-GestaoConfigWindow {
    param([System.Diagnostics.Process]$Process)

    [void][RetaguardaNative]::ShowWindow($Process.MainWindowHandle, 9)
    Start-Sleep -Milliseconds 300

    $bounds = Get-WindowBounds $Process
    if ($bounds.Width -le 50 -or $bounds.Height -le 50) {
        [void][RetaguardaNative]::SetWindowPos($Process.MainWindowHandle, [IntPtr]::Zero, 120, 120, 1024, 700, 0x0040)
        Start-Sleep -Milliseconds 500
    }

    [void][RetaguardaNative]::SetForegroundWindow($Process.MainWindowHandle)
}

function Get-GestaoConfigTextBoxes {
    param([System.Diagnostics.Process]$Process)

    return @(
        [RetaguardaNative]::GetWindowsForProcess($Process.Id) |
            Where-Object {
                $_.Class -eq "ThunderRT6TextBox" -and
                $_.Visible -and
                $_.Enabled -and
                $_.Width -ge 50 -and
                $_.Height -ge 10
            } |
            Sort-Object Top, Left
    )
}

function Get-GestaoConfigVisibleControls {
    param([System.Diagnostics.Process]$Process)

    return @(
        [RetaguardaNative]::GetWindowsForProcess($Process.Id) |
            Where-Object { $_.Visible } |
            Sort-Object Top, Left
    )
}

function Fechar-Popup-Ok-Se-Existir {
    param([System.Diagnostics.Process]$Process)

    $botaoOk = Get-GestaoConfigVisibleControls $Process |
        Where-Object { $_.Enabled -and $_.Text -match '^(OK|Ok|ok)$' } |
        Sort-Object Top, Left |
        Select-Object -First 1

    if ($botaoOk) {
        Click-Control-Center $botaoOk
        Start-Sleep -Milliseconds 500
        return $true
    }

    return $false
}

function Click-Control-Center {
    param($Control)

    $x = $Control.Left + [int]($Control.Width / 2)
    $y = $Control.Top + [int]($Control.Height / 2)

    [void][RetaguardaNative]::SetCursorPos($x, $y)
    Start-Sleep -Milliseconds 150
    [RetaguardaNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [RetaguardaNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 300
}

function Send-Text-Slowly {
    param(
        [string]$Text,
        [int]$DelayMilliseconds
    )

    foreach ($char in $Text.ToCharArray()) {
        [System.Windows.Forms.SendKeys]::SendWait([string]$char)
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
}

function Clear-And-Type-Control {
    param(
        $Control,
        [string]$Text,
        [int]$DelayMilliseconds
    )

    Click-Control-Center $Control
    Start-Sleep -Milliseconds 250
    [System.Windows.Forms.SendKeys]::SendWait("^a")
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE}")
    Start-Sleep -Milliseconds 150
    Send-Text-Slowly -Text $Text -DelayMilliseconds $DelayMilliseconds
    Start-Sleep -Milliseconds 300
}

function Clicar-Botao-Entrar-PorPosicao {
    param(
        [System.Diagnostics.Process]$Process,
        $CampoSenha
    )

    $botaoEntrar = Get-GestaoConfigVisibleControls $Process |
        Where-Object {
            $_.Enabled -and
            $_.Class -eq "ThunderRT6UserControlDC" -and
            $_.Top -gt $CampoSenha.Top -and
            $_.Width -ge 60 -and
            $_.Width -le 120 -and
            $_.Height -ge 18 -and
            $_.Height -le 35
        } |
        Sort-Object Top, Left |
        Select-Object -First 1

    if (-not $botaoEntrar) {
        $detalhes = (Get-GestaoConfigVisibleControls $Process | Format-Table -AutoSize | Out-String)
        throw "Nao localizei o botao Entrar do Retaguarda. Controles encontrados: $detalhes"
    }

    Restore-GestaoConfigWindow $Process
    Click-Control-Center $botaoEntrar
}

function Preencher-Login-PorHandle {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$Usuario,
        [string]$Senha,
        [int]$AguardarSenhaSegundos,
        [int]$DelayDigitacaoMilliseconds
    )

    $textBoxes = @(Get-GestaoConfigTextBoxes $Process)
    if ($textBoxes.Count -lt 2) {
        $detalhes = ($textBoxes | Format-Table -AutoSize | Out-String)
        throw "Nao localizei os campos de usuario e senha do Retaguarda. Campos encontrados: $detalhes"
    }

    $campoUsuario = $textBoxes | Where-Object { $_.Text -eq "Txt_Usuario" } | Select-Object -First 1
    $campoSenha = $textBoxes | Where-Object { $_.Text -eq "TxtSenha" } | Select-Object -First 1

    if (-not $campoUsuario) {
        $campoUsuario = $textBoxes[0]
    }
    if (-not $campoSenha) {
        $campoSenha = $textBoxes[1]
    }

    Restore-GestaoConfigWindow $Process
    Start-Sleep -Milliseconds 500

    Clear-And-Type-Control -Control $campoUsuario -Text $Usuario -DelayMilliseconds $DelayDigitacaoMilliseconds
    Start-Sleep -Milliseconds 700
    Clear-And-Type-Control -Control $campoSenha -Text $Senha -DelayMilliseconds $DelayDigitacaoMilliseconds
    Start-Sleep -Seconds $AguardarSenhaSegundos

    Clicar-Botao-Entrar-PorPosicao -Process $Process -CampoSenha $campoSenha
}

function Aguardar-Tela-Login-Pronta {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$DelaySeconds
    )

    if ($DelaySeconds -gt 0) {
        Start-Sleep -Seconds $DelaySeconds
    }

    $deadline = (Get-Date).AddSeconds(45)
    do {
        $textBoxes = @(Get-GestaoConfigTextBoxes $Process)

        if ($textBoxes.Count -ge 2) {
            return
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    $detalhes = (@(Get-GestaoConfigTextBoxes $Process) | Format-Table -AutoSize | Out-String)
    throw "Tela de login nao ficou pronta apos a abertura. Campos encontrados: $detalhes"
}

function Validar-Login-Concluido {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $processoAtual = Get-GestaoConfigWindow
        if ($processoAtual) {
            $textBoxes = @(Get-GestaoConfigTextBoxes $processoAtual)
            $camposLogin = @(
                $textBoxes |
                    Where-Object {
                        $_.Text -eq "Txt_Usuario" -or
                        $_.Text -eq "TxtSenha" -or
                        $_.Text -eq "txtCdFilial" -or
                        ($_.Top -ge 600 -and $_.Top -le 820)
                    }
            )

            if ($camposLogin.Count -lt 2) {
                return
            }
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    $camposAtuais = @(Get-GestaoConfigTextBoxes $Process) | Format-Table -AutoSize | Out-String
    throw "Login nao avancou: a tela de login ainda parece aberta apos clicar em Entrar. Campos atuais: $camposAtuais"
}

if (-not (Test-Path -LiteralPath $ShortcutPath)) {
    throw "Shortcut not found: $ShortcutPath"
}

$windowProcess = $null
Fechar-Retaguarda-Se-Aberto
Start-Process -FilePath $ShortcutPath

$deadline = (Get-Date).AddSeconds($WindowTimeoutSeconds)
while ((Get-Date) -lt $deadline -and -not $windowProcess) {
    Start-Sleep -Milliseconds 500
    $windowProcess = Get-GestaoConfigWindow
}

if (-not $windowProcess) {
    throw "GestaoConfig window was not found after $WindowTimeoutSeconds seconds."
}

$shell = New-Object -ComObject WScript.Shell
if ($LoginReadyDelaySeconds -gt 0) {
    Start-Sleep -Seconds $LoginReadyDelaySeconds
}

$windowProcess = Get-GestaoConfigWindow
if (-not $windowProcess) {
    throw "GestaoConfig window was not found after startup stabilization."
}

Restore-GestaoConfigWindow $windowProcess

$activated = $false
for ($i = 0; $i -lt $FocusRetries -and -not $activated; $i++) {
    Start-Sleep -Milliseconds 300
    $activated = $shell.AppActivate([int]$windowProcess.Id)
    if (-not $activated) {
        [void][RetaguardaNative]::SetForegroundWindow($windowProcess.MainWindowHandle)
    }
}

if (-not $activated -and $windowProcess.MainWindowTitle) {
    $activated = $shell.AppActivate($windowProcess.MainWindowTitle)
}

if (-not $activated) {
    throw "Could not focus window for process $($windowProcess.ProcessName) PID $($windowProcess.Id)."
}

Start-Sleep -Milliseconds 700
Fechar-Popup-Ok-Se-Existir $windowProcess | Out-Null
Aguardar-Tela-Login-Pronta -Process $windowProcess -DelaySeconds 0
Preencher-Login-PorHandle -Process $windowProcess -Usuario $User -Senha $Password -AguardarSenhaSegundos $PasswordSettleDelaySeconds -DelayDigitacaoMilliseconds $TypingDelayMilliseconds
Start-Sleep -Seconds $WaitAfterSeconds
try {
    Validar-Login-Concluido -Process $windowProcess -TimeoutSeconds 1
}
finally {
    Fechar-Retaguarda-Se-Aberto
}

[pscustomobject]@{
    processName = $windowProcess.ProcessName
    id = $windowProcess.Id
    windowTitle = $windowProcess.MainWindowTitle
    status = "Retaguarda opened fresh, login sequence sent, and system closed"
} | ConvertTo-Json -Compress
