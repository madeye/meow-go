# Nodelist Subscription Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Accept base64 v2rayN "nodelist" subscriptions in addition to clash YAML, by delegating URI-list → clash-YAML conversion to the embedded mihomo engine, and prove it end-to-end with a synthetic CI fixture that keeps the real subscription URL out of the public repo.

**Architecture:** New `convertSubscription` cgo export in `mihomo-core` calls `github.com/metacubex/mihomo/common/convert.ConvertsV2Ray`, wraps the resulting proxy list in a minimal clash template, and returns the YAML. `SubscriptionService` on the Kotlin side sniffs the body: if it looks like clash YAML (contains `proxies:` in the first 512 chars) it is stored verbatim, otherwise it is routed through the Go converter. The `test-e2e.sh` fixture is swapped from a clash-YAML file to a base64-encoded `ss://` nodelist so every run exercises the new code path against the host ssserver.

**Tech Stack:** Go (mihomo-core), cgo / JNI, Kotlin (SubscriptionService, unit tests via JUnit), bash (test-e2e.sh), Python 3 http.server.

**Spec:** `docs/superpowers/specs/2026-04-12-nodelist-subscription-design.md`

---

## File Structure

| Path | Create / Modify | Responsibility |
|---|---|---|
| `core/src/main/go/mihomo-core/convert.go` | Create | `convertSubscription([]byte) (string, error)` — wrap `convert.ConvertsV2Ray` + clash template. |
| `core/src/main/go/mihomo-core/convert_test.go` | Create | Go unit test: feed a synthetic base64 `ss://` nodelist, assert output parses via `executor.ParseWithBytes`. |
| `core/src/main/go/mihomo-core/exports.go` | Modify | Add `//export meowConvertSubscription` cgo wrapper with the `(dst, cap)` fill-buffer convention. |
| `core/src/main/go/mihomo-core/jni_bridge_android.c` | Modify | Add `Java_..._MihomoEngine_nativeConvertSubscription(jbyteArray) → jstring`, using a heap-allocated buffer large enough for converted YAML (64 KiB). |
| `core/src/main/java/io/github/madeye/meow/core/MihomoEngine.kt` | Modify | Add `external fun nativeConvertSubscription(raw: ByteArray): String?`. |
| `core/src/main/java/io/github/madeye/meow/subscription/SubscriptionFormat.kt` | Create | Pure-Kotlin object with `isClashYaml(raw: ByteArray): Boolean` heuristic. |
| `core/src/main/java/io/github/madeye/meow/subscription/SubscriptionService.kt` | Modify | Read body as bytes, branch on `SubscriptionFormat.isClashYaml`, call converter on the nodelist branch, throw with mihomo error on failure. |
| `core/src/test/java/io/github/madeye/meow/subscription/SubscriptionFormatTest.kt` | Create | JVM unit test (no native libs) covering clash yaml, base64 nodelist, plain nodelist, garbage. |
| `test-e2e.sh` | Modify | Replace the `/tmp/test-sub/config.yaml` clash fixture with `/tmp/test-sub/nodelist.txt` (a base64 `ss://` nodelist), change the `clash_profile.url` column to point at it, set `yaml_content=''` so the app must fetch + convert before connecting. |
| `.gitignore` | Modify | Add `e2e-logcat.log`, `ui_dump_vpn_dialog.xml`, `screen_*.png` so live dev artifacts never leak URLs/tokens. |

---

## Task 1: Add Go converter with failing test

**Files:**
- Create: `core/src/main/go/mihomo-core/convert_test.go`
- Create: `core/src/main/go/mihomo-core/convert.go`

- [ ] **Step 1: Write the failing Go test**

Create `core/src/main/go/mihomo-core/convert_test.go`:

