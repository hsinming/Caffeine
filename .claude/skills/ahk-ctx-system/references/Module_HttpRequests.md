# Module_HttpRequests.md
<!-- DOMAIN: Network — file download and synchronous/responsive HTTP requests with WinHttp.WinHttpRequest.5.1 -->
<!-- SCOPE: Download(), the WinHttp.WinHttpRequest.5.1 COM object (Open, SetRequestHeader, Send, WaitForResponse, Status, ResponseText, ResponseBody, SetTimeouts, SetCredentials, SetProxy), GET/POST/PUT/DELETE, headers, Basic/Bearer auth, URL encoding, status checks. Fully non-blocking polling, Promise-style concurrency and periodic pollers are in Module_HttpAsync.md. JSON parsing/serialization and REST client classes are in Module_JsonAndRestClients.md. -->
<!-- TRIGGERS: Download, WinHttp.WinHttpRequest.5.1, WinHttpRequest, ComObject HTTP, "HTTP request", "HTTP GET", "HTTP POST", "fetch URL", "web request", "API call", setRequestHeader, responseText, ResponseBody, status code, SetTimeouts, SetCredentials, SetProxy, "Bearer token", "Basic auth", "download file", "URL encode", "query string" -->
<!-- CONSTRAINTS: Create the request object with ComObject("WinHttp.WinHttpRequest.5.1") — ComObjCreate() was removed in v2. Download() throws on failure but a server error page can be saved as if it were the file. WinHttp does not throw for HTTP 4xx/5xx — check .Status. Open(..., false) blocks the script until the response arrives; the AHK docs show Open(..., true) + WaitForResponse() to keep the script responsive. Network-level failures (DNS, connect, timeout) surface as COM exceptions from Send/WaitForResponse. -->
<!-- CROSS-REF: Module_HttpAsync.md, Module_JsonAndRestClients.md, Module_COMAutomation.md, Module_ExceptionHandling.md, Module_FilesAndFolders.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `ComObjCreate("WinHttp.WinHttpRequest.5.1")` | `ComObject("WinHttp.WinHttpRequest.5.1")` | `ComObjCreate` was removed — load-time VarUnset warning / `UnsetError` |
| `UrlDownloadToFile, url, file` | `Download(url, file)` | v1 command renamed; failure throws instead of setting ErrorLevel |
| `if ErrorLevel` after a download | `try Download(...)` / `catch as e` | ErrorLevel was removed |

## API QUICK-REFERENCE

### Download (built-in)

| Function | Signature | Throws | Notes |
|----------|-----------|--------|-------|
| `Download()` | `Download(URL, Filename)` | exception on failure (type not stated in the docs) | Blocks until done; overwrites `Filename`; relative paths use `A_WorkingDir`. Many servers send an error page for a missing file, and that page is saved as the result. Prefix `"*0 "` to the URL to allow the IE cache; IE proxy settings are used; FTP URLs are supported |

### WinHttp.WinHttpRequest.5.1 — Core Members

> The member list below comes from Microsoft's WinHttpRequest documentation, not from the AutoHotkey docs (COM members are case-insensitive).

