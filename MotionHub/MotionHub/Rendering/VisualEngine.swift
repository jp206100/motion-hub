//
//  VisualEngine.swift
//  Motion Hub
//
//  Core Metal rendering engine
//

import Foundation
import Metal
import MetalKit
import simd

class VisualEngine {
    // MARK: - Metal Resources
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineStates: [String: MTLRenderPipelineState] = [:]

    // MARK: - State
    private var uniforms: Uniforms
    private var startTime: CFAbsoluteTime
    private var currentSeed: UInt32 = 0

    // MARK: - Reset Transition
    private var transitionProgress: Float = 1.0  // 1.0 = complete
    private var previousFrameTexture: MTLTexture?
    private let transitionDuration: Float = 1.5

    // MARK: - App State
    weak var appState: AppState?

    init?(device: MTLDevice) {
        guard let queue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = queue
        self.startTime = CFAbsoluteTimeGetCurrent()

        // Initialize uniforms
        self.uniforms = Uniforms(
            time: 0,
            deltaTime: 0,
            audioLevel: 0,
            audioBass: 0,
            audioMid: 0,
            audioHigh: 0,
            audioFreqBand: 0,
            intensity: 0.72,
            glitchAmount: 0.35,
            speed: 2.0,
            colorShift: 0.15,
            isMonochrome: 0,
            resolution: simd_float2(1920, 1080),
            randomSeed: UInt32.random(in: 0..<UInt32.max)
        )

        setupPipelines()
        observeResetNotification()
    }

    // MARK: - Setup

    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }

        // Base layer pipeline
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "baseLayerFragment"
        ) {
            pipelineStates["baseLayer"] = pipeline
        }

        // Texture composite pipeline
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "textureCompositeFragment"
        ) {
            pipelineStates["textureComposite"] = pipeline
        }

        // Glitch pipeline
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "glitchFragment"
        ) {
            pipelineStates["glitch"] = pipeline
        }

        // Post-process pipeline
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "postProcessFragment"
        ) {
            pipelineStates["postProcess"] = pipeline
        }
    }

    private func createPipeline(
        library: MTLLibrary,
        vertexFunction: String,
        fragmentFunction: String
    ) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: vertexFunction)
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunction)
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create pipeline: \(error)")
            return nil
        }
    }

    private func observeResetNotification() {
        NotificationCenter.default.addObserver(
            forName: .resetVisuals,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.triggerReset()
        }
    }

    // MARK: - Update

    func update(deltaTime: Float, audioLevels: AudioLevels, appState: AppState) {
        let currentTime = Float(CFAbsoluteTimeGetCurrent() - startTime)

        // Update uniforms
        uniforms.time = currentTime
        uniforms.deltaTime = deltaTime

        // Audio
        uniforms.audioLevel = audioLevels.overall
        uniforms.audioBass = audioLevels.bass
        uniforms.audioMid = audioLevels.mid
        uniforms.audioHigh = audioLevels.high
        uniforms.audioFreqBand = audioLevels.frequencyBand

        // Controls
        uniforms.intensity = Float(appState.intensity)
        uniforms.glitchAmount = Float(appState.glitchAmount)
        uniforms.speed = Float(appState.speed)
        uniforms.colorShift = Float(appState.colorShift)
        uniforms.isMonochrome = appState.isMonochrome ? 1 : 0

        // Update transition
        if transitionProgress < 1.0 {
            transitionProgress += deltaTime / transitionDuration
            transitionProgress = min(1.0, transitionProgress)
        }
    }

    // MARK: - Render

    func render(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        // Update resolution
        let viewportSize = view.drawableSize
        uniforms.resolution = simd_float2(Float(viewportSize.width), Float(viewportSize.height))

        // Render the base layer with procedural visuals
        if let pipeline = pipelineStates["baseLayer"] {
            renderEncoder.setRenderPipelineState(pipeline)

            // Pass uniforms
            var uniformsCopy = uniforms
            renderEncoder.setVertexBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)
            renderEncoder.setFragmentBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)

            // Draw fullscreen quad
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Reset

    func triggerReset() {
        // TODO: Capture current frame
        // previousFrameTexture = captureCurrentFrame()

        // New random seed
        currentSeed = UInt32.random(in: 0..<UInt32.max)
        uniforms.randomSeed = currentSeed

        // TODO: Randomize active textures
        // selectRandomArtifacts()

        // Start transition
        transitionProgress = 0.0
    }

    private func easeInOut(_ t: Float) -> Float {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

// MARK: - Uniforms Type
// This matches ShaderTypes.h
struct Uniforms {
    var time: Float
    var deltaTime: Float

    var audioLevel: Float
    var audioBass: Float
    var audioMid: Float
    var audioHigh: Float
    var audioFreqBand: Float

    var intensity: Float
    var glitchAmount: Float
    var speed: Float
    var colorShift: Float
    var isMonochrome: Int32

    var resolution: simd_float2
    var randomSeed: UInt32
}