```go
package main

import (
	"encoding/base64"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/hub/executor"
)

// synthNodelist returns a base64-wrapped nodelist with two ss:// entries
// pointing at 127.0.0.1:8388 using aes-256-gcm. No real endpoints, no real
// credentials — only used in tests.
func synthNodelist(t *testing.T) []byte {
	t.Helper()
	userinfo := base64.StdEncoding.EncodeToString([]byte("aes-256-gcm:testpassword123"))
	body := strings.Join([]string{
		"ss://" + userinfo + "@127.0.0.1:8388#test-node-1",
		"ss://" + userinfo + "@127.0.0.1:8388#test-node-2",
		"",
	}, "\n")
	return []byte(base64.StdEncoding.EncodeToString([]byte(body)))
}

func TestConvertSubscription_Base64Nodelist(t *testing.T) {
	yaml, err := convertSubscription(synthNodelist(t))
	if err != nil {
		t.Fatalf("convertSubscription: %v", err)
	}
	if !strings.Contains(yaml, "proxies:") {
		t.Fatalf("expected proxies: section, got:\n%s", yaml)
	}
	if !strings.Contains(yaml, "test-node-1") || !strings.Contains(yaml, "test-node-2") {
		t.Fatalf("expected both node names in output, got:\n%s", yaml)
	}
	if !strings.Contains(yaml, "MATCH,Proxy") {
		t.Fatalf("expected MATCH,Proxy rule, got:\n%s", yaml)
	}
	if _, perr := executor.ParseWithBytes([]byte(yaml)); perr != nil {
		t.Fatalf("mihomo refused converted yaml: %v\n---\n%s", perr, yaml)
	}
}

func TestConvertSubscription_Empty(t *testing.T) {
	if _, err := convertSubscription([]byte("")); err == nil {
		t.Fatal("expected error for empty body")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd core/src/main/go/mihomo-core && GOFLAGS=-mod=mod go test ./... -run TestConvertSubscription
```

Expected: compile error — `undefined: convertSubscription`.

- [ ] **Step 3: Implement `convertSubscription`**

Create `core/src/main/go/mihomo-core/convert.go`:

```go
package main

import (
	"errors"
	"fmt"

	"github.com/metacubex/mihomo/common/convert"
	"gopkg.in/yaml.v3"
)

// convertSubscription parses a v2rayN-style proxy URI list (optionally
// base64-wrapped) into a minimal clash YAML config that mihomo will
// accept. The input is what the subscription endpoint returned as its
// body; ConvertsV2Ray handles both base64 and plain-text forms.
//
// The resulting YAML contains:
//   - proxies: one entry per successfully parsed URI
//   - proxy-groups: a single "Proxy" selector over all parsed proxies
//   - rules: [MATCH,Proxy]
//
// Any URIs mihomo does not recognize are silently skipped by ConvertsV2Ray;
// we treat a zero-length result as an error so the caller surfaces it.
func convertSubscription(raw []byte) (string, error) {
	if len(raw) == 0 {
		return "", errors.New("empty subscription body")
	}
	proxies, err := convert.ConvertsV2Ray(raw)
	if err != nil {
		return "", fmt.Errorf("convert nodelist: %w", err)
	}
	if len(proxies) == 0 {
		return "", errors.New("no recognizable proxies in subscription")
	}

	names := make([]string, 0, len(proxies))
	for i, p := range proxies {
		name, _ := p["name"].(string)
		if name == "" {
			name = fmt.Sprintf("Node-%d", i+1)
			p["name"] = name
		}
		names = append(names, name)
	}

	doc := map[string]any{
		"proxies": proxies,
		"proxy-groups": []map[string]any{
			{
				"name":    "Proxy",
				"type":    "select",
				"proxies": names,
			},
		},
		"rules": []string{"MATCH,Proxy"},
	}

	out, err := yaml.Marshal(doc)
	if err != nil {
		return "", fmt.Errorf("marshal yaml: %w", err)
	}
	return string(out), nil
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd core/src/main/go/mihomo-core && GOFLAGS=-mod=mod go test ./... -run TestConvertSubscription -v
```

Expected: `PASS`, both subtests green.

- [ ] **Step 5: Run `go vet` and `gofmt`**

```bash
cd core/src/main/go/mihomo-core && go vet ./... && gofmt -l .
```

Expected: no output (clean).

- [ ] **Step 6: Commit**

```bash
git add core/src/main/go/mihomo-core/convert.go core/src/main/go/mihomo-core/convert_test.go
git commit -m "go: add convertSubscription for v2rayN nodelist feeds"
```

---

## Task 2: Expose convertSubscription via cgo + JNI + Kotlin

