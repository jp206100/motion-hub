//
//  PackManager.swift
//  Motion Hub
//
//  Pack storage and management
//

import Foundation
import Combine
import AppKit

class PackManager: ObservableObject {
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
        let packDirectory = Self.packsDirectory.appendingPathComponent(id.uuidString)
        let manifestURL = packDirectory.appendingPathComponent("manifest.json")

        let data = try Data(contentsOf: manifestURL)
        let pack = try JSONDecoder().decode(InspirationPack.self, from: data)

        // TODO: Load extracted artifacts
        // let artifactsURL = packDirectory.appendingPathComponent("artifacts/artifacts.json")
        // Load and process artifacts

        return pack
    }

    func savePack(name: String, mediaFiles: [URL], settings: PackSettings, existingPackID: UUID? = nil) async throws -> InspirationPack {
        let packID = existingPackID ?? UUID()
        let packDirectory = Self.packsDirectory.appendingPathComponent(packID.uuidString)
        let mediaDirectory = packDirectory.appendingPathComponent("media")
        let artifactsDirectory = packDirectory.appendingPathComponent("artifacts")

        // Create directories
        try FileManager.default.createDirectory(
            at: mediaDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: artifactsDirectory,
            withIntermediateDirectories: true
        )

        // Load existing media files if updating
        var savedMediaFiles: [MediaFile] = []
        if let existingPackID = existingPackID {
            do {
                let existingPack = try await loadPack(id: existingPackID)
                savedMediaFiles = existingPack.mediaFiles
                print("📦 Loaded \(savedMediaFiles.count) existing media files")
            } catch {
                print("⚠️ Could not load existing pack, starting fresh: \(error)")
            }
        }

        // Copy new media files
        for mediaURL in mediaFiles {
            let filename = mediaURL.lastPathComponent
            let destinationURL = mediaDirectory.appendingPathComponent(filename)

            // Skip if file already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("⏭️ Skipping existing file: \(filename)")
                continue
            }

            try FileManager.default.copyItem(at: mediaURL, to: destinationURL)

            let mediaType = determineMediaType(for: mediaURL)
            savedMediaFiles.append(MediaFile(filename: filename, type: mediaType))
            print("✅ Added new file: \(filename)")
        }

        // Create pack
        let pack = InspirationPack(
            id: packID,
            name: name,
            mediaFiles: savedMediaFiles,
            settings: settings
        )

        // Save manifest
        let manifestURL = packDirectory.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let manifestData = try encoder.encode(pack)
        try manifestData.write(to: manifestURL)

        // TODO: Trigger preprocessing
        // await runPreprocessing(packDirectory: packDirectory, mediaFiles: savedMediaFiles)

        return pack
    }

    func deletePack(id: UUID) throws {
        let packDirectory = Self.packsDirectory.appendingPathComponent(id.uuidString)
        try FileManager.default.removeItem(at: packDirectory)
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
