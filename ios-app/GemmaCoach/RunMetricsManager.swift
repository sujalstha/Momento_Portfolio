// RunMetricsManager.swift — iPhone side (Nike Run Club-style architecture)
//
// Primary path: HealthKit mirroring (watchOS 10+/iOS 17+)
//   When the Watch app calls session.startMirroringToCompanionDevice(), the
//   iPhone wakes up and gets a live HKLiveWorkoutBuilder feed of every sensor
//   sample — same data, same timing as the Watch sees. No manual WCSession data.
//
// Throttling: raw HealthKit callbacks fire on background threads at high
//   frequency. We funnel them through a PassthroughSubject and throttle to 1 Hz
//   on the main thread before writing to @Published properties. Stops UI churn.
//
// Pace: HealthKit doesn't surface "current pace" directly. We compute it from
//   the most recent runningSpeed sample (m/s → sec/m), falling back to the
//   distance delta over the time delta when speed isn't available.
//
// Standalone-iPhone path: when no Watch is sending mirrored sessions (e.g. user
//   wears no Watch), we still observe HR/SpO2/power/stride via HKAnchoredObjectQuery
//   and use the iPhone's own CMPedometer/CoreLocation/CMAltimeter.

import Combine
import CoreLocation
import CoreMotion
import Foundation
import HealthKit
import WatchConnectivity
import os.log

private let mirrorLog = Logger(subsystem: "com.sujalshrestha.gemmacoach", category: "WatchMirror")
private let wcLog = Logger(subsystem: "com.sujalshrestha.gemmacoach", category: "WCSession")