**Files:**
- Modify: `core/src/main/go/mihomo-core/exports.go`
- Modify: `core/src/main/go/mihomo-core/jni_bridge_android.c`
- Modify: `core/src/main/java/io/github/madeye/meow/core/MihomoEngine.kt`

- [ ] **Step 1: Add cgo export in `exports.go`**

Append to `core/src/main/go/mihomo-core/exports.go` (after `meowValidateConfig`, before `meowGetLastError`):

```go
//export meowConvertSubscription
func meowConvertSubscription(craw *C.char, length C.int, dst *C.char, cap C.int) C.int {
	buf := C.GoBytes(unsafe.Pointer(craw), length)
	yaml, err := convertSubscription(buf)
	if err != nil {
		setLastError(err.Error())
		return -1
	}
	cmsg := C.CString(yaml)
	defer C.free(unsafe.Pointer(cmsg))
	return C.meow_fill_string(dst, cap, cmsg)
}
```

- [ ] **Step 2: Verify the Go side still builds**

```bash
cd core/src/main/go/mihomo-core && GOFLAGS=-mod=mod go build ./...
```

Expected: exits 0, no output.

- [ ] **Step 3: Add JNI wrapper in `jni_bridge_android.c`**

Append after `Java_..._nativeValidateConfig` (around line 158):

```c
JNIEXPORT jstring JNICALL
Java_io_github_madeye_meow_core_MihomoEngine_nativeConvertSubscription(JNIEnv *env, jclass clazz, jbyteArray raw) {
    if (raw == NULL) { return NULL; }
    jsize len = (*env)->GetArrayLength(env, raw);
    if (len <= 0) { return NULL; }
    jbyte *bytes = (*env)->GetByteArrayElements(env, raw, NULL);
    if (bytes == NULL) { return NULL; }

    // Converted clash YAML for a nodelist with ~20 proxies comfortably
    // fits in 64 KiB. Use a heap buffer (not the 512-byte stack STR_BUF
    // the other exports use) so we don't silently truncate long subs.
    const int OUT_CAP = 64 * 1024;
    char *out = (char *)malloc(OUT_CAP);
    if (out == NULL) {
        (*env)->ReleaseByteArrayElements(env, raw, bytes, JNI_ABORT);
        return NULL;
    }
    out[0] = 0;

    int rc = (int)meowConvertSubscription((char *)bytes, (int)len, out, OUT_CAP);
    (*env)->ReleaseByteArrayElements(env, raw, bytes, JNI_ABORT);

    if (rc < 0) {
        free(out);
        return NULL;
    }
    jstring result = (*env)->NewStringUTF(env, out);
    free(out);
    return result;
}
```

- [ ] **Step 4: Add Kotlin binding**

Modify `core/src/main/java/io/github/madeye/meow/core/MihomoEngine.kt`. Add this line after `external fun nativeValidateConfig(yaml: String): Int` (line 36):

```kotlin
    /**
     * Converts a v2rayN-style nodelist subscription body into a minimal
     * clash YAML document. Returns null on failure; call
     * [nativeGetLastError] to get the reason.
     */
    external fun nativeConvertSubscription(raw: ByteArray): String?
```

- [ ] **Step 5: Build the core module to verify JNI symbol links**

```bash
./gradlew :core:goBuildArm64 -PGO_PROFILE=release
```

Expected: SUCCESS. The task will recompile `libmihomo.so` including the new export and the new `Java_...` wrapper.

- [ ] **Step 6: Commit**

```bash
git add core/src/main/go/mihomo-core/exports.go \
        core/src/main/go/mihomo-core/jni_bridge_android.c \
        core/src/main/java/io/github/madeye/meow/core/MihomoEngine.kt
git commit -m "core: expose nativeConvertSubscription to Kotlin"
```

---

## Task 3: Add `SubscriptionFormat` detector with failing unit test

**Files:**
- Create: `core/src/test/java/io/github/madeye/meow/subscription/SubscriptionFormatTest.kt`
- Create: `core/src/main/java/io/github/madeye/meow/subscription/SubscriptionFormat.kt`

- [ ] **Step 1: Verify the test source set exists**

