# Nodelist Subscription Support — Design

**Date:** 2026-04-12
**Branch:** feature/nodelist-subscription
**Status:** approved

## Problem

`SubscriptionService.fetchSubscription` reads the HTTP body of a subscription
URL and stores it verbatim into `ClashProfile.yamlContent`, assuming every feed
is clash YAML. A large class of real-world feeds (v2rayN "nodelist" style —
including the reference feed we use in dev) return **base64-encoded proxy URIs**
instead: one `vless://...` / `vmess://...` / `ss://...` / `trojan://...` per
line, joined and base64-wrapped. When such a feed is stored and handed to
`MihomoInstance`, the Go engine's `hub.Parse` fails.

We need the app to accept both formats and, for nodelist feeds, synthesize a
minimal clash config that the embedded mihomo engine will accept.

## Non-goals

- Supporting subscription-userinfo headers (`subscription-userinfo: upload=...`)
  used for traffic quotas. Out of scope; can be added later.
- Writing a Kotlin-side URI parser. We delegate to mihomo's upstream converter.
- Exposing the real dev subscription URL, token, or any decoded UUIDs in the
  public repository. The CI fixture is entirely synthetic.

## Architecture

```
SubscriptionService.fetchSubscription (Kotlin)
    │  raw bytes from HTTP
    ▼
isClashYaml(raw) / isBase64Body(raw)
    ├── clash yaml → store as-is (unchanged path)
    └── nodelist  → MihomoEngine.nativeConvertSubscription(raw)
                         │
                         ▼
                    Go convert.go:
                        1. best-effort base64 decode
                        2. common/convert.ConvertsV2Ray(lines)
                        3. wrap proxies in minimal clash template
                        4. yaml.Marshal → return string
                         │
                         ▼
                    ClashProfile.yamlContent populated
```

### Detection heuristic (Kotlin)

Given raw body bytes:

1. Decode as UTF-8 (replacement on failure).
2. Strip BOM / leading whitespace.
3. If the first 512 characters contain any of: `proxies:`, `proxy-groups:`,
   `mixed-port:`, `port:`, `mode:` at column 0 of a line → **clash yaml**,
   return as-is.
4. Otherwise, if the body matches `^[A-Za-z0-9+/=\s]+$` → **base64 nodelist**.
5. Otherwise if the body contains lines starting with a known scheme
   (`vless://`, `vmess://`, `ss://`, `trojan://`, `hysteria2://`, `tuic://`) →
   **plain-text nodelist**.
6. Otherwise → throw `UnsupportedSubscriptionFormat`.

Cases 4 and 5 both go to `nativeConvertSubscription`.

### Go converter (`core/src/main/go/mihomo-core/convert.go`)

New file exporting `convertSubscription(data []byte) (string, error)`:

1. Trim whitespace.
2. If `base64.StdEncoding.DecodeString` (with `RawStdEncoding` fallback)
   succeeds and the decoded bytes are valid UTF-8 with newline-separated
   scheme URIs, use the decoded bytes; else use the raw bytes.
3. Split by `\n`, drop blank / comment lines.
4. Call `github.com/metacubex/mihomo/common/convert.ConvertsV2Ray(lines)` —
   returns `[]map[string]any` proxy maps.
5. Assign a fallback name to any proxy without one (`Node-{index}`).
6. Build the wrapper:

   ```yaml
   proxies:
     - { ... }
     - { ... }
   proxy-groups:
     - name: Proxy
       type: select
       proxies: [Node-1, Node-2, ...]
   rules:
     - MATCH,Proxy
   ```

7. `yaml.Marshal` and return.

Corresponding `//export convertSubscription` that packages `(C.char*, C.int,
C.char*)` back to the C bridge (result, length, error-or-null), matching the
error conventions of the existing exports.

### JNI bridge additions

`jni_bridge.c`:

```c
JNIEXPORT jstring JNICALL
Java_io_github_madeye_meow_core_MihomoEngine_nativeConvertSubscription(
    JNIEnv *env, jobject thiz, jbyteArray raw);
```

- Copies the byte array into a C buffer.
- Calls `convertSubscription`.
- On success returns a `jstring`; on failure stashes the error via the existing
  `set_last_error` path and returns `NULL`.

`MihomoEngine.kt`:

```kotlin
external fun nativeConvertSubscription(raw: ByteArray): String?
```

### SubscriptionService changes

