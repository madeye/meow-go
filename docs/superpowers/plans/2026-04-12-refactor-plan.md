# Meow(Go) Refactor Plan — 2026-04-12

Prioritized plan for performance and UI improvements based on a full audit of the
Flutter UI, Kotlin service layer, and Room database configuration. All file:line
references are to the current `main` branch.

---

## Audit Findings Summary

### Performance
| # | Location | Issue |
|---|----------|-------|
| P1 | `PrivateDatabase.kt:22` | `allowMainThreadQueries()` — every DB call blocks the UI thread |
| P2 | `BaseService.kt:160,205` | `GlobalScope.launch` — leaks coroutines on service restart/crash |
| P3 | `home_screen.dart:44` | `setState` on every traffic tick — full widget tree rebuild at 1 Hz |
| P4 | `traffic_screen.dart:50,63` | Same setState-per-tick pattern + `_history.load()` called every 10 s with fire-and-forget `.then()` |
| P5 | `traffic_screen.dart:711` | `_ChartPainter.shouldRepaint` always returns `true` — repaints every frame regardless |
| P6 | `traffic_screen.dart:374-383` | `_buildAllDays()` recomputes 30-day list on every `build()` — O(n²) scan |
| P7 | `logs_screen.dart:51` | `setState` per log line — potentially hundreds of rebuilds per second at debug level |

### UI / UX
| # | Location | Issue |
|---|----------|-------|
| U1 | `app.dart:27` | Hard-coded `ThemeData.dark` — no light/system mode, no user preference |
| U2 | All screens | Dozens of `Colors.white54`, `Colors.greenAccent`, `Colors.grey`, etc. — bypasses theme, breaks light mode |
| U3 | `traffic_screen.dart:437,563,688` | Hard-coded English strings in chart painters ("Tap a bar…", "Upload", "Download") — not localised |
| U4 | `settings_screen.dart:94` | Hard-coded `'Loading...'` literal — not localised |
| U5 | All screens | No `Semantics` wrappers on interactive elements — fails a11y |
| U6 | All screens | Fixed pixel sizes everywhere; no `MediaQuery` / `LayoutBuilder` checks |
| U7 | Various | Missing empty/error/loading states beyond a bare text fallback |

---

## Phase 1 — Performance (do first)

Performance issues compound: the main-thread DB hit can ANR the app; the
`GlobalScope` leak can leave orphan coroutines pumping traffic after a session
ends; the rebuild storm (P3-P5) causes the battery to drain even on the idle
home screen. These must land before UI polish so we aren't optimising widgets
that are being rebuilt every second anyway.

### 1.1 Remove `allowMainThreadQueries` — **highest priority**

**Why first:** ANR risk. Any DB call on a slow device (profile fetch, traffic
record write) freezes the UI. The fix is a one-line removal plus async wrappers
on every call site — contained, high-impact.

**Files to change:**
- `core/…/database/PrivateDatabase.kt:22` — remove `.allowMainThreadQueries()`
- `core/…/database/ProfileDao.kt` — annotate queries returning `List` /
  single rows with `suspend`; wrap fire-and-forget writes in `withContext(Dispatchers.IO)`
- `core/…/database/DailyTrafficDao.kt` — same pattern
- `mobile/…/FlutterChannel.kt` (call sites) — migrate to `lifecycleScope.launch`
  or `viewModelScope` so callers move off the main thread automatically

**Test:** Run full E2E after this change; StrictMode violations in logcat should
drop to zero.

### 1.2 Replace `GlobalScope` with structured coroutines

**Why second:** A crash during `stopRunner` leaves the `GlobalScope` job alive.
On the next `startRunner` call a second job starts — two jobs now race to
read/write `data.state`. The fix scopes coroutines to the service lifetime.

**Files to change:**
- `core/…/bg/BaseService.kt:160` — replace `GlobalScope.launch` in
  `stopRunner()` with a service-owned `CoroutineScope` cancelled in `onDestroy`
- `core/…/bg/BaseService.kt:205` — same for `data.connectingJob`
- Introduce a `serviceScope` property on `BaseService.Interface` backed by
  `SupervisorJob() + Dispatchers.Main.immediate`, cancelled when the service
  reaches `State.Stopped`

### 1.3 Decouple traffic repaints from full widget rebuilds (Flutter)

**Why third:** The traffic stream fires at ~1 Hz. Every tick calls `setState` on
`HomeScreen` (line 44) and `TrafficScreen` (line 50), which rebuilds the entire
subtree — proxy group cards, mode card, sliver app bar — not just the speed
numbers.

**Approach:** Extract speed/traffic display into a `RepaintBoundary`-wrapped
`StreamBuilder` or a thin `ValueListenableBuilder` that isolates rebuilds to the
speed tile only. The parent `HomeScreen` only calls `setState` for state
transitions (`VpnState` changes), not traffic ticks.

**Files to change:**
- `flutter_module/lib/screens/home_screen.dart` — remove `_trafficSub` `setState`;
  replace `_TrafficTile` with `StreamBuilder<TrafficStats>` consuming
  `VpnChannel.instance.trafficStream` directly. Wrap in `RepaintBoundary`.
- `flutter_module/lib/screens/traffic_screen.dart` — same for `_StatCard` row.
  Move `_samples.add(...)` out of `setState` into a `List` updated via
  `addPostFrameCallback` + `markNeedsPaint` on the painter directly.

### 1.4 Fix `_ChartPainter.shouldRepaint` and cache `_buildAllDays`

**Files to change:**
- `traffic_screen.dart:711` — `shouldRepaint` must compare `samples` and
  `maxRate` instead of returning `true` unconditionally.
- `traffic_screen.dart:374` — cache `_buildAllDays()` result in a field; rebuild
  only when `widget.days` identity changes (override `didUpdateWidget`).