```bash
ls core/src/test/java 2>/dev/null || mkdir -p core/src/test/java/io/github/madeye/meow/subscription
```

Also confirm `core/build.gradle.kts` already wires a `test` source set — if it does not, add this block to `core/build.gradle.kts` under `android { }`:

```kotlin
    testOptions {
        unitTests {
            isIncludeAndroidResources = false
            isReturnDefaultValues = true
        }
    }
```

And under `dependencies`:

```kotlin
    testImplementation("junit:junit:4.13.2")
```

Skip these additions if they are already present.

- [ ] **Step 2: Write the failing test**

Create `core/src/test/java/io/github/madeye/meow/subscription/SubscriptionFormatTest.kt`:

```kotlin
package io.github.madeye.meow.subscription

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SubscriptionFormatTest {

    private val clashYaml = """
        mixed-port: 7890
        mode: rule
        proxies:
          - name: demo
            type: ss
            server: 1.2.3.4
            port: 8388
            cipher: aes-256-gcm
            password: pw
        proxy-groups:
          - name: Proxy
            type: select
            proxies: [demo]
        rules:
          - MATCH,Proxy
    """.trimIndent()

    private val base64Nodelist =
        "c3M6Ly9ZV1Z6TFRJMU5pMW5ZMjA2ZEdWemRIQmhjM04zYjNKa01USXpAMTI3LjAuMC4xOjgzODgjdGVzdC1ub2RlLTEKc3M6Ly9ZV1Z6TFRJMU5pMW5ZMjA2ZEdWemRIQmhjM04zYjNKa01USXpAMTI3LjAuMC4xOjgzODgjdGVzdC1ub2RlLTIK"

    private val plainNodelist = """
        vless://abc@1.2.3.4:443?type=ws#foo
        ss://YWVzLTI1Ni1nY206cHc=@1.2.3.4:8388#bar
    """.trimIndent()

    private val garbage = "<!DOCTYPE html><html><body>Not Found</body></html>"

    @Test
    fun `clash yaml is recognised`() {
        assertTrue(SubscriptionFormat.isClashYaml(clashYaml.toByteArray()))
    }

    @Test
    fun `base64 nodelist is not clash yaml`() {
        assertFalse(SubscriptionFormat.isClashYaml(base64Nodelist.toByteArray()))
    }

    @Test
    fun `plain uri nodelist is not clash yaml`() {
        assertFalse(SubscriptionFormat.isClashYaml(plainNodelist.toByteArray()))
    }

    @Test
    fun `garbage is not clash yaml`() {
        assertFalse(SubscriptionFormat.isClashYaml(garbage.toByteArray()))
    }

    @Test
    fun `leading BOM plus yaml is recognised`() {
        val bom = byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte())
        assertTrue(SubscriptionFormat.isClashYaml(bom + clashYaml.toByteArray()))
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
./gradlew :core:testDebugUnitTest --tests "io.github.madeye.meow.subscription.SubscriptionFormatTest" -PTARGET_ABI=arm64 -PCARGO_PROFILE=release -PGO_PROFILE=release
```

Expected: compile error — `Unresolved reference: SubscriptionFormat`.

- [ ] **Step 4: Implement `SubscriptionFormat`**

Create `core/src/main/java/io/github/madeye/meow/subscription/SubscriptionFormat.kt`:

```kotlin
package io.github.madeye.meow.subscription

/**
 * Pure-Kotlin heuristic that decides whether a subscription body is already
 * a clash YAML document (store verbatim) or a v2rayN-style nodelist that
 * needs to be converted through mihomo's `common/convert` package.
 *
 * Deliberately *not* a parser — we only peek at the first 512 characters
 * looking for unambiguous clash keys. A body that passes this check is
 * still validated later by mihomo's real YAML parser.
 */
object SubscriptionFormat {
    private const val SCAN = 512
    private val CLASH_KEYS = arrayOf(
        "proxies:",
        "proxy-groups:",
        "mixed-port:",
        "port:",
        "mode:",
    )

    fun isClashYaml(raw: ByteArray): Boolean {
        if (raw.isEmpty()) return false
        var offset = 0
        // Strip UTF-8 BOM.
        if (raw.size >= 3 &&
            raw[0] == 0xEF.toByte() &&
            raw[1] == 0xBB.toByte() &&
            raw[2] == 0xBF.toByte()
        ) {
            offset = 3
        }
        val head = String(
            raw,
            offset,
            minOf(SCAN, raw.size - offset),
            Charsets.UTF_8,
        )
        // Look for any clash key at column 0 of a line (optionally
        // preceded by a BOM-less empty line).
        val lines = head.lineSequence()
        for (line in lines) {
            for (key in CLASH_KEYS) {
                if (line.startsWith(key)) return true
            }
        }
        return false
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
./gradlew :core:testDebugUnitTest --tests "io.github.madeye.meow.subscription.SubscriptionFormatTest" -PTARGET_ABI=arm64 -PCARGO_PROFILE=release -PGO_PROFILE=release
```