```kotlin
suspend fun fetchSubscription(profile: ClashProfile): ClashProfile = withContext(Dispatchers.IO) {
    val url = URL(profile.url)
    val conn = url.openConnection().apply {
        connectTimeout = 10_000
        readTimeout = 10_000
    }
    val raw = conn.inputStream.use { it.readBytes() }
    val yaml = if (SubscriptionFormat.isClashYaml(raw)) {
        raw.toString(Charsets.UTF_8)
    } else {
        MihomoEngine.nativeConvertSubscription(raw)
            ?: throw IllegalStateException(MihomoEngine.nativeGetLastError() ?: "convert failed")
    }
    profile.copy(
        yamlContent = yaml,
        yamlBackup = yaml,
        lastUpdated = System.currentTimeMillis(),
    )
}
```

`SubscriptionFormat` is a new sibling object holding the pure-Kotlin detection
heuristic so it is unit-testable without loading native libs.

## CI fixture

**Files added:**

- `test/fixtures/nodelist-sample.txt` — base64-wrapped body containing two
  synthetic proxies. Targets the host ssserver that `test-e2e.sh` already
  launches:

  ```
  ss://<base64(chacha20-ietf-poly1305:test-password)>@10.0.2.2:8388#test-node-1
  ss://<base64(chacha20-ietf-poly1305:test-password)>@10.0.2.2:8388#test-node-2
  ```

  (Then the whole thing is base64-encoded, committed verbatim.)

- `test/fixtures/README.md` — one paragraph explaining what the fixture is and
  why it is safe to commit.

**`test-e2e.sh` additions:**

1. Before `adb` actions, launch a local fixture server:

   ```bash
   python3 -m http.server 8088 --bind 127.0.0.1 --directory test/fixtures \
       >/tmp/meow-fixture.log 2>&1 &
   FIXTURE_PID=$!
   trap 'kill $FIXTURE_PID 2>/dev/null' EXIT
   ```

2. In the Room-injection step, insert a profile row with:

   - `url = http://10.0.2.2:8088/nodelist-sample.txt`
   - `yamlContent = ''` (forces a refresh path)
   - `selected = 1`

3. Before the `am start`, trigger a refresh via
   `adb shell am broadcast -a io.github.madeye.meow.REFRESH_SELECTED` (new
   broadcast receiver added in Kotlin, gated behind `BuildConfig.DEBUG`), and
   poll `sqlite3` for `yamlContent NOT LIKE ''` before continuing.

4. The existing 5 connectivity assertions run unchanged against the converted
   config.

**Not committed:** real `edt.maxlv.net` URL, real tokens, logcat dumps
(`e2e-logcat.log`), UI dumps (`ui_dump_vpn_dialog.xml`). The `.gitignore` gains
entries for those two files.

## Testing

| Layer | Test | What it asserts |
|---|---|---|
| Kotlin unit | `SubscriptionFormatTest` | 4 fixtures → detection heuristic returns the right classification for clash yaml, base64 nodelist, plain-text nodelist, and random bytes. |
| Go unit | `convert_test.go` | Known base64 nodelist → `convertSubscription` result parses via `hub.Parse` without error and contains 2 proxies named `test-node-1` / `test-node-2`. |
| E2E | `test-e2e.sh` | New profile fetched from local http.server, converted on device, tun0 exists, DNS works, TCP 1.1.1.1:80 OK, TCP 8.8.8.8:443 OK, HTTP 204 OK. |

## Risks & mitigations

- **Mihomo's `common/convert` API is not a stable public interface.** If the
  upstream package moves, pin the go.mod version we already depend on and add
  a compile-time assert in `convert.go` that the expected symbol exists.
- **Base64 false positives** (a clash YAML full of ASCII could accidentally
  match `^[A-Za-z0-9+/=\s]+$`). The check in step 3 runs *first* and short-
  circuits, so YAML containing `proxies:` never reaches the base64 test.
- **Schemes unsupported by `ConvertsV2Ray`** (e.g. a new `anytls://`) are
  silently dropped by mihomo. Log a warning from Go with the count of skipped
  lines so users can see the discrepancy in logcat.

## Team execution

After this spec is approved and a plan is written, dispatch two subagents:

- **dev** — implements Go converter, JNI glue, Kotlin detection, fixture,
  `test-e2e.sh` wiring, `.gitignore` updates.
- **qa** — writes the Kotlin and Go unit tests first (TDD), reviews dev's diff
  against this spec, runs every lint command from `CLAUDE.md`, runs
  `test-e2e.sh`, reports findings back.

The dev agent must not mark the task complete until qa's verification has run
against the final diff.
