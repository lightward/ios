import OSLog

/// Unified logging for the app. Logs flow to Console.app on-device
/// and to Xcode Organizer crash/diagnostic reports without a cable.
enum Log {
    static let phoropter = Logger(subsystem: "com.lightward", category: "phoropter")
    static let chat = Logger(subsystem: "com.lightward", category: "chat")
    static let api = Logger(subsystem: "com.lightward", category: "api")
    static let sync = Logger(subsystem: "com.lightward", category: "sync")
}