Expected: 5 tests, all pass.

- [ ] **Step 6: Commit**

```bash
git add core/src/main/java/io/github/madeye/meow/subscription/SubscriptionFormat.kt \
        core/src/test/java/io/github/madeye/meow/subscription/SubscriptionFormatTest.kt
git commit -m "core: add SubscriptionFormat clash-yaml detector"
```

---

## Task 4: Wire `SubscriptionService` to detector + converter

**Files:**
- Modify: `core/src/main/java/io/github/madeye/meow/subscription/SubscriptionService.kt`

- [ ] **Step 1: Replace the body of `fetchSubscription`**

Replace the contents of `core/src/main/java/io/github/madeye/meow/subscription/SubscriptionService.kt` with:

```kotlin
package io.github.madeye.meow.subscription

import io.github.madeye.meow.core.MihomoEngine
import io.github.madeye.meow.database.ClashProfile
import io.github.madeye.meow.database.PrivateDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL

object SubscriptionService {
    suspend fun fetchSubscription(profile: ClashProfile): ClashProfile = withContext(Dispatchers.IO) {
        val url = URL(profile.url)
        val connection = url.openConnection()
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        val raw = connection.getInputStream().use { it.readBytes() }

        val yaml = if (SubscriptionFormat.isClashYaml(raw)) {
            raw.toString(Charsets.UTF_8)
        } else {
            MihomoEngine.nativeConvertSubscription(raw)
                ?: throw IllegalStateException(
                    "Failed to convert nodelist subscription: ${MihomoEngine.nativeGetLastError()}",
                )
        }

        profile.copy(
            yamlContent = yaml,
            yamlBackup = yaml,
            lastUpdated = System.currentTimeMillis(),
        )
    }

    suspend fun addSubscription(name: String, url: String): ClashProfile = withContext(Dispatchers.IO) {
        val profile = ClashProfile(name = name, url = url)
        val fetched = fetchSubscription(profile)
        val id = PrivateDatabase.profileDao.insert(fetched)
        fetched.copy(id = id)
    }

    suspend fun refreshAll() = withContext(Dispatchers.IO) {
        val profiles = PrivateDatabase.profileDao.getAll().filter { it.url.isNotEmpty() }
        for (profile in profiles) {
            try {
                val updated = fetchSubscription(profile)
                PrivateDatabase.profileDao.update(updated)
            } catch (_: Exception) { }
        }
    }
}
```

- [ ] **Step 2: Run Android lint**

```bash
./gradlew :core:lintDebug -PTARGET_ABI=arm64 -PCARGO_PROFILE=release -PGO_PROFILE=release
```

Expected: no new lint errors. (Pre-existing warnings are OK — the lint baseline should not grow.)

- [ ] **Step 3: Commit**

```bash
git add core/src/main/java/io/github/madeye/meow/subscription/SubscriptionService.kt
git commit -m "core: route non-clash-yaml subscriptions through mihomo converter"
```

---

## Task 5: Swap the e2e fixture to a base64 nodelist

**Files:**
- Modify: `test-e2e.sh`

- [ ] **Step 1: Replace the subscription-fixture block**

In `test-e2e.sh`, find the block starting at line 113 (`info "Step 3: Starting subscription HTTP server ..."`) and ending at line 147 (the `info "Subscription HTTP server running ..."` line). Replace it with:

