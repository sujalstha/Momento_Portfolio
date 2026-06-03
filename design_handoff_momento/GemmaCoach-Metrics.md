# GemmaCoach — Per-Run Metrics Reference

> Purpose: a single source of truth for **every metric captured during a run**, where it
> comes from, what units it uses, the exact property/payload names on the Watch and iPhone,
> how often it updates, and where it surfaces (Gemma coaching context, spoken voice replies,
> on-screen UI). Read this before touching the metric pipeline.

## Pipeline at a glance

```
Apple Watch (GemmaCoachWatch)                 iPhone (GemmaCoach)
─────────────────────────────                 ───────────────────
HKLiveWorkoutBuilder ──┐
HKAnchoredObjectQuery ─┤ process(_:)           applyWatchPayload(_:)  ──► RunMetricsManager
   (SpO₂ only)         │   ▼                         ▲   @Published current* properties
                       └► WorkoutManager            │        │
                          @Published props          │        ├─► getCurrentStateString()  → Gemma (LiveSession)
                          sendMetrics() every 1 s ──┘        ├─► currentMetricsText()      → spoken "metrics" command
                          via WCSession dict                 └─► liveCard tiles            → developer UI
```

- **Watch is the primary source** during a real run (`HKLiveWorkoutBuilder` + a dedicated SpO₂ query).
- The Watch pushes a full snapshot **every 1 second** (`sendTimer`, `WorkoutManager.startSendTimer`).
  Uses `WCSession.sendMessage` when the phone is reachable, otherwise `updateApplicationContext`.
- iPhone marks the Watch **stale after 4 s** of silence (`watchStaleTimer`, `RunMetricsManager`).
- The iPhone also has **its own local sensors** (GPS, pedometer, altimeter, BLE chest strap) used
  when no Watch is connected; Watch values take priority when present.
- In the **simulator**, both sides synthesize a coherent effort curve so the full UI works without hardware.

## Metric table

| Metric | HealthKit identifier | Unit (sent) | Watch property | WCSession key | iPhone property | Cadence |
|---|---|---|---|---|---|---|
| Heart rate | `heartRate` | BPM (Int) | `heartRateBPM` | `heartRateBPM` | `currentHeartRateBPM` | 1 s |
| Pace | `runningSpeed` | sec/meter | `paceSecondsPerMeter` | `paceSecondsPerMeter` | `currentPaceSecondsPerMeter` | 1 s |
| Cadence | `stepCount` (derived) | steps/min | `cadenceSPM` | `cadenceSPM` | `currentCadenceSPM` | 1 s |
| Running power | `runningPower` | watts | `powerWatts` | `powerWatts` | `currentRunningPowerWatts` | 1 s |
| Stride length | `runningStrideLength` | meters | `strideLengthMeters` | `strideLengthMeters` | `currentStrideLengthMeters` | 1 s |
| Ground contact time | `runningGroundContactTime` | ms | `groundContactTimeMs` | `groundContactTimeMs` | `currentGroundContactTimeMs` | 1 s |
| Vertical oscillation | `runningVerticalOscillation` | cm | `verticalOscillationCm` | `verticalOscillationCm` | `currentVerticalOscillationCm` | 1 s |
| Heart rate variability | `heartRateVariabilitySDNN` | ms | `hrvMs` | `hrvMs` | `currentHeartRateVariabilityMs` | 1 s |
| Respiratory rate | `respiratoryRate` | breaths/min | `respiratoryRate` | `respiratoryRate` | `currentRespiratoryRate` | 1 s |
| **Distance** | `distanceWalkingRunning` | meters (cumulative) | `distanceMeters` | `distanceMeters` | `currentDistanceMeters` | 1 s |
| **Active energy** | `activeEnergyBurned` | kcal (cumulative) | `activeEnergyKcal` | `activeEnergyKcal` | `currentActiveEnergyKcal` | 1 s |
| **Blood oxygen (SpO₂)** | `oxygenSaturation` | percent | `oxygenSaturationPercent` | `oxygenSaturationPercent` | `currentOxygenSaturationPercent` | intermittent ⚠️ |
| Elevation change | — (iPhone `CMAltimeter`) | meters | — | — | `currentElevationMeters` | iPhone-local |

Bold rows were added most recently. Elevation is **iPhone-only** (barometer); it is never sent by the Watch.

## Units & conversions

