import Foundation

/// Tracks unread activity separately from the visibility of its reminder.
struct ReminderState {
    private(set) var snapshot: AppMonitorSnapshot?
    private(set) var isVisible = false
    private(set) var isPreview = false
    private(set) var isPaused: Bool
    private(set) var pauseUntil: Date?
    private(set) var detectedAt = Date()
    private var forceNextReminder = false

    init(isPaused: Bool = false, pauseUntil: Date? = nil) {
        self.isPaused = isPaused
        self.pauseUntil = isPaused ? pauseUntil : nil
    }

    var hasUnread: Bool { snapshot?.unreadState.hasUnread == true }

    mutating func receive(_ next: AppMonitorSnapshot, now: Date = Date()) {
        let previous = snapshot
        snapshot = next
        guard next.monitoringIssue == nil else {
            isVisible = false
            isPreview = false
            return
        }
        guard next.isRunning, next.unreadState.hasUnread else {
            if !isPreview { isVisible = false }
            return
        }
        let increased: Bool
        if case .hasUnread(let old?) = previous?.unreadState,
           case .hasUnread(let new?) = next.unreadState {
            increased = new > old
        } else {
            increased = false
        }
        let newActivity = previous?.unreadState.hasUnread != true || increased || previous?.monitoringIssue != nil
        if newActivity { detectedAt = now }
        if !isPaused && (newActivity || forceNextReminder) {
            isVisible = true
            isPreview = false
        }
        forceNextReminder = false
    }

    mutating func hide() {
        isVisible = false
        isPreview = false
    }

    mutating func pause(minutes: Double?, now: Date = Date()) {
        isPaused = true
        pauseUntil = minutes.map { now.addingTimeInterval($0 * 60) }
        hide()
    }

    mutating func resumeAfterPermissionChange() {
        forceNextReminder = true
    }

    mutating func resume() {
        isPaused = false
        pauseUntil = nil
        forceNextReminder = true
    }

    /// The caller immediately polls again after expiration, including after system sleep.
    mutating func expirePause(now: Date = Date()) -> Bool {
        guard isPaused, let pauseUntil, now >= pauseUntil else { return false }
        resume()
        return true
    }

    mutating func preview(now: Date = Date()) {
        isPreview = true
        isVisible = true
        detectedAt = now
    }

    var displaySnapshot: AppMonitorSnapshot? {
        if isPreview {
            return AppMonitorSnapshot(providerID: "preview", appName: "U", isInstalled: true,
                                      isRunning: true, unreadState: .hasUnread(count: 3))
        }
        return snapshot
    }

    func pauseDescription(now: Date = Date()) -> String? {
        guard isPaused else { return nil }
        guard let pauseUntil else { return "Alerts paused until resumed" }
        let minutes = max(1, Int(ceil(pauseUntil.timeIntervalSince(now) / 60)))
        return "Alerts paused · \(minutes) min remaining"
    }
}