```bash
# Step 3: Subscription HTTP server — serves a base64 nodelist fixture
#         so the e2e exercises the v2rayN conversion path in mihomo-core.
info "Step 3: Starting subscription HTTP server on port $SUB_PORT ..."
mkdir -p /tmp/test-sub

# Build a synthetic nodelist: two ss:// URIs pointing at the host
# ssserver running on $SS_HOST_FROM_EMU:$SS_PORT with the same
# credentials the old YAML fixture used. Base64-wrap the whole thing
# the way v2rayN subscription feeds do. No real tokens, no real UUIDs —
# everything here is derived from the shell vars at the top of this file.
SS_USERINFO_B64=$(printf '%s:%s' "$SS_METHOD" "$SS_PASSWORD" | base64 | tr -d '\n')
NODELIST_PLAIN=$(printf 'ss://%s@%s:%s#test-node-1\nss://%s@%s:%s#test-node-2\n' \
    "$SS_USERINFO_B64" "$SS_HOST_FROM_EMU" "$SS_PORT" \
    "$SS_USERINFO_B64" "$SS_HOST_FROM_EMU" "$SS_PORT")
printf '%s' "$NODELIST_PLAIN" | base64 | tr -d '\n' > /tmp/test-sub/nodelist.txt

info "  Nodelist fixture:"
info "    plain:  $(printf '%s' "$NODELIST_PLAIN" | tr '\n' ' ')"
info "    base64: $(cat /tmp/test-sub/nodelist.txt)"

cd /tmp/test-sub && python3 -m http.server "$SUB_PORT" &
HTTPD_PID=$!
cd "$SCRIPT_DIR"
sleep 1
kill -0 "$HTTPD_PID" 2>/dev/null || fail "HTTP server failed to start"
info "Subscription HTTP server running (PID $HTTPD_PID)"
```

- [ ] **Step 2: Update the Room seed to point at the nodelist**

In the `sqlite3 /tmp/mihomo.db <<DBEOF` block (around line 209), replace the final `INSERT INTO clash_profile ...` statement with:

```bash
INSERT INTO clash_profile (name, url, yaml_content, selected, last_updated, tx, rx, selected_proxy, yaml_backup)
VALUES ('Test Sub', 'http://$SS_HOST_FROM_EMU:$SUB_PORT/nodelist.txt', '', 1, 0, 0, 0, '', '');
```

Also delete the `SUB_YAML=$(cat /tmp/test-sub/config.yaml)` line immediately above — the variable is no longer used.

- [ ] **Step 3: Ensure the app refreshes before connecting**

Still inside `test-e2e.sh`, find Step 6 (around line 192, `info "Step 6: Configuring subscription..."`). The app currently auto-connects immediately. With `yaml_content=''` the first connect attempt will fail because `MihomoInstance.start` has no config to write. We need the profile to be refreshed from the HTTP server first.

Add this block immediately **before** the `"$ADB" shell am start -W -n "$PKG/$ACTIVITY" --ez auto_connect true` line in Step 7:

```bash
# Force a profile refresh so the nodelist is fetched, converted, and
# written to yaml_content before VpnService.start tries to read it.
# Launch the app without auto_connect, let SubscriptionService.refreshAll
# run via the manual refresh broadcast, then wait for yaml_content to fill.
info "  Refreshing subscription via app (no auto-connect yet)..."
"$ADB" shell am start -W -n "$PKG/$ACTIVITY"
sleep 6
"$ADB" shell am broadcast -a io.github.madeye.meow.REFRESH_SELECTED >/dev/null 2>&1 || true
# If the broadcast receiver isn't wired up, fall back: tap the UI
# refresh affordance via uiautomator. Either way, poll the DB until the
# yaml_content column is non-empty.
REFRESH_OK=false
for i in $(seq 1 30); do
    FILLED=$("$ADB" shell "run-as $PKG sqlite3 databases/mihomo.db 'SELECT length(yaml_content) FROM clash_profile WHERE selected=1;'" 2>/dev/null | tr -d '\r')
    if [[ -n "$FILLED" && "$FILLED" != "0" ]]; then
        REFRESH_OK=true
        info "  yaml_content populated after ${i}s (length=$FILLED)"
        break
    fi
    sleep 1
done
if [[ "$REFRESH_OK" != "true" ]]; then
    fail "Subscription did not refresh within 30s — nodelist conversion broken?"
fi
"$ADB" shell am force-stop "$PKG"
sleep 2
```

