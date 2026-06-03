// WorkoutManager.swift — watchOS producer
//
// Runs an HKWorkoutSession on the Watch and mirrors it to the paired iPhone
// using HealthKit's native mirroring (watchOS 10+/iOS 17+). The iOS app's
// RunMetricsManager picks up the mirrored session via
// HKHealthStore.workoutSessionMirroringStartHandler and receives every sensor
// sample (HR, runningSpeed, runningStrideLength, runningPower, distance,
// activeEnergy) with the same timing the Watch sees.
//
// Local concerns:
//   - Cadence: CMPedometer (HealthKit doesn't expose live cadence directly).
//   - SpO₂:    HKAnchoredObjectQuery on .oxygenSaturation. The system samples
//              on its own schedule and almost never during active motion —
//              this is just a "last reading" display.
//   - Throttle every @Published update to 1 Hz so SwiftUI doesn't churn.

import Foundation
import HealthKit
import CoreMotion
import Combine
import WatchConnectivity
import os.log

private let log = Logger(subsystem: "com.sujalshrestha.gemmacoach.watch", category: "WorkoutManager")

final class WorkoutManager: NSObject, ObservableObject {

    // MARK: - Public live state

    @Published private(set) var isRunning: Bool = false
    /// True while a previous session is asynchronously winding down. start()
    /// will queue a pending start instead of throwing if the user taps fast.
    @Published private(set) var isEnding: Bool = false
    @Published private(set) var heartRateBPM: Double = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var activeEnergyKcal: Double = 0
    @Published private(set) var paceSecondsPerKm: Double = 0
    @Published private(set) var cadenceSPM: Double = 0
    @Published private(set) var runningPowerWatts: Double = 0
    @Published private(set) var strideLengthMeters: Double = 0
    @Published private(set) var verticalOscillationCm: Double = 0
    @Published private(set) var groundContactTimeMs: Double = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var bloodOxygenPercent: Double = 0
    @Published private(set) var bloodOxygenAt: Date?
    @Published private(set) var mirroringToPhone: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var spo2Query: HKAnchoredObjectQuery?

    // MARK: - CoreMotion (cadence)

    private let pedometer = CMPedometer()
    private var pedometerActive = false

    /// If user taps Start while we're still finalizing the previous session,
    /// remember it and fire once the session reaches .ended.
    private var pendingStart: Bool = false

    // MARK: - WatchConnectivity (5-second metric packets to iPhone)

    private let wc = WCSession.default
    private var summaryTimer: Timer?
    /// 1.0s = 1 packet/second. Easier on WCSession's queue than 2 Hz and
    /// still updates the iPhone UI well within human perception.
    private static let summaryInterval: TimeInterval = 1.0

    // MARK: - Throttled raw subjects (1 Hz UI cap)

    private let rawHR      = PassthroughSubject<Double, Never>()
    private let rawDist    = PassthroughSubject<Double, Never>()
    private let rawEnergy  = PassthroughSubject<Double, Never>()
    private let rawPace    = PassthroughSubject<Double, Never>()
    private let rawCadence = PassthroughSubject<Double, Never>()
    private let rawPower   = PassthroughSubject<Double, Never>()
    private let rawStride  = PassthroughSubject<Double, Never>()
    private let rawVO      = PassthroughSubject<Double, Never>()
    private let rawGCT     = PassthroughSubject<Double, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Pace derivation (when runningSpeed isn't delivered)

    private var lastDistance: Double = 0
    private var lastSampleTime: Date?

    // MARK: - Elapsed timer

    private var startDate: Date?
    private var tickTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        wireThrottling()
        activateWatchConnectivity()
    }

    private func activateWatchConnectivity() {
        guard WCSession.isSupported() else {
            log.error("WCSession not supported on this device")
            return
        }
        wc.delegate = self
        wc.activate()
        log.info("WCSession activated (state=\(self.wc.activationState.rawValue))")
    }

    private func wireThrottling() {
        bind(rawHR,     to: \.heartRateBPM)
        bind(rawDist,   to: \.distanceMeters)
        bind(rawEnergy, to: \.activeEnergyKcal)
        bind(rawPace,   to: \.paceSecondsPerKm)
        bind(rawCadence, to: \.cadenceSPM)
        bind(rawPower,  to: \.runningPowerWatts)
        bind(rawStride, to: \.strideLengthMeters)
        bind(rawVO,     to: \.verticalOscillationCm)
        bind(rawGCT,    to: \.groundContactTimeMs)
    }

