//
//  TextureLoader.swift
//  Motion Hub
//
//  Loads inspiration pack images and textures into Metal textures
//  for use in the visual rendering pipeline
//

import Foundation
import Metal
import MetalKit
import AppKit
import AVFoundation

class TextureLoader {
    // MARK: - Properties

    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader
    private var loadedTextures: [String: MTLTexture] = [:]
    private var videoFrameTextures: [String: MTLTexture] = [:]

    // Maximum textures to keep loaded
    private let maxLoadedTextures = 16

    // Color palette extracted from textures
    private(set) var extractedPalette: [simd_float4] = []

    // MARK: - Initialization

    init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
    }

    // MARK: - Public Methods

    /// Load textures from an inspiration pack's artifacts
    func loadFromPack(_ pack: InspirationPack, artifacts: ExtractedArtifacts?) async -> [MTLTexture] {
        var textures: [MTLTexture] = []

        // Load original media files first
        let mediaDirectory = PackManager.packsDirectory
            .appendingPathComponent(pack.id.uuidString)
            .appendingPathComponent("media")

        for mediaFile in pack.mediaFiles {
            let filePath = mediaDirectory.appendingPathComponent(mediaFile.filename)

            if let texture = await loadTexture(from: filePath) {
                textures.append(texture)
                loadedTextures[mediaFile.id.uuidString] = texture

                if textures.count >= maxLoadedTextures {
                    break
                }
            }
        }

        // Load extracted textures from artifacts
        if let artifacts = artifacts {
            let artifactsDirectory = PackManager.packsDirectory
                .appendingPathComponent(pack.id.uuidString)
                .appendingPathComponent("artifacts")
                .appendingPathComponent("textures")

            for textureArtifact in artifacts.artifacts.textures {
                if textures.count >= maxLoadedTextures {
                    break
                }

                let texturePath = artifactsDirectory.appendingPathComponent(textureArtifact.filename)

                if let texture = await loadTexture(from: texturePath) {
                    textures.append(texture)
                    loadedTextures[textureArtifact.id.uuidString] = texture
                }
            }

            // Extract color palette from artifacts
            if let palette = artifacts.artifacts.colorPalettes.first {
                extractedPalette = palette.colors.prefix(6).map { hexColor in
                    colorFromHex(hexColor)
                }
            }
        }

        return textures
    }

    /// Load a single texture from a file URL
    func loadTexture(from url: URL) async -> MTLTexture? {
        // Check if already loaded
        if let existing = loadedTextures[url.path] {
            return existing
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let ext = url.pathExtension.lowercased()

        // Handle video files - extract a frame
        if ["mp4", "mov", "m4v", "avi"].contains(ext) {
            return await extractVideoFrame(from: url)
        }

        // Handle image files
        do {
            let options: [MTKTextureLoader.Option: Any] = [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .generateMipmaps: true,
                .SRGB: false
            ]

            let texture = try await textureLoader.newTexture(URL: url, options: options)
            loadedTextures[url.path] = texture
            return texture
        } catch {
            print("Failed to load texture from \(url.path): \(error)")
            return nil
        }
    }

    /// Extract a frame from a video file as a texture
    func extractVideoFrame(from url: URL, atTime: CMTime? = nil) async -> MTLTexture? {
        let asset = AVAsset(url: url)

        // Get video duration
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            print("Failed to get video duration: \(error)")
            return nil
        }

        // Extract frame at middle of video if no time specified
        let extractTime = atTime ?? CMTime(seconds: duration.seconds / 2, preferredTimescale: 600)

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        do {
            let (cgImage, _) = try await imageGenerator.image(at: extractTime)
            return createTexture(from: cgImage)
        } catch {
            print("Failed to extract video frame: \(error)")
            return nil
        }
    }

    /// Create a Metal texture from a CGImage
    func createTexture(from cgImage: CGImage) -> MTLTexture? {
        let width = cgImage.width
        let height = cgImage.height

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: true
        )
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .managed

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        // Create bitmap context and draw image
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Copy pixel data to texture
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                             size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: bytesPerRow
        )

        return texture
    }

    /// Create a placeholder texture with a solid color
    func createPlaceholderTexture(color: simd_float4 = simd_float4(0, 0, 0, 0)) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .managed

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        let pixel: [UInt8] = [
            UInt8(color.x * 255),
            UInt8(color.y * 255),
            UInt8(color.z * 255),
            UInt8(color.w * 255)
        ]

        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                             size: MTLSize(width: 1, height: 1, depth: 1)),
            mipmapLevel: 0,
            withBytes: pixel,
            bytesPerRow: 4
        )

        return texture
    }

    /// Get random textures for rendering (up to count)
    func getRandomTextures(count: Int, seed: UInt32) -> [MTLTexture] {
        let allTextures = Array(loadedTextures.values)

        guard !allTextures.isEmpty else {
            return []
        }

        // Use seed to deterministically select textures
        var selected: [MTLTexture] = []
        var rng = seed

        for _ in 0..<min(count, allTextures.count) {
            // Simple LCG random
            rng = rng &* 1103515245 &+ 12345
            let index = Int(rng >> 16) % allTextures.count
            selected.append(allTextures[index])
        }

        return selected
    }

    /// Clear all loaded textures
    func clearAll() {
        loadedTextures.removeAll()
        videoFrameTextures.removeAll()
        extractedPalette.removeAll()
    }

    // MARK: - Private Methods

    private func colorFromHex(_ hex: String) -> simd_float4 {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Float((rgb & 0xFF0000) >> 16) / 255.0
        let g = Float((rgb & 0x00FF00) >> 8) / 255.0
        let b = Float(rgb & 0x0000FF) / 255.0

        return simd_float4(r, g, b, 1.0)
    }
}

// MARK: - Color Palette Buffer

extension TextureLoader {
    /// Create a Metal buffer containing the color palette
    func createPaletteBuffer() -> MTLBuffer? {
        guard !extractedPalette.isEmpty else {
            return nil
        }

        // Pad to 6 colors
        var colors = extractedPalette
        while colors.count < 6 {
            colors.append(simd_float4(0, 0, 0, 0))
        }

        // ColorPalette struct layout in Metal (with alignment padding):
        // - 6 x simd_float4 colors = 96 bytes
        // - int colorCount = 4 bytes
        // - padding to 16-byte alignment = 12 bytes
        // Total = 112 bytes

        var paletteData = [UInt8](repeating: 0, count: 112)

        // Copy colors (96 bytes)
        for i in 0..<6 {
            let offset = i * 16
            let color = colors[i]
            withUnsafeBytes(of: color.x) { paletteData.replaceSubrange(offset..<offset+4, with: $0) }
            withUnsafeBytes(of: color.y) { paletteData.replaceSubrange(offset+4..<offset+8, with: $0) }
            withUnsafeBytes(of: color.z) { paletteData.replaceSubrange(offset+8..<offset+12, with: $0) }
            withUnsafeBytes(of: color.w) { paletteData.replaceSubrange(offset+12..<offset+16, with: $0) }
        }

        // Set colorCount at offset 96 (as Int32)
        let colorCount = Int32(min(extractedPalette.count, 6))
        withUnsafeBytes(of: colorCount) { paletteData.replaceSubrange(96..<100, with: $0) }

        return device.makeBuffer(bytes: paletteData, length: 112, options: .storageModeShared)
    }
}