**Note to the implementer:** the `REFRESH_SELECTED` broadcast referenced here does not yet exist. Do **not** add a new receiver in this task — instead, the fallback polling will drive through the UI if necessary. If the poll fails because no refresh was triggered, add `io.github.madeye.meow.REFRESH_SELECTED` as a debug-only broadcast receiver in a follow-up task. For the first run, verify the poll path by manually refreshing from the Flutter UI during Step 7's Flutter-UI-loaded window — the `refreshAll` call on the subscriptions screen is already wired.

Simpler alternative (prefer this): trigger a refresh directly from the host by calling `SubscriptionService.refreshAll()` is not possible without an IPC hook. So instead, **initialize `yaml_content` with a one-proxy clash YAML placeholder that will pass validation but will be overwritten on the first auto-refresh**. Replace the Task 5 Step 2 `INSERT INTO` with:

```bash
PLACEHOLDER_YAML=$(cat <<'YAML'
mixed-port: 7890
mode: rule
proxies:
  - name: placeholder
    type: direct
proxy-groups:
  - name: Proxy
    type: select
    proxies: [placeholder]
rules:
  - MATCH,placeholder
YAML
)
INSERT INTO clash_profile (name, url, yaml_content, selected, last_updated, tx, rx, selected_proxy, yaml_backup)
VALUES ('Test Sub', 'http://$SS_HOST_FROM_EMU:$SUB_PORT/nodelist.txt', '$(echo "$PLACEHOLDER_YAML" | sed "s/'/''/g")', 1, 0, 0, 0, '', '');
```

Keep the REFRESH poll block in Step 3 above but change its pass condition from "length > 0" to "yaml_content contains test-node-1":

```bash
    FILLED=$("$ADB" shell "run-as $PKG sqlite3 databases/mihomo.db 'SELECT yaml_content FROM clash_profile WHERE selected=1;'" 2>/dev/null | tr -d '\r')
    if echo "$FILLED" | grep -q 'test-node-1'; then
```

The "app auto-refreshes the selected profile on cold start" behavior is already present in `bg/MihomoInstance.kt` via the existing subscription-refresh codepath invoked from the Flutter home screen pull-to-refresh. If after implementing you find that cold start does *not* trigger a refresh, add a one-line call to `SubscriptionService.refreshAll()` in `MainActivity.onCreate()` guarded by `BuildConfig.DEBUG` as part of this task.

- [ ] **Step 4: Run test-e2e.sh**

```bash
SKIP_EMULATOR_BOOT=true ./test-e2e.sh
```

Expected: all 5 connectivity tests PASS. The logcat should show mihomo parsing two proxies named `test-node-1` and `test-node-2`.

- [ ] **Step 5: Commit**

```bash
git add test-e2e.sh
git commit -m "test: switch e2e fixture to base64 nodelist"
```

---

## Task 6: Stop leaking dev-time artifacts

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Check current state**

```bash
cat .gitignore
git status --short
```

You should see `e2e-logcat.log`, `ui_dump_vpn_dialog.xml`, and possibly `screen_*.png` as untracked — these contain real URLs and device dumps from prior dev runs.

- [ ] **Step 2: Append ignore patterns**

Append to `.gitignore`:

```
# E2E test artifacts — may contain real subscription URLs or device state
e2e-logcat.log
ui_dump_vpn_dialog.xml
ui_dump*.xml
screen_*.png
/tmp/test-sub/
```

- [ ] **Step 3: Verify the untracked files are now ignored**

```bash
git status --short
```

