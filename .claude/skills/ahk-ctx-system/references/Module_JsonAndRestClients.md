# Module_JsonAndRestClients.md
<!-- DOMAIN: Network — JSON handling (no built-in parser) and reusable REST API client classes -->
<!-- SCOPE: Why AHK v2 has no JSON object, using a third-party JSON library, RegExMatch extraction for flat JSON, manual serialization of flat Maps with escaping, a RestClient class (base URL, token, retries with backoff, 429/5xx handling, rate limiting) and a subclass example. WinHttp request basics are in Module_HttpRequests.md; async patterns are in Module_HttpAsync.md. -->
<!-- TRIGGERS: JSON, "JSON parse", "JSON stringify", JSON.Parse, JSON.Stringify, Jxon, "parse API response", "build JSON payload", JsonEscape, "REST API", "API client", "retry request", "rate limit", "429", "exponential backoff", "Bearer token refresh", RestClient, "GitHub API" -->
<!-- CONSTRAINTS: AutoHotkey v2.0 has no built-in JSON parser or serializer — JSON.Parse()/JSON.Stringify() fail unless the script defines such an object. Full JSON needs a third-party library (#Include it); its function names depend on the library. RegExMatch extraction is only safe for flat, known fields. Arrays produced from JSON are AHK Arrays (1-based). Escape \, ", control characters when building JSON by hand. -->
<!-- CROSS-REF: Module_HttpRequests.md, Module_HttpAsync.md, Module_ClassBasics.md, Module_Maps.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `JSON.Parse(text)` / `JSON.Stringify(obj)` (assumed built-in) | A JSON library loaded with `#Include`, or the helpers below | AutoHotkey v2 has no built-in `JSON` object — load-time VarUnset warning / `UnsetError` |
| v1 JSON libraries (`JSON.ahk` for v1, `obj.key` access on parsed data) | A v2 JSON library; parsed objects are typically `Map`/`Array` | v1 libraries use v1 syntax and do not load in v2 |
| `data.items[0]` | `data["items"][1]` | AHK Arrays are 1-based; index 0 throws `IndexError`. Map items use `[key]`, not `.key` |

## API QUICK-REFERENCE

### JSON Approaches

| Approach | Use for | Limits |
|----------|---------|--------|
| Third-party JSON library (e.g. a "Jxon" port for v2) | Any real JSON (nested objects, arrays, escapes) | Third-party: check its README for exact function names (for example `Jxon_Load(&text)`/`Jxon_Dump(obj)` in one popular v2 port, `Jxon.Load()`-style in others) |
| `ExtractJsonField(json, name)` (TIER 1) | One known flat field from a small response | Breaks on nesting, duplicate names, arrays |
| `MapToJsonFlat(map)` + `JsonEscape(str)` (TIER 1) | Small flat outbound payloads | No nesting or arrays of objects |

### Helper Functions Defined in This Module

| Function | Returns | Notes |
|----------|---------|-------|
| `JsonEscape(str)` | Escaped string | `\`, `"`, `\n`, `\r`, `\t`, other control chars as `\u00XX` |
| `MapToJsonFlat(m)` | JSON object text | Numbers unquoted, everything else as strings |
| `ExtractJsonField(json, name)` | Field value or `""` | String, number, `true`/`false`/`null` |
| `RestClient` | Class | `Get`, `Post`, `Put`, `Delete`, `SetToken`, `RefreshToken` (override), `Execute` with retries |

### Library Contract Assumed by TIER 2

The RestClient code calls two small adapter functions — define them once for whichever JSON library you include:

```ahk
JsonLoad(text) => Jxon_Load(&text)   ; adapt to your library's parse function
JsonDump(obj)  => Jxon_Dump(obj)     ; adapt to your library's serialize function
```

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- AutoHotkey has no built-in JSON; never emit `JSON.Parse`/`JSON.Stringify` unless the script defines them. Name the library and `#Include` it. The wrong form is in V1 → V2 BREAKING CHANGES.
- Third-party library APIs are **outside the AutoHotkey docs** — verify the include path and function names against the library you ship; adapter names must match the library.
- RegEx extraction is a shortcut for flat responses only; use a real parser for anything nested.
- Always escape user-provided strings when building JSON by hand (`JsonEscape`).
  ✗ `'{"name":"' input '"}'` → ✓ `MapToJsonFlat(Map("name", input))`
- Parsed JSON arrays are 1-based AHK Arrays (when the library returns `Array`); objects are usually `Map`s accessed with `["key"]`. The wrong forms are in V1 → V2 BREAKING CHANGES.
- Check `Status` before parsing — error responses may be HTML.
- Bound every retry loop.
  ✗ `Loop` retry with no cap → ✓ `maxRetries` + backoff

## RUNTIME ERROR MAPPING

| Exception / Failure | Trigger Condition | Detection | Fix |
|---------------------|-------------------|-----------|-----|
| VarUnset warning / `UnsetError` | `JSON.Parse(...)` with no JSON library | Load-time warning names `JSON` | `#Include` a library and use its functions |
| `IndexError` | `arr[0]` on a parsed array | `e is IndexError` | Use `arr[1]` |
| `UnsetItemError` | `map["missing"]` | `e is UnsetItemError` | `map.Has(k)` or `map.Get(k, default)` |
| Library parse error | Body is HTML or truncated | Exception from the parse function | Check `Status` and the first character (`{` or `[`) first |

## TIER 1 — JSON Without a Library (flat data only)
> METHODS COVERED: RegExMatch · JsonEscape · MapToJsonFlat · ExtractJsonField · Format

```ahk
#Requires AutoHotkey v2.0
JsonEscape(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return RegExReplace(str, "[\x00-\x1F]", "")   ; drop remaining control chars (or \u-escape them)
}

MapToJsonFlat(m) {
    out := ""
    for k, v in m {
        val := (v is Number) ? v : '"' JsonEscape(String(v)) '"'
        out .= (out = "" ? "" : ",") '"' JsonEscape(String(k)) '":' val
    }
    return "{" out "}"
}

ExtractJsonField(json, name) {
    q := "\Q" name "\E"
    if RegExMatch(json, '"' q '"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
        return m[1]                                   ; still escaped text
    if RegExMatch(json, '"' q '"\s*:\s*(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null)', &m)
        return m[1]
    return ""
}

payload := MapToJsonFlat(Map("name", 'Alice "A"', "active", 1))
; → {"name":"Alice \"A\"","active":1}
resp := '{"id":42,"username":"alice","active":true}'
MsgBox(ExtractJsonField(resp, "username") " / " ExtractJsonField(resp, "id"))

; ✗ data := JSON.Parse(resp)   ; no built-in JSON object
```

## TIER 2 — REST Client Class with Retries
> METHODS COVERED: RestClient.__New · Get · Post · Put · Delete · SetToken · IsTokenValid · RefreshToken · BuildUrl · Execute · SendRequest · ParseResponse

```ahk
#Requires AutoHotkey v2.0
; #Include <JXON>                     ; your JSON library (outside AHK docs)
; JsonLoad(text) => Jxon_Load(&text)  ; adapters — see API QUICK-REFERENCE
; JsonDump(obj)  => Jxon_Dump(obj)
; UriEncode() comes from Module_HttpRequests.md

class RestClient {
    __New(baseUrl, opts := Map()) {
        this.baseUrl     := RTrim(baseUrl, "/")
        this.token       := opts.Get("token", "")
        this.tokenExpiry := opts.Get("tokenExpiry", 0)       ; Unix seconds; 0 = none
        this.maxRetries  := opts.Get("maxRetries", 3)
        this.retryDelay  := opts.Get("retryDelay", 1000)
        this.rateLimitMs := opts.Get("rateLimitMs", 0)
        this.lastRequest := 0
        this.headers     := Map("Accept", "application/json")
        for k, v in opts.Get("headers", Map())
            this.headers[k] := v
    }

    Get(path, params := Map()) => this.Execute("GET", this.BuildUrl(path, params), "")
    Post(path, body := Map())  => this.Execute("POST", this.BuildUrl(path), IsObject(body) ? JsonDump(body) : body)
    Put(path, body := Map())   => this.Execute("PUT", this.BuildUrl(path), IsObject(body) ? JsonDump(body) : body)
    Delete(path)               => this.Execute("DELETE", this.BuildUrl(path), "")

    SetToken(token, expiry := 0) {
        this.token := token, this.tokenExpiry := expiry
    }
    IsTokenValid() {
        if this.token = ""
            return false
        now := DateDiff(A_NowUTC, "19700101000000", "Seconds")
        return !(this.tokenExpiry && now > this.tokenExpiry)
    }
    RefreshToken() {                                          ; override in subclasses
        throw Error("RefreshToken() not implemented", -1)
    }

    BuildUrl(path, params := Map()) {
        url := this.baseUrl "/" LTrim(path, "/")
        for k, v in params
            url .= (A_Index = 1 ? "?" : "&") UriEncode(k) "=" UriEncode(String(v))
        return url
    }

    Execute(method, url, payload) {
        if this.rateLimitMs && (wait := this.rateLimitMs - (A_TickCount - this.lastRequest)) > 0
            Sleep(wait)
        if this.tokenExpiry && !this.IsTokenValid()
            this.RefreshToken()
        attempt := 0
        Loop {
            attempt++
            try {
                res := this.SendRequest(method, url, payload)
            } catch as e {                                    ; network-level failure
                if attempt > this.maxRetries
                    throw Error("Request failed after " attempt " attempts: " e.Message, -1, url)
                Sleep(this.retryDelay * 2 ** (attempt - 1))
                continue
            }
            this.lastRequest := A_TickCount
            status := res["status"]
            if (status = 429 || status >= 500) && attempt <= this.maxRetries {
                delay := RegExMatch(res["headers"], "im)^Retry-After:\s*(\d+)", &m)
                    ? m[1] * 1000 : this.retryDelay * 2 ** (attempt - 1)
                Sleep(delay)
                continue
            }
            if status = 401 && attempt = 1 {
                this.RefreshToken()
                continue
            }
            return this.ParseResponse(res)
        }
    }

    SendRequest(method, url, payload) {
        xhr := ComObject("WinHttp.WinHttpRequest.5.1")
        xhr.SetTimeouts(0, 10000, 30000, 30000)
        xhr.Open(method, url, true)
        for k, v in this.headers
            xhr.SetRequestHeader(k, v)
        if this.token != ""
            xhr.SetRequestHeader("Authorization", "Bearer " this.token)
        if payload != ""
            xhr.SetRequestHeader("Content-Type", "application/json; charset=UTF-8")
        xhr.Send(payload)
        xhr.WaitForResponse()                                 ; responsive wait
        return Map("status", xhr.Status, "body", xhr.ResponseText, "headers", xhr.GetAllResponseHeaders())
    }

    ParseResponse(res) {
        if res["status"] >= 400
            throw Error("HTTP " res["status"], -1, SubStr(res["body"], 1, 300))
        body := Trim(res["body"])
        return (SubStr(body, 1, 1) ~= "[\[{]") ? JsonLoad(body) : body
    }
}

class GitHubClient extends RestClient {
    __New(token) {
        super.__New("https://api.github.com", Map("token", token, "retryDelay", 2000,
            "headers", Map("User-Agent", "AHK-v2-Client/1.0")))
    }
    GetRepo(owner, repo) => this.Get("/repos/" owner "/" repo)
    ListIssues(owner, repo, state := "open") => this.Get("/repos/" owner "/" repo "/issues", Map("state", state))
}

; try {
;     gh := GitHubClient("ghp_your_token")
;     repo := gh.GetRepo("AutoHotkey", "AutoHotkey")
;     MsgBox("Stars: " repo["stargazers_count"])
;     issues := gh.ListIssues("AutoHotkey", "AutoHotkey")
;     if issues.Length
;         MsgBox(issues[1]["title"])          ; ✓ 1-based
; } catch as e {
;     MsgBox("API error: " e.Message "`n" e.Extra)
; }
```

### Performance Notes

- Parsing a large JSON tree costs time; for a single flat field in a hot polling loop, `ExtractJsonField` is cheaper.
- Exponential backoff (`delay * 2 ** (attempt - 1)`) and honoring `Retry-After` reduce load on rate-limited APIs.
- Prefer bulk endpoints over one request per item.

## DROP-IN RECIPES

```ahk
; JsonFetch — GET + status check + parse (requires HttpFetch from Module_HttpRequests.md and JsonLoad)
JsonFetch(url, opts := Map()) {
    res := HttpFetch("GET", url, opts)
    if res["status"] >= 400
        throw Error("JsonFetch: HTTP " res["status"], -1, SubStr(res["body"], 1, 300))
    body := Trim(res["body"])
    if !(SubStr(body, 1, 1) ~= "[\[{]")
        throw Error("JsonFetch: response is not JSON", -1, SubStr(body, 1, 40))
    return JsonLoad(body)
}

; ArrayOfMapsToJson — flat Maps only
ArrayOfMapsToJson(arr) {
    out := ""
    for item in arr
        out .= (out = "" ? "" : ",") MapToJsonFlat(item)
    return "[" out "]"
}
```

## SEE ALSO

> This module does NOT cover: WinHttp members, auth, Download → see Module_HttpRequests.md
> This module does NOT cover: non-blocking/concurrent request patterns → see Module_HttpAsync.md
> This module does NOT cover: Map/Array APIs in depth → see Module_Maps.md

- `Module_HttpRequests.md` — `HttpFetch`, `UriEncode`, request basics.
- `Module_HttpAsync.md` — `HttpPromise` and polling.
- `Module_ClassBasics.md` — class inheritance and `super.__New` used by `GitHubClient`.
- `Module_Maps.md` — Map and Array handling of parsed responses.
- `Module_ExceptionHandling.md` — error handling and retry design.
