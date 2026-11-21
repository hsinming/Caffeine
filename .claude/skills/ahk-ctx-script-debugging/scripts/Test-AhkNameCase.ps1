<#
.SYNOPSIS
    Static check for AutoHotkey v2 name collisions caused by case-insensitive identifiers.

.DESCRIPTION
    AutoHotkey v2 identifiers are case-insensitive: `_Tick` and `_tick` are one name. Code that treats them
    as two names (a method `_Tick` plus `this._tick := ...`) fails at run time with "Property is read-only",
    or silently shares one variable. The interpreter reports no load error for it, so /Validate stays clean.

    The check is a line-based scan, not a full parser: it blanks strings and comments, tracks braces, and
    compares spellings per scope. It reads one file at a time (members of an #Include'd class are not seen).

    Findings (kind, severity):
        class-member-collision       error    a method or property and `this.X :=` differ only by case
        shadowed-name                error    a local variable or parameter has the name of a function or class
                                              that the same scope calls (`map := Map()`), or the scope uses another
                                              spelling of it as `Name.` or `Name(` (`json := JSON.Dump(x)`)
        inconsistent-spelling        warning  one local name is spelled with different case in one scope
        inconsistent-member-spelling warning  one class member is spelled with different case in one class

    Output is one JSON object: filesScanned, errors, warnings, findings[]. Exit 0 when there are no
    findings, 1 otherwise.

.EXAMPLE
    .\Test-AhkNameCase.ps1 -Path C:\proj\app.ahk
    .\Test-AhkNameCase.ps1 -Path C:\proj          # every *.ahk below the folder
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string[]] $Path
)
$ErrorActionPreference = 'Stop'

# Replace string contents and comments with spaces, keeping line breaks so line numbers stay right.
function Remove-StringsAndComments([string] $text) {
    $sb = [Text.StringBuilder]::new($text.Length)
    $n = $text.Length
    $i = 0
    $state = 'code'
    $quote = ''
    $prevSpace = $true      # the previous character is whitespace (or the text start)
    $lineBlank = $true      # only whitespace so far on this line
    $unterminated = $false  # the previous line ended inside a string: a "(" line may open a continuation section
    while ($i -lt $n) {
        $ch = $text[$i]
        $isBreak = ($ch -eq "`n" -or $ch -eq "`r")
        if ($state -eq 'block') {
            if ($ch -eq '*' -and $i + 1 -lt $n -and $text[$i + 1] -eq '/') { [void]$sb.Append('  '); $i += 2; $state = 'code'; continue }
            [void]$sb.Append($(if ($isBreak) { $ch } else { ' ' }))
            if ($isBreak) { $lineBlank = $true }
            $i++; continue
        }
        if ($state -eq 'continuation') {
            if ($isBreak) { [void]$sb.Append($ch); $lineBlank = $true; $i++; continue }
            if ($lineBlank -and $ch -eq ')') { [void]$sb.Append(' '); $state = 'code'; $lineBlank = $false; $prevSpace = $false; $i++; continue }
            if ($ch -ne ' ' -and $ch -ne "`t") { $lineBlank = $false }
            [void]$sb.Append(' '); $i++; continue
        }
        if ($state -eq 'string') {
            if ($ch -eq '`' -and $i + 1 -lt $n -and -not ($text[$i + 1] -eq "`n" -or $text[$i + 1] -eq "`r")) {
                [void]$sb.Append('  '); $i += 2; continue
            }
            if ($ch -eq $quote) { [void]$sb.Append($ch); $state = 'code'; $prevSpace = $false; $lineBlank = $false; $i++; continue }
            if ($isBreak) { [void]$sb.Append($ch); $state = 'code'; $lineBlank = $true; $prevSpace = $true; $unterminated = $true; $i++; continue }
            [void]$sb.Append(' '); $i++; continue
        }
        if ($lineBlank -and -not $isBreak -and $ch -ne ' ' -and $ch -ne "`t") {
            if ($unterminated -and $ch -eq '(') { $state = 'continuation'; [void]$sb.Append(' '); $lineBlank = $false; $unterminated = $false; $i++; continue }
            $unterminated = $false
        }
        if ($ch -eq '"' -or $ch -eq "'") {
            $state = 'string'; $quote = $ch; [void]$sb.Append($ch); $lineBlank = $false; $prevSpace = $false; $i++; continue
        }
        if ($ch -eq ';' -and $prevSpace) {
            while ($i -lt $n -and $text[$i] -ne "`n" -and $text[$i] -ne "`r") { [void]$sb.Append(' '); $i++ }
            continue
        }
        if ($ch -eq '/' -and $lineBlank -and $i + 1 -lt $n -and $text[$i + 1] -eq '*') {
            [void]$sb.Append('  '); $i += 2; $state = 'block'; continue
        }
        [void]$sb.Append($ch)
        if ($isBreak) { $lineBlank = $true; $prevSpace = $true }
        else { $prevSpace = ($ch -eq ' ' -or $ch -eq "`t"); if (-not $prevSpace) { $lineBlank = $false } }
        $i++
    }
    return $sb.ToString()
}

