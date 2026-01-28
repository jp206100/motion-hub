//
//  PreprocessingManager.swift
//  Motion Hub
//
//  Manages the Python preprocessing pipeline for extracting artifacts from media
//

import Foundation
import Combine

class PreprocessingManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var lastError: String?

    private let logger = DebugLogger.shared

    // Path to the Python script
    private var scriptPath: URL {
        // Look for script in app bundle or development location
        if let bundledPath = Bundle.main.url(forResource: "extract", withExtension: "py", subdirectory: "preprocessing") {
            return bundledPath
        }

        // Development path - relative to the project
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return projectRoot.appendingPathComponent("preprocessing/extract.py")
    }

    // MARK: - Public Methods

    /// Run preprocessing on media files for a pack
    /// - Parameters:
    ///   - packID: The UUID of the pack
    ///   - mediaFiles: List of media file URLs to process
    /// - Returns: True if preprocessing completed successfully
    func runPreprocessing(packID: UUID, mediaFiles: [URL]) async -> Bool {
        guard !mediaFiles.isEmpty else {
            logger.warning("No media files to preprocess", context: "Preprocessing")
            return false
        }

        await MainActor.run {
            isProcessing = true
            progress = 0.0
            statusMessage = "Starting preprocessing..."
            lastError = nil
        }

        let packDirectory = PackManager.packsDirectory.appendingPathComponent(packID.uuidString)
        let artifactsDirectory = packDirectory.appendingPathComponent("artifacts")

        // Ensure artifacts directory exists
        try? FileManager.default.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)

        // Build input file list (comma-separated)
        let mediaDirectory = packDirectory.appendingPathComponent("media")
        let inputFiles = mediaFiles.map { file -> String in
            // Files are stored in the media directory
            return mediaDirectory.appendingPathComponent(file.lastPathComponent).path
        }.joined(separator: ",")

        logger.info("Starting preprocessing for pack \(packID.uuidString)", context: "Preprocessing")
        logger.debug("Input files: \(inputFiles)", context: "Preprocessing")
        logger.debug("Output directory: \(artifactsDirectory.path)", context: "Preprocessing")

        // Check if Python is available
        guard let pythonPath = findPython() else {
            await MainActor.run {
                isProcessing = false
                lastError = "Python 3 not found. Please install Python 3 with required packages (numpy, opencv-python, scikit-learn, pillow)."
                statusMessage = "Error: Python not found"
            }
            logger.error("Python 3 not found", context: "Preprocessing")
            return false
        }

        // Check if script exists
        guard FileManager.default.fileExists(atPath: scriptPath.path) else {
            await MainActor.run {
                isProcessing = false
                lastError = "Preprocessing script not found at: \(scriptPath.path)"
                statusMessage = "Error: Script not found"
            }
            logger.error("Script not found at: \(scriptPath.path)", context: "Preprocessing")
            return false
        }

        await MainActor.run {
            progress = 0.1
            statusMessage = "Processing media files..."
        }

        // Run the Python script
        let success = await runPythonScript(
            pythonPath: pythonPath,
            scriptPath: scriptPath.path,
            inputFiles: inputFiles,
            outputDirectory: artifactsDirectory.path,
            packID: packID.uuidString
        )

        await MainActor.run {
            isProcessing = false
            progress = success ? 1.0 : 0.0
            statusMessage = success ? "Preprocessing complete" : "Preprocessing failed"
        }

        return success
    }

    // MARK: - Private Methods

    private func findPython() -> String? {
        // Common Python 3 paths
        let pythonPaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
        ]

        for path in pythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find via `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            logger.debug("Could not find python3 via which: \(error.localizedDescription)", context: "Preprocessing")
        }

        return nil
    }

    private func runPythonScript(
        pythonPath: String,
        scriptPath: String,
        inputFiles: String,
        outputDirectory: String,
        packID: String
    ) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [
                scriptPath,
                "--input", inputFiles,
                "--output", outputDirectory,
                "--pack-id", packID
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Handle stdout for progress updates
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    DispatchQueue.main.async {
                        self?.logger.debug("Python output: \(output)", context: "Preprocessing")

                        // Update progress based on output
                        if output.contains("Processing") {
                            self?.progress = min(0.9, (self?.progress ?? 0) + 0.1)
                            if let filename = output.components(separatedBy: " ").last {
                                self?.statusMessage = "Processing \(filename)..."
                            }
                        }
                    }
                }
            }

            // Handle stderr
            errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let error = String(data: data, encoding: .utf8), !error.isEmpty {
                    DispatchQueue.main.async {
                        self?.logger.warning("Python stderr: \(error)", context: "Preprocessing")
                    }
                }
            }

            process.terminationHandler = { [weak self] process in
                // Clean up handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                let success = process.terminationStatus == 0

                if !success {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    DispatchQueue.main.async {
                        self?.lastError = "Preprocessing failed: \(errorOutput)"
                        self?.logger.error("Preprocessing failed with status \(process.terminationStatus): \(errorOutput)", context: "Preprocessing")
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.logger.info("Preprocessing completed successfully", context: "Preprocessing")
                    }
                }

                continuation.resume(returning: success)
            }

            do {
                try process.run()
                logger.debug("Started preprocessing process with PID \(process.processIdentifier)", context: "Preprocessing")
            } catch {
                logger.error("Failed to start preprocessing: \(error.localizedDescription)", error: error, context: "Preprocessing")
                DispatchQueue.main.async {
                    self.lastError = "Failed to start preprocessing: \(error.localizedDescription)"
                }
                continuation.resume(returning: false)
            }
        }
    }
}