- **Pace** is stored as `secondsPerMeter`. Display converts to min/mile: `secPerMeter * 1609.34` → `mm:ss /mi`
  (`RunMetricsManager.formattedPace`). `0` ⇒ "Standing still".
- **Distance** is collected with `stats.sumQuantity()` in **meters**; UI/Gemma show km (`/ 1000`).
- **Active energy** is collected with `stats.sumQuantity()` in **kcal**.
- **SpO₂** arrives from HealthKit as a `0–1` fraction; we multiply by `100` to store a percent.
- **Cadence** is derived from cumulative `stepCount`: `(Δsteps / Δt) * 60` (`WorkoutManager.process`).
- Distance & active energy are **cumulative for the run** (they only increase); all others are instantaneous.

## How each metric is used

1. **Gemma coaching context** — `RunMetricsManager.getCurrentStateString()` builds the multi-line
   block injected into every live-coaching turn (`LiveSession.startGeneration`). Unavailable values
   render as `—`; the system prompt instructs Gemma to treat `0`/`—`/unknown as "not available".
2. **Spoken "metrics" voice command** — `ContentView.currentMetricsText()` speaks HR, pace, cadence,
   power, distance, blood oxygen, active calories, and elevation when the user asks.
3. **Developer UI** — `ContentView.liveCard` shows live tiles (HR, Pace, Cadence, Power, Stride, Elev,
   GCT, Vert Osc, HRV, Resp Rate, SpO₂, Distance, Energy).
4. **Watch HUD** — `WatchContentView` shows HR, Pace, Cadence, Power only (intentionally minimal).

## Source priority & fallbacks

- **Heart rate:** Apple Watch payload wins. A BLE chest strap (`service 180D` / `char 2A37`) is only
  applied when `isWatchConnected == false` (`RunMetricsManager.peripheral(_:didUpdateValueFor:)`).
- **Pace:** Watch `runningSpeed` preferred; otherwise iPhone GPS (`CLLocation.speed`).
- **Cadence:** Watch-derived preferred; otherwise iPhone `CMPedometer`.
- **Elevation:** always iPhone `CMAltimeter` (relative altitude).
- **Watch staleness:** if no packet arrives for 4 s, `isWatchConnected` flips to `false` and the iPhone
  falls back to its local sensors.

## ⚠️ Blood oxygen (SpO₂) is not per-second

`HKLiveWorkoutBuilder` does **not** stream `oxygenSaturation` during a workout. watchOS only samples
blood oxygen periodically/in the background, so it cannot be pushed every second like the other metrics.

- It is captured via a dedicated **`HKAnchoredObjectQuery`** (`WorkoutManager.startOxygenSaturationQuery`),
  started in `startWorkout()` and stopped in `stopWorkout()`. The query's `updateHandler` forwards each
  new reading the moment it lands.
- The iPhone decode guards with `v > 0` so a "no reading yet" zero never overwrites a real value.
- Availability requires a supported Apple Watch (Series 6–9 / Ultra) with **Blood Oxygen enabled**, and
  the feature is disabled in some regions. Expect refreshes minutes apart, not seconds.

## Authorization

All Watch metrics ride a single `HKHealthStore.requestAuthorization` call
(`WorkoutManager.requestHealthAuthorization`) using the `typesToRead` set. Adding a new metric means:

1. Add the `HKObjectType.quantityType(forIdentifier:)` to **`typesToRead`**.
2. Add an `@Published` property + a `case` in **`process(_:)`** (or a separate query for non-workout types).
3. Add the key to the **`sendMetrics()`** payload dict.
4. Mirror the `@Published` property + decode it in **`RunMetricsManager.applyWatchPayload`**.
5. Surface it in **`getCurrentStateString()`** (Gemma), **`currentMetricsText()`** (spoken), and/or the UI.

The Watch `Info.plist` must contain `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`;
no per-metric plist key is required.

## Simulator behavior

When `targetEnvironment(simulator)`:
- **iPhone** (`RunMetricsManager.start`) runs a 2 s mock timer driving a sine-based effort curve
  (`effort` 0→1 over an 8-min cycle). All metrics are physically correlated — higher effort raises
  HR/power/respiratory rate and lowers GCT/vertical oscillation/HRV/SpO₂ simultaneously. Distance and
  energy accumulate; SpO₂ ranges 99% (easy) → ~95% (hard).
- **Watch** capture requires real hardware; HealthKit live collection does not run in the simulator.