| Member | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `ComObject()` | `ComObject("WinHttp.WinHttpRequest.5.1")` | COM object | Throws if creation fails |
| `.SetTimeouts()` | `.SetTimeouts(resolveMs, connectMs, sendMs, receiveMs)` | — | All in milliseconds; this module passes `0` for resolve (see constraints) |
| `.Open()` | `.Open(Method, Url, Async := false)` | — | `Async = true` + `.WaitForResponse()` keeps the script responsive (pattern shown in the AHK `Download` docs) |
| `.SetRequestHeader()` | `.SetRequestHeader(Name, Value)` | — | After `Open`, before `Send` |
| `.Send()` | `.Send(Body?)` | — | String body (or a byte array); returns at once when `Async = true` |
| `.WaitForResponse()` | `.WaitForResponse(TimeoutSecs?)` | True if the response arrived, false on timeout | No argument = wait without limit |
| `.Abort()` | `.Abort()` | — | Cancels an async request |
| `.Status` / `.StatusText` | read-only | Integer / String | HTTP status; 4xx/5xx do **not** raise exceptions |
| `.ResponseText` | read-only | String | Body decoded as text |
| `.ResponseBody` | read-only | Byte SAFEARRAY | Raw body — use for binary content |
| `.GetAllResponseHeaders()` / `.GetResponseHeader(Name)` | — | String | Response headers |
| `.SetCredentials()` | `.SetCredentials(User, Password, Flags)` | — | Flags `0` = server, `1` = proxy |
| `.SetProxy()` | `.SetProxy(Setting, Server?, Bypass?)` | — | Setting `0` default, `1` direct, `2` named proxy |
| `.SetClientCertificate()` / `.SetAutoLogonPolicy()` / `.Option[id]` | — | — | TLS client certificate, NTLM/Kerberos logon policy, raw WinHTTP options |

### Helper Functions Defined in This Module

| Function | Purpose |
|----------|---------|
| `UriEncode(str)` | UTF-8 percent-encoding of one query component |
| `BuildQueryString(map)` | `?k=v&...` from a Map |
| `BasicAuthHeader(user, pass)` | `"Basic <base64>"` via `CryptBinaryToStringW` |
| `HttpSend(method, url, body?, headers?)` | Generic request returning `Map("status", "body", "headers")` |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 form from V1 → V2 BREAKING CHANGES remains: `ComObjCreate`, `UrlDownloadToFile`, `ErrorLevel`.
- Always read `.Status` before trusting `.ResponseText` — WinHttp returns error pages normally.
  ✗ `return xhr.ResponseText` → ✓ check `xhr.Status` first
- Read binary responses from `.ResponseBody` (or use `Download()`), not `.ResponseText`.
  ✗ `.ResponseText` for images/ZIPs → ✓ `.ResponseBody` or `Download()`
- `Open(..., false)` blocks the script (GUI, hotkeys and timers stall) until the response arrives. For GUI scripts use `Open(..., true)`, `Send()`, then `WaitForResponse()` — the AHK `Download` docs state this "allows the script to remain responsive".
  ✗ `Open("GET", url, false)` in a GUI handler → ✓ `Open(..., true)` + `WaitForResponse()`
- `Download()` throws on failure, but an HTTP error page may be saved as the file — validate the result (size, content, or use WinHttp to check `.Status` first).
- Wrap `Send`/`WaitForResponse`/`Download` in `try` where network failure must be handled; failures arrive as COM exceptions (catch `Error`, since the exact class is not documented).
- Always passing `0` as the first `SetTimeouts` argument (resolve timeout) is a **repo convention** based on Microsoft's note about name-resolution timeouts; it is not an AutoHotkey rule.
- Preferring WinHttp over `Msxml2.XMLHTTP`/`ServerXMLHTTP` is a **repo convention**; the AHK docs show examples of both.
- URL-encode query parameters (UTF-8) and escape strings embedded in JSON bodies (see Module_JsonAndRestClients.md).
  ✗ `url "?q=" userInput` → ✓ `BuildQueryString(Map("q", userInput))`

## RUNTIME ERROR MAPPING

| Exception / Failure | Trigger Condition | Detection | Fix |
|---------------------|-------------------|-----------|-----|
| COM exception (catch `Error`) | DNS failure, refused connection, timeout during `Send`/`WaitForResponse` | `e.Message` contains the WinHTTP error code (e.g. `0x80072EE7` name not resolved, `0x80072EFD` cannot connect, `0x80072EFE` connection aborted) | `try`/`catch`; retry with backoff; verify the URL |
| Wrong data, no exception | HTTP 4xx/5xx treated as success | `.Status >= 400` | Check `.Status`; surface `.StatusText` |
| Exception from `Download` | Network/disk failure | `e.Message` | `try`/`catch`; ensure the folder exists |
| Saved file is an HTML error page | Server returned an error page | File content/size | Check status with WinHttp first, or validate the file |