$Keywords = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($k in 'if', 'else', 'while', 'for', 'loop', 'switch', 'case', 'default', 'catch', 'try', 'finally', 'until',
    'return', 'throw', 'break', 'continue', 'goto', 'global', 'local', 'static', 'in', 'is', 'as', 'and', 'or', 'not',
    'contains', 'class', 'extends', 'this', 'super', 'true', 'false', 'get', 'set', 'unset', 'parse', 'read', 'files', 'reg') {
    [void]$Keywords.Add($k)
}

# Names of AutoHotkey v2 functions and classes (the page names under docs/lib of AutoHotkeyDocs).
$BuiltinNames = @'
Any Array Block BlockInput Break Buffer CallbackCreate CaretGetPos Catch Chr Class Click ClipboardAll ClipWait
ComCall ComObjActive ComObjArray ComObjConnect ComObject ComObjFlags ComObjFromPtr ComObjGet ComObjQuery
ComObjType ComObjValue ComValue Continue Control ControlAddItem ControlChooseIndex ControlChooseString
ControlClick ControlDeleteItem ControlFindItem ControlFocus ControlGetChecked ControlGetChoice
ControlGetClassNN ControlGetEnabled ControlGetFocus ControlGetHwnd ControlGetIndex ControlGetItems
ControlGetPos ControlGetStyle ControlGetText ControlGetVisible ControlHide ControlHideDropDown ControlMove
ControlSend ControlSetChecked ControlSetEnabled ControlSetStyle ControlSetText ControlShow ControlShowDropDown
CoordMode Critical DateAdd DateDiff DetectHiddenText DetectHiddenWindows DirCopy DirCreate DirDelete DirExist
DirMove DirSelect DllCall Download Drive DriveEject DriveGetCapacity DriveGetFileSystem DriveGetLabel
DriveGetList DriveGetSerial DriveGetSpaceFree DriveGetStatus DriveGetStatusCD DriveGetType DriveLock
DriveSetLabel DriveUnlock Edit EditGetCurrentCol EditGetCurrentLine EditGetLine EditGetLineCount
EditGetSelectedText EditPaste Else Enumerator EnvGet EnvSet Error Exit ExitApp File FileAppend FileCopy
FileCreateShortcut FileDelete FileEncoding FileExist FileGetAttrib FileGetShortcut FileGetSize FileGetTime
FileGetVersion FileInstall FileMove FileOpen FileRead FileRecycle FileRecycleEmpty FileSelect FileSetAttrib
FileSetTime Finally Float For Format FormatTime Func GetKeyName GetKeySC GetKeyState GetKeyVK GetMethod Goto
GroupActivate GroupAdd GroupClose GroupDeactivate Gui GuiControl GuiControls GuiCtrlFromHwnd GuiFromHwnd
GuiOnCommand GuiOnEvent GuiOnNotify HasBase HasMethod HasProp HotIf Hotkey Hotstring If ImageSearch
IniDelete IniRead IniWrite InputBox InputHook InstallKeybdHook InstallMouseHook InStr Integer Is IsLabel
IsObject IsSet KeyHistory KeyWait ListHotkeys ListLines ListVars ListView ListViewGetContent LoadPicture Loop
LoopFiles LoopParse LoopRead LoopReg Map Math Menu MenuFromHandle MenuSelect Monitor MonitorGet
MonitorGetCount MonitorGetName MonitorGetPrimary MonitorGetWorkArea MouseClick MouseClickDrag MouseGetPos
MouseMove MsgBox Number NumGet NumPut ObjAddRef ObjBindMethod Object OnClipboardChange OnError OnExit
OnMessage Ord OutputDebug Pause Persistent PixelGetColor PixelSearch PostMessage Process ProcessClose
ProcessExist ProcessGetName ProcessGetParent ProcessSetPriority ProcessWait ProcessWaitClose Random
RegCreateKey RegDelete RegDeleteKey RegExMatch RegExReplace RegRead RegWrite Reload Return Run RunAs Send
SendLevel SendMessage SendMode SetControlDelay SetDefaultMouseSpeed SetKeyDelay SetMouseDelay
SetNumScrollCapsLockState SetRegView SetStoreCapsLockMode SetTimer SetTitleMatchMode SetWinDelay SetWorkingDir
Shutdown Sleep Sort Sound SoundBeep SoundGetInterface SoundGetMute SoundGetName SoundGetVolume SoundPlay
SoundSetMute SoundSetVolume SplitPath StatusBarGetText StatusBarWait StrCompare StrGet String StrLen StrLower
StrPtr StrPut StrReplace StrSplit SubStr Suspend Switch SysGet SysGetIPAddresses Thread Throw ToolTip
TraySetIcon TrayTip TreeView Trim Try Type Until VarSetStrCapacity VerCompare While Win WinActivate
WinActivateBottom WinActive WinClose WinExist WinGetClass WinGetClientPos WinGetControls WinGetControlsHwnd
WinGetCount WinGetID WinGetIDLast WinGetList WinGetMinMax WinGetPID WinGetPos WinGetProcessName
WinGetProcessPath WinGetStyle WinGetText WinGetTitle WinGetTransColor WinGetTransparent WinHide WinKill
WinMaximize WinMinimize WinMinimizeAll WinMove WinMoveBottom WinMoveTop WinRedraw WinRestore WinSetAlwaysOnTop
WinSetEnabled WinSetRegion WinSetStyle WinSetTitle WinSetTransColor WinSetTransparent WinShow WinWait
WinWaitActive WinWaitClose
'@ -split '\s+'

