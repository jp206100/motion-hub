//
//  DebugLogger.swift
//  Motion Hub
//
//  Debug logging utility for tracking pack operations
//

import Foundation
import Combine
import os.log

/// Centralized logging for debugging pack save/load operations
final class DebugLogger {
    static let shared = DebugLogger()

    private let logger = Logger(subsystem: "com.motionhub.app", category: "PackOperations")
    private let dateFormatter: DateFormatter

    /// Log entries for in-app display
    @Published private(set) var recentLogs: [LogEntry] = []
    private let maxLogEntries = 100

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }

    // MARK: - Log Entry

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let context: String?
        let error: Error?

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"

        var emoji: String {
            switch self {
            case .debug: return "[D]"
            case .info: return "[I]"
            case .warning: return "[W]"
            case .error: return "[E]"
            }
        }
    }

    // MARK: - Logging Methods

    func debug(_ message: String, context: String? = nil) {
        log(level: .debug, message: message, context: context)
    }

    func info(_ message: String, context: String? = nil) {
        log(level: .info, message: message, context: context)
    }

    func warning(_ message: String, context: String? = nil) {
        log(level: .warning, message: message, context: context)
    }

    func error(_ message: String, error: Error? = nil, context: String? = nil) {
        log(level: .error, message: message, context: context, error: error)
    }

    private func log(level: LogLevel, message: String, context: String?, error: Error? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            context: context,
            error: error
        )

        // Console output for debugging
        let contextStr = context.map { " [\($0)]" } ?? ""
        let errorStr = error.map { " | Error: \($0.localizedDescription)" } ?? ""
        let fullMessage = "\(level.emoji)\(contextStr) \(message)\(errorStr)"

        switch level {
        case .debug:
            logger.debug("\(fullMessage)")
        case .info:
            logger.info("\(fullMessage)")
        case .warning:
            logger.warning("\(fullMessage)")
        case .error:
            logger.error("\(fullMessage)")
        }

        // Also print to console for development
        print("[\(entry.formattedTimestamp)] \(fullMessage)")

        // Store in recent logs
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentLogs.append(entry)
            if self.recentLogs.count > self.maxLogEntries {
                self.recentLogs.removeFirst()
            }
        }
    }

    // MARK: - Pack-Specific Logging

    func logPackSaveStart(name: String, mediaCount: Int) {
        info("Starting pack save", context: "PackSave")
        debug("Pack name: '\(name)', Media files: \(mediaCount)", context: "PackSave")
    }

    func logPackSaveProgress(step: String, details: String? = nil) {
        let message = details != nil ? "\(step) - \(details!)" : step
        debug(message, context: "PackSave")
    }

    func logPackSaveSuccess(packID: UUID, path: String) {
        info("Pack saved successfully", context: "PackSave")
        debug("Pack ID: \(packID.uuidString)", context: "PackSave")
        debug("Location: \(path)", context: "PackSave")
    }

    func logPackSaveError(_ error: Error, step: String) {
        self.error("Pack save failed at step: \(step)", error: error, context: "PackSave")
    }

    func logPackLoadStart(packID: UUID) {
        info("Loading pack: \(packID.uuidString)", context: "PackLoad")
    }

    func logPackLoadSuccess(name: String) {
        info("Pack loaded: '\(name)'", context: "PackLoad")
    }

    func logPackLoadError(_ error: Error, packID: UUID) {
        self.error("Failed to load pack: \(packID.uuidString)", error: error, context: "PackLoad")
    }

    // MARK: - Validation Logging

    func logValidationError(_ message: String) {
        warning("Validation failed: \(message)", context: "Validation")
    }

    func logFileOperation(operation: String, path: String, success: Bool) {
        if success {
            debug("\(operation) succeeded: \(path)", context: "FileOp")
        } else {
            warning("\(operation) failed: \(path)", context: "FileOp")
        }
    }

    // MARK: - Utility

    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.recentLogs.removeAll()
        }
    }

    func exportLogs() -> String {
        return recentLogs.map { entry in
            let errorStr = entry.error.map { " | Error: \($0.localizedDescription)" } ?? ""
            let contextStr = entry.context.map { " [\($0)]" } ?? ""
            let line = "[\(entry.formattedTimestamp)] \(entry.level.rawValue)\(contextStr) \(entry.message)\(errorStr)"
            return Self.redactUserPaths(line)
        }.joined(separator: "\n")
    }

    /// Replace the user's home directory path with ~ to avoid leaking usernames in exports.
    static func redactUserPaths(_ string: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return string.replacingOccurrences(of: home, with: "~")
    }
}