## TIER 1 — Basic File Download
> METHODS COVERED: Download · SplitPath · DirExist · DirCreate · FileGetSize

```ahk
#Requires AutoHotkey v2.0
DownloadFile(url, destPath) {
    SplitPath(destPath, , &destDir)
    if destDir != "" && !DirExist(destDir)
        DirCreate(destDir)
    try {
        Download(url, destPath)
    } catch as e {                                  ; exception class not documented — catch all Errors
        MsgBox("Download failed: " e.Message, "Download", 16)
        return false
    }
    if !FileExist(destPath) || FileGetSize(destPath) = 0
        return false
    return true          ; note: may still be a server error page — see constraints
}

if DownloadFile("https://www.autohotkey.com/download/2.0/version.txt", A_Temp "\ahk_version.txt")
    MsgBox(FileRead(A_Temp "\ahk_version.txt"))
```

## TIER 2 — GET Request (blocking and responsive forms)
> METHODS COVERED: ComObject · SetTimeouts · Open · Send · WaitForResponse · Status · ResponseText · UriEncode · BuildQueryString

```ahk
#Requires AutoHotkey v2.0
HttpGet(url, responsive := true) {
    xhr := ComObject("WinHttp.WinHttpRequest.5.1")
    xhr.SetTimeouts(0, 10000, 30000, 30000)          ; resolve 0 (repo convention), connect, send, receive
    xhr.Open("GET", url, responsive)                  ; true → async
    xhr.Send()
    if responsive
        xhr.WaitForResponse()                         ; ✓ script stays responsive while waiting
    if xhr.Status = 200
        return xhr.ResponseText
    throw Error("HTTP " xhr.Status " " xhr.StatusText, -1, url)
}

UriEncode(str) {
    buf := Buffer(StrPut(str, "UTF-8"))
    StrPut(str, buf, "UTF-8")
    out := ""
    Loop buf.Size - 1 {                               ; skip the null terminator
        b := NumGet(buf, A_Index - 1, "UChar")
        out .= (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
            || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E ? Chr(b) : Format("%{:02X}", b)
    }
    return out
}

BuildQueryString(params) {
    qs := ""
    for k, v in params
        qs .= (qs = "" ? "?" : "&") UriEncode(k) "=" UriEncode(v)
    return qs
}

try {
    body := HttpGet("https://api.example.com/search" BuildQueryString(Map("q", "autohotkey v2")))
    MsgBox(SubStr(body, 1, 300))
} catch as e {
    MsgBox("Request failed: " e.Message)
}

; ✗ return xhr.ResponseText without checking Status — error pages look like success
```

## TIER 3 — POST, Headers and Authentication
> METHODS COVERED: SetRequestHeader · GetAllResponseHeaders · SetCredentials · BasicAuthHeader · HttpSend