$AssignOp = '(?::=|\+=|-=|\*=|/=|//=|\.=|\|=|&=|\^=|>>=|<<=|>>>=|\+\+|--)'

function Get-NameCaseFindings([string] $file) {
    $findings = [Collections.Generic.List[object]]::new()
    $raw = [IO.File]::ReadAllText($file)
    $lines = (Remove-StringsAndComments $raw) -split "`r?`n"

    function Add-Finding($kind, $severity, $line, $name, $spellings, $message) {
        $findings.Add([pscustomobject]@{
                file = $file; kind = $kind; severity = $severity; line = $line
                name = $name.ToLowerInvariant(); spellings = @($spellings); message = $message
            })
    }

    function Test-NextLineOpensBrace($index) {
        for ($j = $index + 1; $j -lt $lines.Count; $j++) {
            $t = $lines[$j].Trim()
            if ($t -ne '') { return $t.StartsWith('{') }
        }
        return $false
    }

    function New-VarScope($type, $name) {
        return @{ type = $type; name = $name; bound = [Collections.Generic.List[object]]::new()
            tokens = [Collections.Generic.List[object]]::new(); calls = [Collections.Generic.List[object]]::new() }
    }

    function Get-ParamNames([string] $paramText) {
        $parts = [Collections.Generic.List[string]]::new()
        $nest = 0
        $cur = ''
        foreach ($c in $paramText.ToCharArray()) {
            if ($c -eq '(' -or $c -eq '[' -or $c -eq '{') { $nest++ } elseif ($c -eq ')' -or $c -eq ']' -or $c -eq '}') { $nest-- }
            if ($c -eq ',' -and $nest -eq 0) { $parts.Add($cur); $cur = '' } else { $cur += $c }
        }
        $parts.Add($cur)
        foreach ($part in $parts) { if ($part -match '^\s*&?([A-Za-z_]\w*)') { $Matches[1] } }
    }

    # Functions and classes defined at the top level of this file, plus the built-in ones.
    $known = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($b in $BuiltinNames) { if ($b) { [void]$known.Add($b) } }
    $nestDepth = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if ($nestDepth -eq 0) {
            if ($t -match '^class\s+([A-Za-z_]\w*)') { [void]$known.Add($Matches[1]) }
            elseif ($t -match '^([A-Za-z_]\w*)\s*\((?:[^()]|\([^()]*\))*\)\s*(\{|=>)?' -and -not $Keywords.Contains($Matches[1]) -and ($Matches[2] -or (Test-NextLineOpensBrace $i))) { [void]$known.Add($Matches[1]) }
        }
        $nestDepth += ($t.Split('{').Count - 1) - ($t.Split('}').Count - 1)
        if ($nestDepth -lt 0) { $nestDepth = 0 }
    }

    function Complete-VarScope($scope) {
        $boundKeys = @{}
        foreach ($b in $scope.bound) {
            $k = $b.name.ToLowerInvariant()
            if (-not $boundKeys.ContainsKey($k)) { $boundKeys[$k] = $b }
        }
        foreach ($k in $boundKeys.Keys) {
            $call = $scope.calls | Where-Object { $_.name -ieq $k } | Select-Object -First 1
            $local = $scope.bound | Where-Object { $_.name -ieq $k -and $_.kind -ne 'param' } | Select-Object -First 1
            if ($call -and $local -and $known.Contains($k)) {
                Add-Finding 'shadowed-name' 'error' $local.line $k @($local.name, $call.name) `
                    "In $($scope.type) '$($scope.name)', local '$($local.name)' has the name of a function or class that is also called there ('$($call.name)('): the call goes to the local variable."
                continue
            }
            $uses = @($scope.tokens | Where-Object { $_.name.ToLowerInvariant() -eq $k })
            $spellings = @($uses | ForEach-Object { $_.name } | Select-Object -Unique)
            # A spelling never bound here, used as `Name.` or `Name(`, means a class or function from another file.
            $boundSpellings = @($scope.bound | Where-Object { $_.name -ieq $k } | ForEach-Object { $_.name })
            $other = $uses | Where-Object { $_.member -and $boundSpellings -cnotcontains $_.name } | Select-Object -First 1
            if ($other) {
                $b = $boundKeys[$k]
                Add-Finding 'shadowed-name' 'error' $b.line $k @($b.name, $other.name) `
                    "In $($scope.type) '$($scope.name)', local '$($b.name)' hides '$($other.name)' (line $($other.line)): identifiers are case-insensitive, so '$($other.name)' is the local variable, not the class or function."
                continue
            }
            if ($spellings.Count -ge 2) {
                $second = $uses | Where-Object { $_.name -cne $spellings[0] } | Select-Object -First 1
                Add-Finding 'inconsistent-spelling' 'warning' $second.line $k $spellings `
                    "In $($scope.type) '$($scope.name)', '$k' is spelled $($spellings -join ' and '): identifiers are case-insensitive, so these are one variable."
            }
        }
    }

    function Complete-Class($scope) {
        $groups = @{}
        foreach ($item in @($scope.defs) + @($scope.refs)) {
            $key = "$([bool]$item.static)|$($item.name.ToLowerInvariant())"     # static and instance members are separate namespaces
            if (-not $groups.ContainsKey($key)) { $groups[$key] = [Collections.Generic.List[object]]::new() }
            $groups[$key].Add($item)
        }
        foreach ($groupKey in $groups.Keys) {
            $key = $groupKey.Substring($groupKey.IndexOf('|') + 1)
            $items = @($groups[$groupKey] | Sort-Object line)
            $spellings = @($items | ForEach-Object { $_.name } | Select-Object -Unique)
            if (@($spellings | Select-Object -Unique).Count -lt 2) { continue }
            $callable = @($items | Where-Object { $_.kind -in 'method', 'property' })
            $collided = $false
            $defs = @($items | Where-Object { $_.kind -in 'method', 'property', 'field' })
            $defSpellings = @($defs | ForEach-Object { $_.name } | Select-Object -Unique)
            if ($callable.Count -and $defSpellings.Count -ge 2) {
                $later = $defs | Where-Object { $_.name -cne $defSpellings[0] } | Select-Object -First 1
                Add-Finding 'class-member-collision' 'error' $later.line $key $defSpellings `
                    "In class $($scope.name), '$($later.name)' and '$($defSpellings[0])' define one member twice: identifiers are case-insensitive."
                $collided = $true
            }
            foreach ($a in @($items | Where-Object { $_.kind -eq 'assign' })) {
                if ($collided) { break }
                $clash = @($callable | Where-Object { $_.name -cne $a.name })
                if ($clash.Count) {
                    Add-Finding 'class-member-collision' 'error' $a.line $key $spellings `
                        "In class $($scope.name), '$($a.name)' is assigned but $($clash[0].kind) '$($clash[0].name)' (line $($clash[0].line)) is the same name: identifiers are case-insensitive."
                    $collided = $true
                    break
                }
            }
            if (-not $collided) {
                $second = $items | Where-Object { $_.name -cne $spellings[0] } | Select-Object -First 1
                Add-Finding 'inconsistent-member-spelling' 'warning' $second.line $key $spellings `
                    "In class $($scope.name), member '$key' is spelled $($spellings -join ' and '): identifiers are case-insensitive, so these are one member."
            }
        }
    }

    $stack = [Collections.Generic.List[hashtable]]::new()
    $stack.Add((New-VarScope 'global' 'the script'))
    $stack[0].bodyDepth = 0
    $depth = 0
    $pending = $null

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $lineNo = $index + 1
        $work = $lines[$index]
        $t = $work.Trim()
        $top = $stack[$stack.Count - 1]
        $newScope = $null
        $arrow = $false
        $isStatic = [bool]($t -match '^static\s')

        if ($null -eq $pending -and $t -ne '') {
            if ($t -match '^class\s+([A-Za-z_]\w*)(?:\s+extends\s+[\w.]+)?\s*(\{.*)?$') {
                $newScope = @{ type = 'class'; name = $Matches[1]; defs = [Collections.Generic.List[object]]::new(); refs = [Collections.Generic.List[object]]::new() }
                $work = $Matches[2]
            } elseif ($t -match '^([^\s:]+(?:\s*&\s*[^\s:]+)?)::\s*(\{.*)?$' -and ($Matches[2] -or (Test-NextLineOpensBrace $index))) {
                $newScope = New-VarScope 'function' "hotkey $($Matches[1])"
                $work = $Matches[2]
            } elseif ($t -match '^(?:static\s+)?([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)\s*(\{.*|=>.*)?$' -and -not $Keywords.Contains($Matches[1]) -and ($Matches[3] -or (Test-NextLineOpensBrace $index))) {
                $newScope = New-VarScope 'function' $Matches[1]
                $paramText = $Matches[2]
                if ($top.type -eq 'class') { $top.defs.Add([pscustomobject]@{ name = $Matches[1]; kind = 'method'; line = $lineNo; static = $isStatic }) }
                $work = $Matches[3]
                foreach ($pn in @(Get-ParamNames $paramText)) {
                    $newScope.bound.Add([pscustomobject]@{ name = $pn; line = $lineNo; kind = 'param' })
                    $newScope.tokens.Add([pscustomobject]@{ name = $pn; line = $lineNo })
                }
            } elseif ($top.type -eq 'class' -and $t -match '^(?:static\s+)?([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*(\{.*|=>.*)?$' -and -not $Keywords.Contains($Matches[1]) -and ($Matches[2] -or (Test-NextLineOpensBrace $index))) {
                $newScope = @{ type = 'property'; name = $Matches[1] }
                $top.defs.Add([pscustomobject]@{ name = $Matches[1]; kind = 'property'; line = $lineNo; static = $isStatic })
                $work = $Matches[2]
            }
            if ($top.type -eq 'class' -and $null -eq $newScope -and $t -match '^(?:static\s+)?([A-Za-z_]\w*)\s*:=') {
                $top.defs.Add([pscustomobject]@{ name = $Matches[1]; kind = 'field'; line = $lineNo; static = $isStatic })
            }
            if ($null -ne $newScope -and $work -and $work.TrimStart().StartsWith('=>')) { $arrow = $true }
            if ($null -ne $newScope -and -not $arrow) { $pending = $newScope }
        }
        if ($null -eq $work) { $work = '' }
        if ($arrow) { $newScope.bodyDepth = -1; $stack.Add($newScope) }

        $seg = [Text.StringBuilder]::new()
        $flush = {
            param($text)
            $vs = $stack[$stack.Count - 1]
            if ($vs.type -eq 'function' -or $vs.type -eq 'global') {
                foreach ($m in [regex]::Matches($text, "(?<![\w.%])([A-Za-z_]\w*)\s*$AssignOp")) {
                    if (-not $Keywords.Contains($m.Groups[1].Value)) { $vs.bound.Add([pscustomobject]@{ name = $m.Groups[1].Value; line = $lineNo; kind = 'assign' }) }
                }
                foreach ($m in [regex]::Matches($text, '\bfor\s+([^{=]*?)\s+in\b')) {
                    foreach ($pn in @(Get-ParamNames $m.Groups[1].Value)) { $vs.bound.Add([pscustomobject]@{ name = $pn; line = $lineNo; kind = 'for' }) }
                }
                foreach ($m in [regex]::Matches($text, '\bcatch\b[^{]*?\bas\s+([A-Za-z_]\w*)')) {
                    $vs.bound.Add([pscustomobject]@{ name = $m.Groups[1].Value; line = $lineNo; kind = 'catch' })
                }
                foreach ($m in [regex]::Matches($text, '(?<![\w.%])([A-Za-z_]\w*)')) {
                    if ($Keywords.Contains($m.Groups[1].Value)) { continue }
                    # `Key:` in an object literal is a property name, not a use of a variable.
                    $before = $text.Substring(0, $m.Index)
                    $after = $text.Substring($m.Index + $m.Length)
                    if ($before -match '(^|[{,])\s*$' -and $after -match '^\s*:(?![=:])') { continue }
                    $vs.tokens.Add([pscustomobject]@{ name = $m.Groups[1].Value; line = $lineNo; member = $after -match '^[.(]' })
                }
                foreach ($m in [regex]::Matches($text, '(?<![\w.%])([A-Za-z_]\w*)\s*\(')) {
                    if (-not $Keywords.Contains($m.Groups[1].Value)) { $vs.calls.Add([pscustomobject]@{ name = $m.Groups[1].Value; line = $lineNo }) }
                }
            }
            $cls = $null
            for ($k = $stack.Count - 1; $k -ge 0; $k--) { if ($stack[$k].type -eq 'class') { $cls = $stack[$k]; break } }
            if ($cls) {
                foreach ($m in [regex]::Matches($text, "(?<![\w.])this\.([A-Za-z_]\w*)(\s*$AssignOp)?")) {
                    $cls.refs.Add([pscustomobject]@{ name = $m.Groups[1].Value; kind = $(if ($m.Groups[2].Success) { 'assign' } else { 'use' }); line = $lineNo; static = $false })
                }
                foreach ($m in [regex]::Matches($text, "(?<![\w.])$([regex]::Escape($cls.name))\.([A-Za-z_]\w*)(\s*$AssignOp)?")) {
                    $cls.refs.Add([pscustomobject]@{ name = $m.Groups[1].Value; kind = $(if ($m.Groups[2].Success) { 'assign' } else { 'use' }); line = $lineNo; static = $true })
                }
            }
        }
        foreach ($ch in $work.ToCharArray()) {
            if ($ch -eq '{') {
                & $flush $seg.ToString(); [void]$seg.Clear()
                $depth++
                if ($null -ne $pending) { $pending.bodyDepth = $depth; $stack.Add($pending); $pending = $null }
            } elseif ($ch -eq '}') {
                & $flush $seg.ToString(); [void]$seg.Clear()
                $topScope = $stack[$stack.Count - 1]
                if ($stack.Count -gt 1 -and $topScope.bodyDepth -eq $depth) {
                    if ($topScope.type -eq 'class') { Complete-Class $topScope }
                    if ($topScope.type -eq 'function') { Complete-VarScope $topScope }
                    $stack.RemoveAt($stack.Count - 1)
                }
                if ($depth -gt 0) { $depth-- }
            } else { [void]$seg.Append($ch) }
        }
        & $flush $seg.ToString()
        if ($arrow) { Complete-VarScope $stack[$stack.Count - 1]; $stack.RemoveAt($stack.Count - 1) }
    }
    while ($stack.Count -gt 1) {
        $s = $stack[$stack.Count - 1]
        if ($s.type -eq 'class') { Complete-Class $s }
        if ($s.type -eq 'function') { Complete-VarScope $s }
        $stack.RemoveAt($stack.Count - 1)
    }
    Complete-VarScope $stack[0]
    return $findings
}

$files = foreach ($p in $Path) {
    if (Test-Path -LiteralPath $p -PathType Container) { Get-ChildItem -LiteralPath $p -Filter *.ahk -Recurse -File | ForEach-Object FullName }
    else { (Resolve-Path -LiteralPath $p).ProviderPath }
}
$all = [Collections.Generic.List[object]]::new()
foreach ($f in $files) { foreach ($finding in (Get-NameCaseFindings $f)) { $all.Add($finding) } }

$result = [ordered]@{
    filesScanned = @($files).Count
    errors       = @($all | Where-Object severity -eq 'error').Count
    warnings     = @($all | Where-Object severity -eq 'warning').Count
    findings     = @($all.ToArray())
}
ConvertTo-Json -InputObject $result -Depth 6
exit $(if ($all.Count) { 1 } else { 0 })
