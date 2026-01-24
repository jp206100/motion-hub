//
//  PackManager.swift
//  Motion Hub
//
//  Pack storage and management
//

import Foundation
import Combine
import AppKit

// MARK: - Pack Save Errors

enum PackSaveError: LocalizedError {
    case emptyPackName
    case noMediaFiles
    case invalidMediaFile(url: URL, reason: String)
    case directoryCreationFailed(path: String, underlying: Error)
    case fileCopyFailed(source: URL, destination: URL, underlying: Error)
    case manifestEncodingFailed(underlying: Error)
    case manifestWriteFailed(path: String, underlying: Error)
    case packNotFound(id: UUID)
    case manifestLoadFailed(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .emptyPackName:
            return "Pack name cannot be empty"
        case .noMediaFiles:
            return "At least one media file is required"
        case .invalidMediaFile(let url, let reason):
            return "Invalid media file '\(url.lastPathComponent)': \(reason)"
        case .directoryCreationFailed(let path, let underlying):
            return "Failed to create directory at '\(path)': \(underlying.localizedDescription)"
        case .fileCopyFailed(let source, _, let underlying):
            return "Failed to copy '\(source.lastPathComponent)': \(underlying.localizedDescription)"
        case .manifestEncodingFailed(let underlying):
            return "Failed to encode pack data: \(underlying.localizedDescription)"
        case .manifestWriteFailed(let path, let underlying):
            return "Failed to write manifest to '\(path)': \(underlying.localizedDescription)"
        case .packNotFound(let id):
            return "Pack not found: \(id.uuidString)"
        case .manifestLoadFailed(let path, let underlying):
            return "Failed to load pack manifest from '\(path)': \(underlying.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyPackName:
            return "Enter a name for your pack"
        case .noMediaFiles:
            return "Add at least one image, video, or GIF to your pack"
        case .invalidMediaFile:
            return "Remove the invalid file and try again"
        case .directoryCreationFailed:
            return "Check disk space and permissions"
        case .fileCopyFailed:
            return "Ensure the file exists and is readable"
        case .manifestEncodingFailed, .manifestWriteFailed:
            return "Try saving again. If the problem persists, restart the app"
        case .packNotFound:
            return "The pack may have been deleted. Refresh the pack list"
        case .manifestLoadFailed:
            return "The pack data may be corrupted. Try deleting and recreating it"
        }
    }
}

class PackManager: ObservableObject {
    // MARK: - Properties

    private let logger = DebugLogger.shared