```ahk
#Requires AutoHotkey v2.0
HttpSend(method, url, payload := "", headers := Map()) {
    xhr := ComObject("WinHttp.WinHttpRequest.5.1")
    xhr.SetTimeouts(0, 10000, 30000, 30000)
    xhr.Open(method, url, true)
    for name, value in headers
        xhr.SetRequestHeader(name, value)             ; after Open, before Send
    xhr.Send(payload)
    xhr.WaitForResponse()
    return Map("status", xhr.Status, "body", xhr.ResponseText,
               "headers", xhr.GetAllResponseHeaders())
}

BasicAuthHeader(user, pass) {
    cred := user ":" pass
    bin := Buffer(StrPut(cred, "UTF-8"))
    len := StrPut(cred, bin, "UTF-8") - 1             ; bytes without the null
    flags := 0x1                                      ; CRYPT_STRING_BASE64
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", bin, "UInt", len, "UInt", flags,
        "Ptr", 0, "UInt*", &chars := 0)
    out := Buffer(chars * 2)
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", bin, "UInt", len, "UInt", flags,
        "Ptr", out, "UInt*", &chars)
    return "Basic " Trim(StrGet(out, "UTF-16"), "`r`n ")   ; strip the trailing CRLF
}

; Bearer token + JSON body
res := HttpSend("POST", "https://api.example.com/users", '{"name":"Alice"}',
    Map("Content-Type", "application/json", "Authorization", "Bearer TOKEN"))
if res["status"] >= 400
    MsgBox("API error " res["status"] ": " SubStr(res["body"], 1, 200))

; Built-in server authentication instead of a manual header
AuthGet(url, user, pass) {
    xhr := ComObject("WinHttp.WinHttpRequest.5.1")
    xhr.Open("GET", url, true)
    xhr.SetCredentials(user, pass, 0)                 ; 0 = server, 1 = proxy
    xhr.Send()
    xhr.WaitForResponse()
    return xhr.Status
}
; PUT/PATCH/DELETE use the same HttpSend call with another method string.
```

### Performance Notes

- Reuse a request object for sequential calls when convenient; `Open` starts a new request on the same object.
- Batch endpoints beat one request per item; each request pays DNS/TCP/TLS setup.
- For binary downloads with headers or auth, read `.ResponseBody` or use `Download()` when no custom headers are needed.

## DROP-IN RECIPES

```ahk
; HttpFetch — one request with options Map: headers, body, contentType, connectMs, sendMs, receiveMs
HttpFetch(method, url, opts := Map()) {
    if !RegExMatch(url, "i)^https?://")
        throw ValueError("HttpFetch: url must start with http:// or https://", -1, url)
    xhr := ComObject("WinHttp.WinHttpRequest.5.1")
    xhr.SetTimeouts(0, opts.Get("connectMs", 10000), opts.Get("sendMs", 30000), opts.Get("receiveMs", 30000))
    xhr.Open(method, url, true)
    if opts.Has("headers")
        for k, v in opts["headers"]
            xhr.SetRequestHeader(k, v)
    body := opts.Get("body", "")
    if body != ""
        xhr.SetRequestHeader("Content-Type", opts.Get("contentType", "application/json; charset=UTF-8"))
    try {
        xhr.Send(body)
        xhr.WaitForResponse()
    } catch as e {
        throw Error("HttpFetch [" method " " url "]: " e.Message, -1)
    }
    return Map("status", xhr.Status, "body", xhr.ResponseText, "headers", xhr.GetAllResponseHeaders())
}
; Call site: res := HttpFetch("GET", "https://api.example.com/data")
;            if res["status"] = 200
;                MsgBox(res["body"])

; SafeDownload — retries with increasing delay; returns true or throws
SafeDownload(url, destPath, maxRetries := 2, delayMs := 1000) {
    SplitPath(destPath, , &dir)
    if dir != "" && !DirExist(dir)
        DirCreate(dir)
    Loop maxRetries + 1 {
        try {
            Download(url, destPath)
            return true
        } catch as e {
            if A_Index > maxRetries
                throw Error("SafeDownload failed after " A_Index " attempts: " e.Message, -1, url)
            Sleep(delayMs * A_Index)
        }
    }
}
```

## SEE ALSO

> This module does NOT cover: SetTimer polling, HttpPromise, concurrent requests, periodic pollers → see Module_HttpAsync.md
> This module does NOT cover: JSON parsing/serialization, REST client classes → see Module_JsonAndRestClients.md
> This module does NOT cover: other COM automation → see Module_COMAutomation.md

- `Module_HttpAsync.md` — non-blocking request patterns and Promise-style helpers.
- `Module_JsonAndRestClients.md` — JSON handling and a reusable REST client.
- `Module_COMAutomation.md` — COM object lifecycle in general.
- `Module_ExceptionHandling.md` — error handling and retry patterns.