@MainActor
final class RunMetricsManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published metrics (SwiftUI reads these — only updated at 1 Hz)

    @Published var currentPaceSecondsPerMeter: Double = 0
    @Published var currentCadenceSPM: Double = 0
    @Published var currentHeartRateBPM: Int = 0
    @Published var currentElevationMeters: Double = 0
    @Published var currentRunningPowerWatts: Double = 0
    @Published var currentStrideLengthMeters: Double = 0
    @Published var currentVerticalOscillationCm: Double = 0
    @Published var currentGroundContactTimeMs: Double = 0
    @Published var currentBloodOxygenPercent: Double = 0
    @Published var currentDistanceMeters: Double = 0
    @Published var currentCalories: Double = 0
    @Published var currentElapsedSeconds: TimeInterval = 0
    @Published var isActive: Bool = false

    /// True while a Watch session is mirrored into this app. Used by the UI
    /// to display the metrics card even when the iPhone-side Live toggle is
    /// off — the Watch is the source of truth.
    @Published var hasMirroredSession: Bool = false

    // MARK: - Sensors

    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let altimeter = CMAltimeter()
    private let healthStore = HKHealthStore()
    private var activeQueries: [HKQuery] = []

    // MARK: - HealthKit mirroring state

    private var mirroredSession: HKWorkoutSession?
    private var mirroredBuilder: HKLiveWorkoutBuilder?

    // MARK: - Pace derivation

    private var lastDistance: Double = 0
    private var lastDistanceTime: Date?

    // MARK: - Combine throttling pipeline

    private struct RawMetrics {
        var heartRate: Double?
        var distance: Double?
        var calories: Double?
        var speed: Double?
        var stride: Double?
        var power: Double?
        var verticalOscillationCm: Double?
        var groundContactTimeMs: Double?
    }

    /// Latest value seen for each field, merged across delegate callbacks.
    /// HealthKit delivers types in separate calls (HR at t=0, distance at
    /// t=0.5, etc.) — without merging, a 1Hz `.throttle(latest: true)` would
    /// drop everything except the last partial RawMetrics in each window and
    /// most fields would stop updating.
    private var pendingMetrics = RawMetrics()

    /// Throttle tick — fires whenever new data arrives; the sink reads
    /// `pendingMetrics` so it always sees the freshest value of every field.
    private let metricsTick = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    // True once HealthKit/mirroring delivers a stride from Watch — prevents the
    // pace+cadence-derived fallback from overwriting the more accurate value.
    private var strideFromWatch = false

    // Guard against double-starting the altimeter (both `start()` and
    // `attachMirroredSession()` can request it).
    private var altimeterRunning = false

    // Drives the 1Hz elapsed-time tick when a mirrored session is attached.
    private var elapsedTimer: Timer?

    // MARK: - WatchConnectivity (5-second metric packets from Watch)

    private let wc = WCSession.default
    /// Timestamp of the most recent WC packet so we can auto-clear
    /// `hasMirroredSession` if the Watch stops sending without an explicit
    /// "ended" message.
    private var lastWCMessageAt: Date?
    private var wcWatchdog: Timer?

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        setupMirroringHandler()
        setupThrottlingPipeline()
        activateWatchConnectivity()
    }

    private func activateWatchConnectivity() {
        guard WCSession.isSupported() else {
            wcLog.error("WCSession not supported on this device")
            return
        }
        wc.delegate = self
        wc.activate()
        wcLog.info("WCSession activate() called (state=\(self.wc.activationState.rawValue))")
    }

    /// Idempotent — safe to call every time the view appears. Triggers the
    /// HealthKit permission sheet the first time. Required for the iOS app
    /// to read sample values out of the mirrored builder, even though the
    /// mirroring handshake itself is independent of per-type authorization.
    func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            mirrorLog.error("HealthKit not available on this device")
            return
        }
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.runningSpeed),
            HKQuantityType(.runningStrideLength),
            HKQuantityType(.runningPower),
            HKQuantityType(.runningVerticalOscillation),
            HKQuantityType(.runningGroundContactTime),
            HKQuantityType(.oxygenSaturation),
            HKObjectType.workoutType(),
        ]
        do {
            try await healthStore.requestAuthorization(toShare: [], read: read)
            mirrorLog.info("HealthKit authorization request completed")

            // Start the always-on anchored-query fallback for HR/SpO₂. These
            // fire whenever the Watch writes samples to HealthKit during a
            // workout, so the iPhone UI still ticks if mirroring fails for
            // any reason. They self-gate against mirrored data when it's
            // active so the two sources never fight.
            if activeQueries.isEmpty {
                launchBackgroundQueries()
            }
        } catch {
            mirrorLog.error("HealthKit authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Throttling pipeline (1 Hz UI updates)

    private func setupThrottlingPipeline() {
        metricsTick
            .throttle(for: .seconds(1.0), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] in
                guard let self else { return }
                self.applyMetrics(self.pendingMetrics)
            }
            .store(in: &cancellables)
    }

    /// Merge new (non-nil) fields from a delegate callback into `pendingMetrics`
    /// and signal a tick. Must be called on the main actor.
    private func mergePending(_ raw: RawMetrics) {
        if let v = raw.heartRate              { pendingMetrics.heartRate = v }
        if let v = raw.distance               { pendingMetrics.distance = v }
        if let v = raw.calories               { pendingMetrics.calories = v }
        if let v = raw.speed                  { pendingMetrics.speed = v }
        if let v = raw.stride                 { pendingMetrics.stride = v }
        if let v = raw.power                  { pendingMetrics.power = v }
        if let v = raw.verticalOscillationCm  { pendingMetrics.verticalOscillationCm = v }
        if let v = raw.groundContactTimeMs    { pendingMetrics.groundContactTimeMs = v }
        metricsTick.send(())
    }

    private func applyMetrics(_ raw: RawMetrics) {
        if let hr = raw.heartRate, hr > 0 {
            currentHeartRateBPM = Int(hr)
        }

        // Prefer instantaneous speed for pace; fall back to distance/time delta.
        if let speed = raw.speed, speed > 0 {
            currentPaceSecondsPerMeter = 1.0 / speed
        } else if let distance = raw.distance, distance > 0 {
            let now = Date()
            if let lastTime = lastDistanceTime,
               distance > lastDistance {
                let dt = now.timeIntervalSince(lastTime)
                let dd = distance - lastDistance
                if dt > 0.1 && dd > 0 {
                    currentPaceSecondsPerMeter = dt / dd
                }
            }
            lastDistance = distance
            lastDistanceTime = now
        }

        if let distance = raw.distance {
            currentDistanceMeters = distance
        }
        if let cal = raw.calories {
            currentCalories = cal
        }
        if let stride = raw.stride, stride > 0 {
            strideFromWatch = true
            currentStrideLengthMeters = stride
        }
        if let power = raw.power {
            currentRunningPowerWatts = power
        }
        if let vo = raw.verticalOscillationCm, vo > 0 {
            currentVerticalOscillationCm = vo
        }
        if let gct = raw.groundContactTimeMs, gct > 0 {
            currentGroundContactTimeMs = gct
        }

        // Derive cadence from mirrored speed + stride: SPM = 60 · speed / stride.
        // HealthKit doesn't expose live cadence as a quantity type during a
        // workout, so without this iPhone-side derivation the metric would
        // always read 0 unless the user's phone is in their pocket with
        // CMPedometer running.
        if hasMirroredSession,
           currentStrideLengthMeters > 0,
           currentPaceSecondsPerMeter > 0 {
            let metersPerSecond = 1.0 / currentPaceSecondsPerMeter
            currentCadenceSPM = (metersPerSecond * 60.0) / currentStrideLengthMeters
        }
    }

    // MARK: - HealthKit Mirroring handler (Watch wakes us up here)

    private func setupMirroringHandler() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        mirrorLog.info("Registering workoutSessionMirroringStartHandler")
        healthStore.workoutSessionMirroringStartHandler = { [weak self] session in
            mirrorLog.info("🟢 workoutSessionMirroringStartHandler fired")
            Task { @MainActor [weak self] in
                self?.attachMirroredSession(session)
            }
        }
    }

    private func attachMirroredSession(_ session: HKWorkoutSession) {
        // If a prior mirrored session is still referenced (rapid stop→start
        // on the Watch), detach it first so old delegate hooks and state
        // don't bleed into the new session.
        if mirroredSession != nil {
            mirrorLog.warning("Existing mirroredSession found — detaching before reattach")
            detachMirroredSession()
        }

        mirrorLog.info("attachMirroredSession — building delegate chain")
        mirroredSession = session
        session.delegate = self           // observe end-state so we can clean up
        let builder = session.associatedWorkoutBuilder()
        builder.delegate = self
        mirroredBuilder = builder
        hasMirroredSession = true
        mirrorLog.info("✅ Mirrored session attached. hasMirroredSession=true, state=\(session.state.rawValue)")

        // Fresh start so the metrics card doesn't flash leftovers from a
        // previous workout the moment mirroring re-attaches.
        resetLiveMetrics()

        // Passive iPhone sensors that don't conflict with mirrored data.
        // Altimeter populates elev if the phone is on the user; if it's
        // on a desk, it'll just sit at 0 (harmless).
        startAltimeterIfNeeded()

        // 1Hz elapsed-time tick that mirrors the Watch's "Elapsed" display.
        startElapsedTimer()
    }

    private func detachMirroredSession() {
        mirroredSession = nil
        mirroredBuilder = nil
        strideFromWatch = false
        hasMirroredSession = false
        stopElapsedTimer()

        // Only stop altimeter if the user didn't also flip Live coaching mode
        // on the iPhone (which would also have started it).
        if !isActive {
            stopAltimeterIfRunning()
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let start = self.mirroredBuilder?.startDate {
                    self.currentElapsedSeconds = Date().timeIntervalSince(start)
                }
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        strideFromWatch = false
        lastDistance = 0
        lastDistanceTime = nil
        resetLiveMetrics()

        // Standalone iPhone fallback sensors (when no Watch mirroring is active)
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        if CMPedometer.isPaceAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                guard let data, error == nil else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    // Only trust iPhone-pedometer cadence when no Watch is
                    // mirroring — otherwise the phone (sitting on a desk)
                    // would clobber the correct mirrored-derived cadence
                    // with ~0 spm.
                    if self.mirroredSession == nil,
                       let cadence = data.currentCadence?.doubleValue {
                        self.currentCadenceSPM = cadence * 60
                    }

                    // Only use CMPedometer pace if mirroring hasn't given us speed
                    if self.mirroredSession == nil,
                       let pace = data.currentPace?.doubleValue, pace > 0 {
                        self.currentPaceSecondsPerMeter = pace
                    }

                    // Stride fallback when Watch hasn't provided one
                    if !self.strideFromWatch,
                       self.mirroredSession == nil,
                       let pace = data.currentPace?.doubleValue,
                       let cadence = data.currentCadence?.doubleValue,
                       pace > 0, cadence > 0 {
                        self.currentStrideLengthMeters = (1.0 / pace) / cadence
                    }
                }
            }
        }

        startAltimeterIfNeeded()

        // HR + SpO2 background observers — show last reading immediately
        startHealthKitObservation()

        isActive = true
    }

    /// Idempotent — safe to call from both `start()` and `attachMirroredSession()`.
    private func startAltimeterIfNeeded() {
        guard !altimeterRunning, CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeterRunning = true
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let data, error == nil else { return }
            Task { @MainActor in
                self?.currentElevationMeters = data.relativeAltitude.doubleValue
            }
        }
    }

    private func stopAltimeterIfRunning() {
        guard altimeterRunning else { return }
        altimeter.stopRelativeAltitudeUpdates()
        altimeterRunning = false
    }

    /// Zero out display values so a new run doesn't start with stale numbers.
    private func resetLiveMetrics() {
        pendingMetrics = RawMetrics()
        currentPaceSecondsPerMeter = 0
        currentCadenceSPM = 0
        currentHeartRateBPM = 0
        currentElevationMeters = 0
        currentRunningPowerWatts = 0
        currentStrideLengthMeters = 0
        currentVerticalOscillationCm = 0
        currentGroundContactTimeMs = 0
        currentDistanceMeters = 0
        currentCalories = 0
        currentElapsedSeconds = 0
        // Note: currentBloodOxygenPercent is intentionally NOT reset — SpO₂ is
        // a recent-history value, not a workout-scoped one.
    }

    // MARK: - Display formatters (match the Watch UI 1:1)

    // MARK: - WCSession payload application

    /// Applies a metric packet pushed from the Watch. Each field is optional —
    /// only present keys are applied, so the Watch can omit fields that
    /// haven't been measured yet.
    @MainActor
    fileprivate func applyWCPayload(_ payload: [String: Any]) {
        let keys = payload.keys.joined(separator: ",")
        wcLog.info("📦 Received WC packet: \(keys, privacy: .public)")

        if let status = payload["status"] as? String, status == "ended" {
            wcLog.info("Packet status=ended — clearing live state")
            hasMirroredSession = false
            stopWCWatchdog()
            lastWCMessageAt = nil
            return
        }

        // Flip the UI gate on first packet, restart altimeter for elev,
        // and arm the watchdog so we auto-clear if the Watch goes silent.
        if !hasMirroredSession {
            hasMirroredSession = true
            startAltimeterIfNeeded()
            resetLiveMetrics()
            startWCWatchdog()
        }
        lastWCMessageAt = Date()

        if let v = payload["heartRateBPM"] as? Double, v > 0 {
            currentHeartRateBPM = Int(v)
        }
        if let v = payload["distanceMeters"] as? Double {
            currentDistanceMeters = v
        }
        if let v = payload["activeEnergyKcal"] as? Double {
            currentCalories = v
        }
        if let v = payload["paceSecondsPerKm"] as? Double, v > 0 {
            // Convert sec/km → sec/m so it matches the existing display field.
            currentPaceSecondsPerMeter = v / 1000.0
        }
        if let v = payload["cadenceSPM"] as? Double, v > 0 {
            currentCadenceSPM = v
        }
        if let v = payload["runningPowerWatts"] as? Double, v > 0 {
            currentRunningPowerWatts = v
        }
        if let v = payload["strideLengthMeters"] as? Double, v > 0 {
            currentStrideLengthMeters = v
        }
        if let v = payload["verticalOscillationCm"] as? Double, v > 0 {
            currentVerticalOscillationCm = v
        }
        if let v = payload["groundContactTimeMs"] as? Double, v > 0 {
            currentGroundContactTimeMs = v
        }
        if let v = payload["bloodOxygenPercent"] as? Double, v > 0 {
            currentBloodOxygenPercent = v
        }
        if let v = payload["elapsedSeconds"] as? Double {
            currentElapsedSeconds = v
        }
    }

    private func startWCWatchdog() {
        wcWatchdog?.invalidate()
        // Watch is sending at 1 Hz (every 1s). 6s of silence ≈ 6 missed
        // packets — at that point the Watch is genuinely gone, not a hiccup.
        wcWatchdog = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard let last = self.lastWCMessageAt else { return }
                if Date().timeIntervalSince(last) > 6 {
                    wcLog.warning("No WC packet in 6s — clearing hasMirroredSession")
                    self.hasMirroredSession = false
                    self.stopWCWatchdog()
                }
            }
        }
    }

    private func stopWCWatchdog() {
        wcWatchdog?.invalidate()
        wcWatchdog = nil
    }

    var formattedDistance: String {
        if currentDistanceMeters >= 1000 {
            return String(format: "%.2f km", currentDistanceMeters / 1000)
        }
        return String(format: "%.0f m", currentDistanceMeters)
    }

    var formattedElapsed: String {
        let total = Int(currentElapsedSeconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        stopAltimeterIfRunning()
        activeQueries.forEach { healthStore.stop($0) }
        activeQueries.removeAll()
        detachMirroredSession()
        isActive = false
    }

    // MARK: - CoreLocation delegate (iPhone-side GPS fallback)

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last,
              loc.horizontalAccuracy >= 0,
              loc.horizontalAccuracy < 15,
              loc.speedAccuracy >= 0
        else { return }

        let pace = loc.speed > 0 ? 1.0 / loc.speed : 0
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Don't override mirrored speed
            if self.mirroredSession == nil {
                self.currentPaceSecondsPerMeter = pace
            }
        }
    }

    // MARK: - HealthKit standalone observation (SpO2 + auth for mirroring types)

    private func startHealthKitObservation() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.runningPower),
            HKQuantityType(.runningStrideLength),
            HKQuantityType(.runningSpeed),
            HKQuantityType(.runningVerticalOscillation),
            HKQuantityType(.runningGroundContactTime),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKObjectType.workoutType(),
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] granted, _ in
            guard granted else { return }
            Task { @MainActor [weak self] in self?.launchBackgroundQueries() }
        }
    }

    private func launchBackgroundQueries() {
        // SpO2 — 2 hour lookback so current reading appears immediately
        let twoHoursAgo = Date().addingTimeInterval(-7_200)
        let recentPredicate = HKQuery.predicateForSamples(
            withStart: twoHoursAgo, end: nil, options: .strictStartDate)

        observe(.oxygenSaturation, unit: .percent(), predicate: recentPredicate) { [weak self] fraction in
            self?.currentBloodOxygenPercent = fraction * 100
        }

        // HR fallback when no mirrored session — same 2-hour lookback
        observe(.heartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                predicate: recentPredicate) { [weak self] bpm in
            guard let self else { return }
            if self.mirroredSession == nil {
                self.currentHeartRateBPM = Int(bpm)
            }
        }
    }

    private func observe(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate,
        onUpdate: @MainActor @escaping (Double) -> Void
    ) {
        let type = HKQuantityType(identifier)

        let deliver: ([HKSample]?) -> Void = { samples in
            guard let latest = (samples as? [HKQuantitySample])?.last else { return }
            let value = latest.quantity.doubleValue(for: unit)
            Task { @MainActor in onUpdate(value) }
        }

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: { _, added, _, _, _ in deliver(added) }
        )
        query.updateHandler = { _, added, _, _, _ in deliver(added) }

        healthStore.execute(query)
        activeQueries.append(query)
    }

    // MARK: - Formatters

    var formattedPace: String {
        guard currentPaceSecondsPerMeter > 0 else { return "Standing still" }
        let secPerMile = currentPaceSecondsPerMeter * 1_609.34
        let minutes = Int(secPerMile) / 60
        let seconds = Int(secPerMile) % 60
        guard minutes < 60 else { return "Standing still" }
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    func getCurrentStateString() -> String {
        let spo2 = currentBloodOxygenPercent > 0
            ? String(format: "%.0f%%", currentBloodOxygenPercent)
            : "Searching..."
        let vo  = currentVerticalOscillationCm > 0
            ? String(format: "%.1f cm", currentVerticalOscillationCm)
            : "Searching..."
        let gct = currentGroundContactTimeMs > 0
            ? "\(Int(currentGroundContactTimeMs)) ms"
            : "Searching..."
        return """
        Heart Rate: \(currentHeartRateBPM > 0 ? "\(currentHeartRateBPM) BPM" : "Searching...")
        Pace: \(formattedPace)
        Cadence: \(Int(currentCadenceSPM)) steps per minute
        Elevation Change: \(String(format: "%.1f", currentElevationMeters)) meters
        Running Power: \(Int(currentRunningPowerWatts)) W
        Stride Length: \(String(format: "%.2f", currentStrideLengthMeters)) m
        Vertical Oscillation: \(vo)
        Ground Contact Time: \(gct)
        Blood Oxygen: \(spo2)
        Distance: \(String(format: "%.0f", currentDistanceMeters)) m
        """
    }
}