    // MARK: - Directories
    static let applicationSupportDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("MotionHub")
    }()

    static let packsDirectory = applicationSupportDirectory.appendingPathComponent("packs")

    // MARK: - Initialization

    static func setupApplicationDirectories() {
        let directories = [
            applicationSupportDirectory,
            packsDirectory
        ]

        for directory in directories {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - Pack Management

    func listPacks() -> [PackInfo] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: Self.packsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        var packs: [PackInfo] = []

        for packURL in contents {
            guard (try? packURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                continue
            }

            let manifestURL = packURL.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let pack = try? JSONDecoder().decode(InspirationPack.self, from: data) else {
                continue
            }

            let mediaDirectory = packURL.appendingPathComponent("media")
            let thumbnailURLs = pack.mediaFiles.prefix(3).compactMap { file -> URL? in
                return mediaDirectory.appendingPathComponent(file.filename)
            }

            let packInfo = PackInfo(
                id: pack.id,
                name: pack.name,
                createdAt: pack.createdAt,
                mediaCount: pack.mediaFiles.count,
                thumbnailURLs: thumbnailURLs
            )

            packs.append(packInfo)
        }

        return packs.sorted { $0.createdAt > $1.createdAt }
    }

    func loadPack(id: UUID) async throws -> InspirationPack {
        logger.logPackLoadStart(packID: id)

        let packDirectory = Self.packsDirectory.appendingPathComponent(id.uuidString)
        let manifestURL = packDirectory.appendingPathComponent("manifest.json")

        // Check if pack exists
        guard FileManager.default.fileExists(atPath: packDirectory.path) else {
            let error = PackSaveError.packNotFound(id: id)
            logger.logPackLoadError(error, packID: id)
            throw error
        }

        logger.debug("Loading manifest from: \(manifestURL.path)", context: "PackLoad")

        do {
            let data = try Data(contentsOf: manifestURL)
            logger.debug("Manifest data loaded: \(data.count) bytes", context: "PackLoad")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let pack = try decoder.decode(InspirationPack.self, from: data)

            logger.logPackLoadSuccess(name: pack.name)
            logger.debug("Pack contains \(pack.mediaFiles.count) media files", context: "PackLoad")

            // TODO: Load extracted artifacts
            // let artifactsURL = packDirectory.appendingPathComponent("artifacts/artifacts.json")
            // Load and process artifacts

            return pack
        } catch {
            let loadError = PackSaveError.manifestLoadFailed(path: manifestURL.path, underlying: error)
            logger.logPackLoadError(loadError, packID: id)
            throw loadError
        }
    }

    func savePack(name: String, mediaFiles: [URL], settings: PackSettings, existingPackID: UUID? = nil) async throws -> InspirationPack {
        // MARK: - Validation
        logger.logPackSaveStart(name: name, mediaCount: mediaFiles.count)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            logger.logValidationError("Pack name is empty")
            throw PackSaveError.emptyPackName
        }

        // Only require media files if this is a new pack (not updating existing)
        if existingPackID == nil && mediaFiles.isEmpty {
            logger.logValidationError("No media files provided")
            throw PackSaveError.noMediaFiles
        }

        // Validate media files exist and are readable
        logger.logPackSaveProgress(step: "Validating media files")
        for url in mediaFiles {
            guard FileManager.default.fileExists(atPath: url.path) else {
                logger.logValidationError("File does not exist: \(url.path)")
                throw PackSaveError.invalidMediaFile(url: url, reason: "File does not exist")
            }
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                logger.logValidationError("File is not readable: \(url.path)")
                throw PackSaveError.invalidMediaFile(url: url, reason: "File is not readable")
            }
            logger.debug("Validated: \(url.lastPathComponent)", context: "PackSave")
        }

        // MARK: - Directory Setup
        let packID = existingPackID ?? UUID()
        let packDirectory = Self.packsDirectory.appendingPathComponent(packID.uuidString)
        let mediaDirectory = packDirectory.appendingPathComponent("media")
        let artifactsDirectory = packDirectory.appendingPathComponent("artifacts")

        logger.logPackSaveProgress(step: "Creating directories", details: packDirectory.path)

        do {
            try FileManager.default.createDirectory(
                at: mediaDirectory,
                withIntermediateDirectories: true
            )
            logger.logFileOperation(operation: "Create directory", path: mediaDirectory.path, success: true)
        } catch {
            logger.logPackSaveError(error, step: "Create media directory")
            throw PackSaveError.directoryCreationFailed(path: mediaDirectory.path, underlying: error)
        }

        do {
            try FileManager.default.createDirectory(
                at: artifactsDirectory,
                withIntermediateDirectories: true
            )
            logger.logFileOperation(operation: "Create directory", path: artifactsDirectory.path, success: true)
        } catch {
            logger.logPackSaveError(error, step: "Create artifacts directory")
            throw PackSaveError.directoryCreationFailed(path: artifactsDirectory.path, underlying: error)
        }

        // MARK: - Load Existing Media Files (if updating)
        var savedMediaFiles: [MediaFile] = []
        if let existingPackID = existingPackID {
            do {
                let existingPack = try await loadPack(id: existingPackID)
                savedMediaFiles = existingPack.mediaFiles
                logger.debug("Loaded \(savedMediaFiles.count) existing media files", context: "PackSave")
            } catch {
                logger.warning("Could not load existing pack, starting fresh: \(error.localizedDescription)", context: "PackSave")
            }
        }

        // MARK: - Copy Media Files
        logger.logPackSaveProgress(step: "Copying media files", details: "\(mediaFiles.count) files")

        for (index, mediaURL) in mediaFiles.enumerated() {
            let filename = mediaURL.lastPathComponent
            let destinationURL = mediaDirectory.appendingPathComponent(filename)

            logger.debug("Copying file \(index + 1)/\(mediaFiles.count): \(filename)", context: "PackSave")

            // Skip if file already exists (for updates)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                logger.debug("Skipping existing file: \(filename)", context: "PackSave")
                continue
            }

            do {
                // Handle duplicate filenames
                var finalDestination = destinationURL
                var counter = 1
                while FileManager.default.fileExists(atPath: finalDestination.path) {
                    let nameWithoutExt = mediaURL.deletingPathExtension().lastPathComponent
                    let ext = mediaURL.pathExtension
                    let newFilename = "\(nameWithoutExt)_\(counter).\(ext)"
                    finalDestination = mediaDirectory.appendingPathComponent(newFilename)
                    counter += 1
                    logger.debug("Duplicate found, using: \(newFilename)", context: "PackSave")
                }

                try FileManager.default.copyItem(at: mediaURL, to: finalDestination)
                logger.logFileOperation(operation: "Copy file", path: finalDestination.path, success: true)

                let mediaType = determineMediaType(for: mediaURL)
                savedMediaFiles.append(MediaFile(filename: finalDestination.lastPathComponent, type: mediaType))
            } catch {
                logger.logPackSaveError(error, step: "Copy file: \(filename)")
                // Clean up on failure only if this is a new pack
                if existingPackID == nil {
                    try? FileManager.default.removeItem(at: packDirectory)
                }
                throw PackSaveError.fileCopyFailed(source: mediaURL, destination: destinationURL, underlying: error)
            }
        }

        // MARK: - Create and Save Manifest
        logger.logPackSaveProgress(step: "Creating pack manifest")

        let pack = InspirationPack(
            id: packID,
            name: trimmedName,
            mediaFiles: savedMediaFiles,
            settings: settings
        )

        let manifestURL = packDirectory.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let manifestData: Data
        do {
            manifestData = try encoder.encode(pack)
            logger.debug("Manifest encoded: \(manifestData.count) bytes", context: "PackSave")
        } catch {
            logger.logPackSaveError(error, step: "Encode manifest")
            if existingPackID == nil {
                try? FileManager.default.removeItem(at: packDirectory)
            }
            throw PackSaveError.manifestEncodingFailed(underlying: error)
        }

        do {
            try manifestData.write(to: manifestURL)
            logger.logFileOperation(operation: "Write manifest", path: manifestURL.path, success: true)
        } catch {
            logger.logPackSaveError(error, step: "Write manifest")
            if existingPackID == nil {
                try? FileManager.default.removeItem(at: packDirectory)
            }
            throw PackSaveError.manifestWriteFailed(path: manifestURL.path, underlying: error)
        }

        // TODO: Trigger preprocessing
        // await runPreprocessing(packDirectory: packDirectory, mediaFiles: savedMediaFiles)

        logger.logPackSaveSuccess(packID: packID, path: packDirectory.path)
        return pack
    }

    func deletePack(id: UUID) throws {
        logger.info("Deleting pack: \(id.uuidString)", context: "PackDelete")
        let packDirectory = Self.packsDirectory.appendingPathComponent(id.uuidString)

        guard FileManager.default.fileExists(atPath: packDirectory.path) else {
            logger.warning("Pack directory not found: \(packDirectory.path)", context: "PackDelete")
            throw PackSaveError.packNotFound(id: id)
        }

        do {
            try FileManager.default.removeItem(at: packDirectory)
            logger.info("Pack deleted successfully: \(id.uuidString)", context: "PackDelete")
        } catch {
            logger.error("Failed to delete pack: \(id.uuidString)", error: error, context: "PackDelete")
            throw error
        }
    }

    func mediaURL(for media: MediaFile, in packID: UUID) -> URL? {
        let packDirectory = Self.packsDirectory.appendingPathComponent(packID.uuidString)
        let mediaDirectory = packDirectory.appendingPathComponent("media")
        return mediaDirectory.appendingPathComponent(media.filename)
    }

    // MARK: - Helper Methods

    private func determineMediaType(for url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "jpg", "jpeg", "png", "heic", "tiff", "bmp":
            return .image
        case "gif":
            return .gif
        case "mp4", "mov", "m4v", "avi", "mkv":
            return .video
        default:
            return .image
        }
    }
}