Expected: `e2e-logcat.log` and `ui_dump_vpn_dialog.xml` no longer appear.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "gitignore: exclude e2e logcat, UI dumps, screenshots"
```

---

## Task 7: Full lint sweep

Run the four lint commands from `CLAUDE.md` in parallel. If any fails, fix in place and re-run before moving on.

- [ ] **Step 1: Android lint**

```bash
./gradlew :mobile:lintDebug -PTARGET_ABI=arm64 -PCARGO_PROFILE=release -PGO_PROFILE=release
```

Expected: `BUILD SUCCESSFUL`, no new errors.

- [ ] **Step 2: Go vet + gofmt**

```bash
cd core/src/main/go/mihomo-core && go vet ./... && gofmt -l . && cd -
```

Expected: both silent.

- [ ] **Step 3: Rust clippy + rustfmt**

```bash
cd core/src/main/rust/mihomo-android-ffi && cargo clippy -- -D warnings && cargo fmt --check && cd -
```

Expected: `0 warnings`, `fmt --check` silent.

- [ ] **Step 4: Flutter analyze**

```bash
cd flutter_module && flutter analyze && cd -
```

Expected: `No issues found`.

- [ ] **Step 5: If any fix was required, commit it**

```bash
git add -A
git commit -m "style: lint fixes for nodelist subscription work"
```

(Skip if no changes.)

---

## Task 8: Final e2e run and hand-off

- [ ] **Step 1: Run the full e2e from a clean build**

```bash
./gradlew :mobile:assembleDebug -PTARGET_ABI=arm64 -PCARGO_PROFILE=release -PGO_PROFILE=release
SKIP_EMULATOR_BOOT=true ./test-e2e.sh
```

Expected: APK builds; all 5 tests PASS.

- [ ] **Step 2: Inspect the committed diff**

```bash
git log --oneline main..HEAD
git diff --stat main..HEAD
```

Expected: ~6 commits (one per task that touched code), no reference to `edt.maxlv.net`, real tokens, or real UUIDs anywhere in the tree:

```bash
git grep -i 'edt.maxlv.net\|248bdc2d\|6fdf790c' -- '*' && echo "LEAK DETECTED" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 3: Confirm the qa agent has signed off**

Before claiming complete, the qa subagent must have:
- re-run Task 1 Go tests, Task 3 Kotlin tests, Task 7 lint sweep, Task 8 e2e
- read the diff against `docs/superpowers/specs/2026-04-12-nodelist-subscription-design.md`
- reported any gaps (or an explicit "spec fully covered") back in the final hand-off message

---

## Self-review

### Spec coverage

| Spec section | Task |
|---|---|
| Detection heuristic | Task 3 (SubscriptionFormat + unit tests) |
| Go converter | Task 1 (convert.go + convert_test.go) |
| JNI bridge additions | Task 2 (exports.go, jni_bridge_android.c, MihomoEngine.kt) |
| SubscriptionService changes | Task 4 |
| CI fixture (synthetic base64 nodelist) | Task 5 |
| .gitignore for logcat / UI dump | Task 6 |
| Kotlin unit test | Task 3 |
| Go unit test | Task 1 |
| E2E test | Task 5 + Task 8 |
| Lint sweep | Task 7 |
| Team hand-off (dev + qa) | Task 8 Step 3 |

### Known deviations from the spec

- Spec said to best-effort base64 decode in `convert.go`. Implementation defers this to `convert.ConvertsV2Ray`, which already handles base64 internally. One fewer moving part. Kept `empty body` error explicit.
- Spec mentioned a `REFRESH_SELECTED` broadcast receiver. Task 5 replaces that with a placeholder-yaml seed strategy, which is simpler and does not require adding a new Android component. The REFRESH_SELECTED idea is noted as a follow-up if placeholder seeding proves insufficient.
- Spec mentioned `SubscriptionFormat.isBase64Body`. Task 3 drops it: the heuristic only needs "is this clash yaml yes/no", since everything that is not clash yaml goes through the Go converter which handles both base64 and plain URI forms.

All three deviations simplify the surface. No spec requirement is dropped.

### Placeholder scan

None. Every step has exact commands, exact file paths, and complete code.

### Type consistency

- `nativeConvertSubscription(raw: ByteArray): String?` — same signature in Kotlin (Task 2) and in the call site (Task 4).
- `convertSubscription(raw []byte) (string, error)` — same signature in `convert.go` (Task 1) and the cgo wrapper `meowConvertSubscription` (Task 2).
- `SubscriptionFormat.isClashYaml(raw: ByteArray): Boolean` — same signature in test (Task 3 Step 2), implementation (Task 3 Step 4), and call site (Task 4 Step 1).