// MARK: - WCSessionDelegate (Watch → iPhone metric packets)

extension RunMetricsManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        if let error {
            wcLog.error("WCSession activation error: \(error.localizedDescription, privacy: .public)")
        }
        wcLog.info("WCSession activation: state=\(activationState.rawValue), paired=\(session.isPaired), reachable=\(session.isReachable)")
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        wcLog.info("WCSession became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        wcLog.info("WCSession deactivated — re-activating")
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        wcLog.info("WCSession reachability=\(session.isReachable)")
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in
            self?.applyWCPayload(message)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor [weak self] in
            self?.applyWCPayload(message)
        }
        replyHandler(["ack": true])
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor [weak self] in
            self?.applyWCPayload(userInfo)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate (mirrored session lifecycle)

extension RunMetricsManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        if toState == .ended {
            Task { @MainActor [weak self] in
                self?.detachMirroredSession()
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.detachMirroredSession()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate (mirrored Watch session data lands here)

extension RunMetricsManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let typeNames = collectedTypes.compactMap { ($0 as? HKQuantityType)?.identifier }.joined(separator: ",")
        mirrorLog.info("📡 didCollectDataOf: \(typeNames, privacy: .public)")
        var raw = RawMetrics()
        for type in collectedTypes {
            guard let qt = type as? HKQuantityType else { continue }
            guard let stats = workoutBuilder.statistics(for: qt) else { continue }

            switch qt {
            case HKQuantityType(.heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                raw.heartRate = stats.mostRecentQuantity()?.doubleValue(for: unit)

            case HKQuantityType(.distanceWalkingRunning):
                raw.distance = stats.sumQuantity()?.doubleValue(for: .meter())

            case HKQuantityType(.activeEnergyBurned):
                raw.calories = stats.sumQuantity()?.doubleValue(for: .kilocalorie())

            case HKQuantityType(.runningSpeed):
                raw.speed = stats.mostRecentQuantity()?.doubleValue(for: .meter().unitDivided(by: .second()))

            case HKQuantityType(.runningStrideLength):
                raw.stride = stats.mostRecentQuantity()?.doubleValue(for: .meter())

            case HKQuantityType(.runningPower):
                raw.power = stats.mostRecentQuantity()?.doubleValue(for: .watt())

            case HKQuantityType(.runningVerticalOscillation):
                if let v = stats.mostRecentQuantity()?.doubleValue(for: .meter()) {
                    raw.verticalOscillationCm = v * 100   // meters → cm
                }

            case HKQuantityType(.runningGroundContactTime):
                raw.groundContactTimeMs = stats.mostRecentQuantity()?
                    .doubleValue(for: .secondUnit(with: .milli))

            default:
                break
            }
        }

        // Merge non-nil fields into `pendingMetrics` and fire a tick; the
        // throttle sink at 1 Hz reads `pendingMetrics` so every metric stays
        // fresh even when HealthKit delivers types in separate callbacks.
        let captured = raw
        Task { @MainActor [weak self] in
            self?.mergePending(captured)
        }
    }
}
