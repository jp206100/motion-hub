//
//  InspirationPack.swift
//  Motion Hub
//
//  Data models for inspiration packs and artifacts
//

import Foundation

// MARK: - Inspiration Pack
struct InspirationPack: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let mediaFiles: [MediaFile]
    let settings: PackSettings

    init(id: UUID = UUID(), name: String, mediaFiles: [MediaFile], settings: PackSettings) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.mediaFiles = mediaFiles
        self.settings = settings
    }
}

// MARK: - Media File
struct MediaFile: Codable, Identifiable {
    let id: UUID
    let filename: String
    let type: MediaType

    init(id: UUID = UUID(), filename: String, type: MediaType) {
        self.id = id
        self.filename = filename
        self.type = type
    }
}

enum MediaType: String, Codable {
    case image
    case video
    case gif
}

// MARK: - Pack Settings
struct PackSettings: Codable {
    var intensity: Double
    var glitchAmount: Double
    var speed: Int
    var colorShift: Double
    var pulseStrength: Double
    var freqMin: Double
    var freqMax: Double
    var isMonochrome: Bool
    var targetFPS: Int

    static let `default` = PackSettings(
        intensity: 0.72,
        glitchAmount: 0.35,
        speed: 2,
        colorShift: 0.72,
        pulseStrength: 0.6,
        freqMin: 80,
        freqMax: 4200,
        isMonochrome: false,
        targetFPS: 30
    )

    // Support loading old packs without pulseStrength
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intensity = try container.decode(Double.self, forKey: .intensity)
        glitchAmount = try container.decode(Double.self, forKey: .glitchAmount)
        speed = try container.decode(Int.self, forKey: .speed)
        colorShift = try container.decode(Double.self, forKey: .colorShift)
        pulseStrength = try container.decodeIfPresent(Double.self, forKey: .pulseStrength) ?? 0.6
        freqMin = try container.decode(Double.self, forKey: .freqMin)
        freqMax = try container.decode(Double.self, forKey: .freqMax)
        isMonochrome = try container.decode(Bool.self, forKey: .isMonochrome)
        targetFPS = try container.decode(Int.self, forKey: .targetFPS)
    }

    init(intensity: Double, glitchAmount: Double, speed: Int, colorShift: Double, pulseStrength: Double = 0.6, freqMin: Double, freqMax: Double, isMonochrome: Bool, targetFPS: Int) {
        self.intensity = intensity
        self.glitchAmount = glitchAmount
        self.speed = speed
        self.colorShift = colorShift
        self.pulseStrength = pulseStrength
        self.freqMin = freqMin
        self.freqMax = freqMax
        self.isMonochrome = isMonochrome
        self.targetFPS = targetFPS
    }
}

// MARK: - Pack Info (lightweight for listing)
struct PackInfo: Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let mediaCount: Int
    let thumbnailURLs: [URL]  // First 3 media files for preview
}

// MARK: - Extracted Artifacts
struct ExtractedArtifacts: Codable {
    let packId: UUID
    let createdAt: Date
    let sourceMedia: [MediaFile]
    let artifacts: Artifacts

    struct Artifacts: Codable {
        let colorPalettes: [ColorPalette]
        let textures: [Texture]
        let motionPatterns: [MotionPattern]
        let videoClips: [VideoClip]
        let ghostedImages: [GhostedImage]
    }
}

// MARK: - Artifact Types
struct ColorPalette: Codable, Identifiable {
    let id: UUID
    let colors: [String]  // Hex color strings
    let source: String    // Source filename

    init(id: UUID = UUID(), colors: [String], source: String) {
        self.id = id
        self.colors = colors
        self.source = source
    }
}

struct Texture: Codable, Identifiable {
    let id: UUID
    let filename: String
    let source: String
    let type: TextureType

    init(id: UUID = UUID(), filename: String, source: String, type: TextureType) {
        self.id = id
        self.filename = filename
        self.source = source
        self.type = type
    }

    enum TextureType: String, Codable {
        case edgeMap = "edge_map"
        case processed = "processed"
        case posterized = "posterized"
        case noise = "noise"
    }
}

struct MotionPattern: Codable, Identifiable {
    let id: UUID
    let filename: String
    let source: String
    let type: String

    init(id: UUID = UUID(), filename: String, source: String, type: String) {
        self.id = id
        self.filename = filename
        self.source = source
        self.type = type
    }
}

struct VideoClip: Codable, Identifiable {
    let id: UUID
    let filename: String
    let source: String
    let duration: Double
    let stretched: Bool

    init(id: UUID = UUID(), filename: String, source: String, duration: Double, stretched: Bool) {
        self.id = id
        self.filename = filename
        self.source = source
        self.duration = duration
        self.stretched = stretched
    }
}

struct GhostedImage: Codable, Identifiable {
    let id: UUID
    let filename: String
    let source: String
    let opacity: Double

    init(id: UUID = UUID(), filename: String, source: String, opacity: Double) {
        self.id = id
        self.filename = filename
        self.source = source
        self.opacity = opacity
    }
}