    private func bind(_ subject: PassthroughSubject<Double, Never>,
                      to keyPath: ReferenceWritableKeyPath<WorkoutManager, Double>) {
        subject
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?[keyPath: keyPath] = v }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let read: Set<HKSampleType> = [
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
        let write: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.runningSpeed),
            HKQuantityType(.runningStrideLength),
            HKQuantityType(.runningPower),
            HKQuantityType(.runningVerticalOscillation),
            HKQuantityType(.runningGroundContactTime),
        ]
        do {
            try await healthStore.requestAuthorization(toShare: write, read: read)
            startSpO2Listener()
        } catch {
            await MainActor.run { self.errorMessage = "Auth failed: \(error.localizedDescription)" }
        }
    }

    // MARK: - SpO₂ listener (best effort — system schedules samples)

    private func startSpO2Listener() {
        guard spo2Query == nil else { return }
        let type = HKQuantityType(.oxygenSaturation)

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.consumeSpO2(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.consumeSpO2(samples)
        }
        healthStore.execute(query)
        spo2Query = query
    }

    private func consumeSpO2(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.max(by: { $0.endDate < $1.endDate }) else { return }
        let value = latest.quantity.doubleValue(for: HKUnit.percent()) * 100
        let at = latest.endDate
        DispatchQueue.main.async {
            self.bloodOxygenPercent = value
            self.bloodOxygenAt = at
        }
    }

    // MARK: - Start / Stop

    func start() {
        // If a previous session is still asynchronously ending, queue this
        // start request — the session delegate will fire it when state
        // transitions to .ended.
        if isEnding {
            log.info("start() called while isEnding — queuing pendingStart")
            pendingStart = true
            return
        }
        guard !isRunning else {
            log.info("start() called while already running — ignored")
            return
        }
        log.info("start() — creating new HKWorkoutSession")

        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            let dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore, workoutConfiguration: config)
            builder.dataSource = dataSource

            // Opt-in to running form metrics. The data source's default
            // typesToCollect only includes HR, distance, and energy — without
            // these, the builder delegate never fires for stride/power/VO/GCT
            // even though authorization was granted.
            // NOTE: Form metrics require Apple Watch Series 6 or later silicon.
            // watchOS 26 already gates devices below that, so no extra check needed.
            let extraTypes: [HKQuantityType] = [
                HKQuantityType(.runningSpeed),
                HKQuantityType(.runningStrideLength),
                HKQuantityType(.runningPower),
                HKQuantityType(.runningVerticalOscillation),
                HKQuantityType(.runningGroundContactTime),
            ]
            for type in extraTypes {
                dataSource.enableCollection(for: type, predicate: nil)
            }

            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { [weak self] _, error in
                if let error {
                    log.error("beginCollection failed: \(error.localizedDescription, privacy: .public)")
                    Task { @MainActor in
                        self?.errorMessage = "beginCollection: \(error.localizedDescription)"
                    }
                } else {
                    log.info("beginCollection succeeded")
                }
            }

            // === THE NIKE MIRRORING HANDSHAKE ===
            // Wakes the paired iPhone and starts streaming session data over
            // the local network. iOS app's RunMetricsManager picks this up
            // via HKHealthStore.workoutSessionMirroringStartHandler.
            log.info("Calling startMirroringToCompanionDevice…")
            session.startMirroringToCompanionDevice { [weak self] success, error in
                Task { @MainActor in
                    if let error {
                        log.error("Mirroring failed: \(error.localizedDescription, privacy: .public)")
                        self?.errorMessage = "Mirroring: \(error.localizedDescription)"
                    } else {
                        log.info("Mirroring callback: success=\(success)")
                    }
                    self?.mirroringToPhone = success
                }
            }

            self.startDate = start
            self.lastDistance = 0
            self.lastSampleTime = nil
            self.isRunning = true
            startTick()
            startPedometer(from: start)
            startSummaryTimer()
        } catch {
            log.error("HKWorkoutSession init threw: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = "Start failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard isRunning, !isEnding else {
            log.info("stop() ignored — isRunning=\(self.isRunning) isEnding=\(self.isEnding)")
            return
        }
        log.info("stop() — flagging isEnding, calling session.end()")

        // Flip flags up-front so the UI immediately reflects the new state
        // and start() will queue rather than throw if user taps fast.
        isEnding = true
        isRunning = false
        mirroringToPhone = false
        stopTick()
        stopPedometer()

        // Tell HealthKit to wind down. References stay non-nil here — the
        // session delegate will null them out when state reaches .ended,
        // and only then is it safe to create a brand-new session.
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in
                log.info("finishWorkout completion fired")
            }
        }

        // Stop the 5s push and notify iPhone that the workout ended so the
        // iPhone UI's metrics card collapses.
        stopSummaryTimer()
        sendEndedPacket()
    }

    // MARK: - Cadence (CMPedometer)

    private func startPedometer(from startDate: Date) {
        guard CMPedometer.isCadenceAvailable() else { return }
        pedometerActive = true
        pedometer.startUpdates(from: startDate) { [weak self] data, _ in
            guard let self, let cadence = data?.currentCadence else { return }
            self.rawCadence.send(cadence.doubleValue * 60)   // steps/sec → steps/min
        }
    }

    private func stopPedometer() {
        guard pedometerActive else { return }
        pedometer.stopUpdates()
        pedometerActive = false
    }

    // MARK: - Elapsed timer

    private func startTick() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            DispatchQueue.main.async {
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTick() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    // MARK: - Formatting helpers

    var formattedPace: String {
        guard paceSecondsPerKm.isFinite, paceSecondsPerKm > 0, paceSecondsPerKm < 3600 else { return "—" }
        let m = Int(paceSecondsPerKm) / 60
        let s = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    var formattedDistance: String {
        if distanceMeters >= 1000 {
            return String(format: "%.2f km", distanceMeters / 1000)
        }
        return String(format: "%.0f m", distanceMeters)
    }

    var formattedElapsed: String {
        let total = Int(elapsedSeconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    var formattedCadence: String {
        cadenceSPM > 0 ? "\(Int(cadenceSPM)) spm" : "—"
    }

    var formattedStride: String {
        strideLengthMeters > 0 ? String(format: "%.2f m", strideLengthMeters) : "—"
    }

    var formattedPower: String {
        runningPowerWatts > 0 ? "\(Int(runningPowerWatts)) W" : "—"
    }

    var formattedVerticalOscillation: String {
        verticalOscillationCm > 0 ? String(format: "%.1f cm", verticalOscillationCm) : "—"
    }

    var formattedGroundContactTime: String {
        groundContactTimeMs > 0 ? "\(Int(groundContactTimeMs)) ms" : "—"
    }

    // MARK: - WCSession summary push (every 5 seconds)

    private func startSummaryTimer() {
        summaryTimer?.invalidate()
        summaryTimer = Timer.scheduledTimer(withTimeInterval: Self.summaryInterval, repeats: true) { [weak self] _ in
            self?.sendSummaryPacket()
        }
        // Fire one immediately so iPhone UI populates within a second of Start.
        sendSummaryPacket()
    }

    private func stopSummaryTimer() {
        summaryTimer?.invalidate()
        summaryTimer = nil
    }

    private func sendSummaryPacket() {
        guard isRunning else { return }
        var payload: [String: Any] = [
            "status": "running",
            "sentAt": Date().timeIntervalSince1970,
            "elapsedSeconds": elapsedSeconds,
        ]
        // Only include fields we actually have values for. iPhone-side will
        // apply only the present keys and leave others untouched.
        if heartRateBPM > 0          { payload["heartRateBPM"] = heartRateBPM }
        if distanceMeters > 0        { payload["distanceMeters"] = distanceMeters }
        if activeEnergyKcal > 0      { payload["activeEnergyKcal"] = activeEnergyKcal }
        if paceSecondsPerKm > 0      { payload["paceSecondsPerKm"] = paceSecondsPerKm }
        if cadenceSPM > 0            { payload["cadenceSPM"] = cadenceSPM }
        if runningPowerWatts > 0     { payload["runningPowerWatts"] = runningPowerWatts }
        if strideLengthMeters > 0    { payload["strideLengthMeters"] = strideLengthMeters }
        if verticalOscillationCm > 0 { payload["verticalOscillationCm"] = verticalOscillationCm }
        if groundContactTimeMs > 0   { payload["groundContactTimeMs"] = groundContactTimeMs }
        if bloodOxygenPercent > 0    { payload["bloodOxygenPercent"] = bloodOxygenPercent }

        deliver(payload)
    }

    private func sendEndedPacket() {
        let payload: [String: Any] = [
            "status": "ended",
            "sentAt": Date().timeIntervalSince1970,
        ]
        deliver(payload)
    }

    /// Sends via the best available WC channel. `sendMessage` for low latency
    /// when the iPhone is reachable; `transferUserInfo` (queued, guaranteed)
    /// as fallback so updates aren't lost if the iPhone is briefly asleep.
    private func deliver(_ payload: [String: Any]) {
        guard wc.activationState == .activated else {
            log.warning("WC not activated; dropping packet")
            return
        }
        if wc.isReachable {
            wc.sendMessage(payload, replyHandler: nil) { error in
                log.error("WC sendMessage failed: \(error.localizedDescription, privacy: .public)")
                // sendMessage failed — fall back to queued transfer
                WCSession.default.transferUserInfo(payload)
            }
            log.info("📤 Sent live summary via sendMessage (\(payload.keys.count) keys)")
        } else {
            wc.transferUserInfo(payload)
            log.info("📥 iPhone not reachable — queued summary via transferUserInfo")
        }
    }

    var formattedBloodOxygen: String {
        guard let at = bloodOxygenAt, bloodOxygenPercent > 0 else { return "—" }
        let pct = String(format: "%.0f%%", bloodOxygenPercent)
        let secs = Int(Date().timeIntervalSince(at))
        let age: String
        if secs < 60 { age = "\(secs)s ago" }
        else if secs < 3600 { age = "\(secs / 60)m ago" }
        else { age = "\(secs / 3600)h ago" }
        return "\(pct) · \(age)"
    }
}

// MARK: - WCSessionDelegate (watchOS — minimal, only activation callback required)

extension WorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            log.error("WCSession activation error: \(error.localizedDescription, privacy: .public)")
        }
        log.info("WCSession activation completed: state=\(activationState.rawValue), reachable=\(session.isReachable)")
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        log.info("Session state changed: \(fromState.rawValue) → \(toState.rawValue)")

        if toState == .ended {
            DispatchQueue.main.async {
                // Only now is it actually safe to release the old session
                // references and allow a new HKWorkoutSession to be created.
                log.info(".ended reached — releasing session refs")
                self.session = nil
                self.builder = nil
                self.mirroringToPhone = false
                self.isRunning = false
                self.isEnding = false

                // If the user already tapped Start while we were ending,
                // honor it now.
                if self.pendingStart {
                    log.info("Firing queued pendingStart")
                    self.pendingStart = false
                    self.start()
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        log.error("Session didFailWithError: \(error.localizedDescription, privacy: .public)")
        DispatchQueue.main.async {
            self.errorMessage = "Session: \(error.localizedDescription)"
            // Treat failure as an end — clean up so the user can retry.
            self.session = nil
            self.builder = nil
            self.isRunning = false
            self.isEnding = false
            self.mirroringToPhone = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: quantityType) else { continue }

            switch quantityType {
            case HKQuantityType(.heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                if let v = stats.mostRecentQuantity()?.doubleValue(for: unit) {
                    rawHR.send(v)
                }

            case HKQuantityType(.distanceWalkingRunning):
                if let v = stats.sumQuantity()?.doubleValue(for: .meter()) {
                    rawDist.send(v)
                    updatePaceFromDistance(totalMeters: v)
                }

            case HKQuantityType(.activeEnergyBurned):
                if let v = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    rawEnergy.send(v)
                }

            case HKQuantityType(.runningSpeed):
                let unit = HKUnit.meter().unitDivided(by: .second())
                if let v = stats.mostRecentQuantity()?.doubleValue(for: unit), v > 0.2 {
                    rawPace.send(1000.0 / v)        // m/s → sec/km
                }

            case HKQuantityType(.runningStrideLength):
                if let v = stats.mostRecentQuantity()?.doubleValue(for: .meter()) {
                    rawStride.send(v)
                }

            case HKQuantityType(.runningPower):
                if let v = stats.mostRecentQuantity()?.doubleValue(for: .watt()) {
                    rawPower.send(v)
                }

            case HKQuantityType(.runningVerticalOscillation):
                // Stored in meters; show as cm (typical range 6–12 cm).
                if let v = stats.mostRecentQuantity()?.doubleValue(for: .meter()) {
                    rawVO.send(v * 100)
                }

            case HKQuantityType(.runningGroundContactTime):
                // Stored in seconds; show as ms (typical range 200–300 ms).
                if let v = stats.mostRecentQuantity()?.doubleValue(for: .secondUnit(with: .milli)) {
                    rawGCT.send(v)
                }

            default:
                break
            }
        }
    }

    /// Fallback pace from Δdistance / Δtime when runningSpeed isn't delivered.
    private func updatePaceFromDistance(totalMeters: Double) {
        let now = Date()
        defer {
            self.lastDistance = totalMeters
            self.lastSampleTime = now
        }
        guard let last = lastSampleTime else { return }
        let dd = totalMeters - lastDistance
        let dt = now.timeIntervalSince(last)
        guard dd > 0.5, dt > 0.1 else { return }
        let metersPerSecond = dd / dt
        guard metersPerSecond > 0.2 else { return }
        rawPace.send(1000.0 / metersPerSecond)
    }
}