### 1.5 Batch log-screen rebuilds

**Files to change:**
- `logs_screen.dart:51` — accumulate log entries in a buffer; flush to `setState`
  at most every 200 ms using a `Timer.periodic`. This reduces rebuilds from
  potentially hundreds per second (at `debug` level) to 5 per second. Keep the
  existing `_kMaxEntries = 1000` cap.

---

## Phase 2 — UI / Theme (do second)

The hard-coded colour and theme issues are tightly coupled — fixing them
together in one sweep is far cheaper than patching screen by screen. A systematic
theme pass also enables light-mode support requested by users, which is a
user-visible feature worth shipping.

### 2.1 Add theme switcher and semantic colour tokens

**Why:** Every screen hard-codes `Colors.white54`, `Colors.greenAccent`, etc.
These are invisible on a light background. The fix must be done _once_ in the
theme, not per-widget.

**Approach:**
- `app.dart` — add `themeMode` state (dark / light / system) persisted via
  `SharedPreferences`. Wire to `MaterialApp.themeMode`.
- Define a light `ThemeData` alongside the existing dark one. Avoid duplicating
  the `ColorScheme` — use `ColorScheme.fromSeed` with `brightness` parameter.
- Introduce semantic colour extensions on `BuildContext`:
  ```dart
  extension AppColors on BuildContext {
    Color get statusConnected => Theme.of(this).colorScheme.tertiary;
    Color get statusDisconnected => Theme.of(this).colorScheme.outline;
    Color get uploadColor => Theme.of(this).colorScheme.primary;
    Color get downloadColor => Theme.of(this).colorScheme.secondary;
  }
  ```
- Replace all raw `Colors.*` literals in screens and widgets with these
  extensions. `home_screen.dart`, `traffic_screen.dart`, `logs_screen.dart` are
  the main offenders.

**Files to change:**
- `flutter_module/lib/app.dart` — theme mode state + both ThemeData objects
- `flutter_module/lib/theme/app_colors.dart` (new) — extension definitions
- All screen files — replace `Colors.*` literals

### 2.2 Localise hard-coded strings

**Files to change:**
- `flutter_module/lib/l10n/strings.dart` — add keys: `tapBarForDetails`,
  `upload`, `download`, `loading`
- `traffic_screen.dart:437,563,568,688,689` — use `S.of(context).*` inside
  `StatefulWidget.build`; pass pre-rendered strings into painters as constructor
  params (painters have no `BuildContext`)
- `settings_screen.dart:94` — replace `'Loading...'` with `s.loading`

### 2.3 Loading and error states

**Files to change:**
- `subscriptions_screen.dart` — replace bare `_loading` flag with a proper
  loading skeleton (`ListView` of `shimmer`-style `ListTile` placeholders) and
  an error banner when `_vpn.getProfiles()` throws.
- `home_screen.dart` — show a `CircularProgressIndicator` while `_loadState()`
  is in flight instead of rendering stale data.
- `settings_screen.dart` — show `_version` skeleton while waiting; show error
  icon if `_loadMeta()` fails.

### 2.4 Theme mode setting tile in Settings

Add a `ListTile` / `SegmentedButton` to `SettingsScreen` for Dark / Light /
System theme selection. Persist choice to `SharedPreferences`.

---

## Phase 3 — Lower Priority (polish)

These items have no reliability or correctness risk; defer until Phase 1 and 2 are
shipped and verified.

### 3.1 Accessibility (a11y)

Add `Semantics` labels to:
- VPN toggle switch (announce state as "VPN connected/disconnected")
- Traffic speed tiles (label as "Upload rate: X, total: Y")
- Chart widgets (mark `excludeFromSemantics: true` + add a summary
  `Semantics` node with textual description)

### 3.2 Responsive layout

- Wrap card rows in `LayoutBuilder`; switch from `Row` of two `Expanded` cards
  to a `Wrap` with `spacing` when `maxWidth < 360` (small phones like Pixel 3a).
- Replace fixed-height `SizedBox(height: 220)` chart containers with
  `AspectRatio(aspectRatio: 16/9)` so they scale on tablets.

### 3.3 `_ChartPainter` light-mode colour pass

The chart painters use raw `Colors.blue`, `Colors.green`, `Colors.white10`
directly. After Phase 2 adds a light theme, audit painter constructors and
thread semantic colours in from the caller.

### 3.4 Profile change debounce

`home_screen.dart` calls `_loadState()` via `profileChanged` listener every time
any mutation fires. If subscriptions screen triggers multiple rapid saves (e.g.,
bulk import), `_loadState()` floods the channel. Debounce to 300 ms.

---

## Ordering Rationale

```
Phase 1 (reliability + battery)
  1.1 allowMainThreadQueries  ← ANR risk, contained change
  1.2 GlobalScope             ← correctness, pairs with 1.1 migration to scoped coroutines
  1.3 traffic setState storm  ← battery drain, UX jank
  1.4 chart repaint / cache   ← easy wins, no risk
  1.5 log batch               ← completes the rebuild-storm sweep

Phase 2 (UX completeness)
  2.1 theme + colours         ← blocks all remaining visual work
  2.2 localisation            ← embarrassing regression risk for i18n users
  2.3 loading/error states    ← required before any QA sign-off
  2.4 theme setting tile      ← small; depends on 2.1

Phase 3 (polish)
  3.1-3.4                     ← no blocking dependency; good candidates for
                                 parallel implementation once Phase 2 ships
```

Phase 1 should be reviewed by QA against the E2E test suite (`test-e2e.sh`)
before Phase 2 lands. Phase 2 requires manual UI review on both dark and light
system themes on a physical device and emulator.
