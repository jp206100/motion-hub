//
//  VisualEngine.swift
//  Motion Hub
//
//  Core Metal rendering engine with multi-pass pipeline
//  Supports inspiration pack textures and diverse visual patterns
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

    // MARK: - Offscreen Render Targets
    private var renderTarget0: MTLTexture?
    private var renderTarget1: MTLTexture?
    private var currentRenderTargetSize: CGSize = .zero

    // MARK: - Texture Loading
    private var textureLoader: TextureLoader?
    private var inspirationTextures: [MTLTexture] = []
    private var placeholderTexture: MTLTexture?
    private var paletteBuffer: MTLBuffer?

    // MARK: - State
    private var uniforms: Uniforms
    private var startTime: CFAbsoluteTime
    private var currentSeed: UInt32 = 0
    private var activePattern: Int32 = 0

    // MARK: - Audio Smoothing
    private var smoothedAudioLevel: Float = 0
    private var peakAudioLevel: Float = 0
    private var peakDecay: Float = 0.95

    // MARK: - Reset Transition
    private var transitionProgress: Float = 1.0
    private var previousFrameTexture: MTLTexture?
    private let transitionDuration: Float = 1.5

    // MARK: - Glitch Timing
    private var lastGlitchTime: Float = 0
    private var glitchHoldTime: Float = 0

    // MARK: - App State
    weak var appState: AppState?

    init?(device: MTLDevice) {
        print("🎨 VisualEngine init starting...")

        guard let queue = device.makeCommandQueue() else {
            print("🎨 ERROR: Failed to create command queue")
            return nil
        }
        print("🎨 Command queue created")

        self.device = device
        self.commandQueue = queue
        self.startTime = CFAbsoluteTimeGetCurrent()

        // Initialize texture loader
        self.textureLoader = TextureLoader(device: device)

        // Initialize uniforms with expanded fields
        self.uniforms = Uniforms(
            time: 0,
            deltaTime: 0,
            audioLevel: 0,
            audioBass: 0,
            audioMid: 0,
            audioHigh: 0,
            audioFreqBand: 0,
            audioPeak: 0,
            audioSmooth: 0,
            intensity: 0.72,
            glitchAmount: 0.35,
            speed: 2.0,
            colorShift: 0.15,
            isMonochrome: 0,
            resolution: simd_float2(1920, 1080),
            randomSeed: UInt32.random(in: 0..<UInt32.max),
            textureCount: 0,
            activePattern: 0,
            lastGlitchTime: 0,
            glitchHoldTime: 0
        )

        // Set initial random pattern
        currentSeed = uniforms.randomSeed
        activePattern = Int32(currentSeed % 8)
        uniforms.activePattern = activePattern

        print("🎨 Uniforms initialized, pattern: \(activePattern)")

        setupPipelines()
        print("🎨 Pipelines setup complete, count: \(pipelineStates.count)")

        // Create placeholder texture
        placeholderTexture = textureLoader?.createPlaceholderTexture()

        observeResetNotification()
        print("🎨 VisualEngine init complete")
    }

    // MARK: - Setup

    private func setupPipelines() {
        print("🎨 Setting up pipelines...")

        guard let library = device.makeDefaultLibrary() else {
            print("🎨 ERROR: Failed to create Metal library")
            return
        }
        print("🎨 Metal library created")

        // Base layer pipeline
        print("🎨 Creating baseLayer pipeline...")
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "baseLayerFragment"
        ) {
            pipelineStates["baseLayer"] = pipeline
            print("🎨 baseLayer pipeline created")
        } else {
            print("🎨 ERROR: Failed to create baseLayer pipeline")
        }

        // Texture composite pipeline
        print("🎨 Creating textureComposite pipeline...")
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "textureCompositeFragment"
        ) {
            pipelineStates["textureComposite"] = pipeline
            print("🎨 textureComposite pipeline created")
        } else {
            print("🎨 ERROR: Failed to create textureComposite pipeline")
        }

        // Glitch pipeline
        print("🎨 Creating glitch pipeline...")
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "glitchFragment"
        ) {
            pipelineStates["glitch"] = pipeline
            print("🎨 glitch pipeline created")
        } else {
            print("🎨 ERROR: Failed to create glitch pipeline")
        }

        // Post-process pipeline
        print("🎨 Creating postProcess pipeline...")
        if let pipeline = createPipeline(
            library: library,
            vertexFunction: "vertexShader",
            fragmentFunction: "postProcessFragment"
        ) {
            pipelineStates["postProcess"] = pipeline
            print("🎨 postProcess pipeline created")
        } else {
            print("🎨 ERROR: Failed to create postProcess pipeline")
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

    private func createRenderTargets(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }

        if currentRenderTargetSize == size { return }
        currentRenderTargetSize = size

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        renderTarget0 = device.makeTexture(descriptor: descriptor)
        renderTarget1 = device.makeTexture(descriptor: descriptor)

        print("🎨 Created render targets: \(Int(size.width))x\(Int(size.height))")
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

    // MARK: - Texture Loading

    /// Load textures from the current inspiration pack
    func loadInspirationPack(_ pack: InspirationPack, artifacts: ExtractedArtifacts?) {
        Task {
            guard let loader = textureLoader else { return }

            let textures = await loader.loadFromPack(pack, artifacts: artifacts)
            await MainActor.run {
                self.inspirationTextures = textures
                self.uniforms.textureCount = Int32(min(textures.count, 4))
                self.paletteBuffer = loader.createPaletteBuffer()
                print("🎨 Loaded \(textures.count) textures from pack")
            }
        }
    }

    /// Clear loaded textures
    func clearTextures() {
        inspirationTextures.removeAll()
        textureLoader?.clearAll()
        uniforms.textureCount = 0
        paletteBuffer = nil
    }

    // MARK: - Update

    func update(deltaTime: Float, audioLevels: AudioLevels, appState: AppState) {
        let currentTime = Float(CFAbsoluteTimeGetCurrent() - startTime)

        // Update uniforms
        uniforms.time = currentTime
        uniforms.deltaTime = deltaTime

        // Audio with smoothing
        uniforms.audioLevel = audioLevels.overall
        uniforms.audioBass = audioLevels.bass
        uniforms.audioMid = audioLevels.mid
        uniforms.audioHigh = audioLevels.high
        uniforms.audioFreqBand = audioLevels.frequencyBand

        // Smooth audio level (for visual smoothness)
        smoothedAudioLevel = smoothedAudioLevel * 0.7 + audioLevels.overall * 0.3
        uniforms.audioSmooth = smoothedAudioLevel

        // Peak detection (for transient response)
        if audioLevels.overall > peakAudioLevel {
            peakAudioLevel = audioLevels.overall
        } else {
            peakAudioLevel *= peakDecay
        }
        uniforms.audioPeak = peakAudioLevel

        // Controls
        uniforms.intensity = Float(appState.intensity)
        uniforms.glitchAmount = Float(appState.glitchAmount)
        uniforms.speed = Float(appState.speed)
        uniforms.colorShift = Float(appState.colorShift)
        uniforms.isMonochrome = appState.isMonochrome ? 1 : 0

        // Pattern selection stays consistent until reset
        uniforms.activePattern = activePattern

        // Glitch timing
        uniforms.lastGlitchTime = lastGlitchTime
        uniforms.glitchHoldTime = glitchHoldTime

        // Update transition
        if transitionProgress < 1.0 {
            transitionProgress += deltaTime / transitionDuration
            transitionProgress = min(1.0, transitionProgress)
        }
    }

    // MARK: - Render

    func render(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        // Update resolution and create render targets
        let viewportSize = view.drawableSize
        uniforms.resolution = simd_float2(Float(viewportSize.width), Float(viewportSize.height))
        createRenderTargets(size: viewportSize)

        // Multi-pass rendering pipeline:
        // Pass 1: Base Layer (procedural patterns) -> renderTarget0
        // Pass 2: Texture Composite (blend inspiration textures) -> renderTarget1
        // Pass 3: Glitch (apply glitch effects) -> renderTarget0
        // Pass 4: Post Process (final grading) -> drawable

        // === PASS 1: BASE LAYER ===
        if let baseTarget = renderTarget0 {
            renderPass(
                commandBuffer: commandBuffer,
                pipeline: pipelineStates["baseLayer"],
                targetTexture: baseTarget,
                inputTexture: nil,
                additionalTextures: []
            )
        }

        // === PASS 2: TEXTURE COMPOSITE ===
        if let compositeTarget = renderTarget1, let baseTarget = renderTarget0 {
            // Get inspiration textures (up to 4)
            var texturesToBind: [MTLTexture] = [baseTarget]

            for i in 0..<4 {
                if i < inspirationTextures.count {
                    texturesToBind.append(inspirationTextures[i])
                } else if let placeholder = placeholderTexture {
                    texturesToBind.append(placeholder)
                }
            }

            renderPassWithMultipleTextures(
                commandBuffer: commandBuffer,
                pipeline: pipelineStates["textureComposite"],
                targetTexture: compositeTarget,
                textures: texturesToBind
            )
        }

        // === PASS 3: GLITCH ===
        if let glitchTarget = renderTarget0, let compositeTarget = renderTarget1 {
            renderPass(
                commandBuffer: commandBuffer,
                pipeline: pipelineStates["glitch"],
                targetTexture: glitchTarget,
                inputTexture: compositeTarget,
                additionalTextures: []
            )
        }

        // === PASS 4: POST PROCESS (to drawable) ===
        if let descriptor = view.currentRenderPassDescriptor,
           let glitchResult = renderTarget0 {
            renderFinalPass(
                commandBuffer: commandBuffer,
                pipeline: pipelineStates["postProcess"],
                descriptor: descriptor,
                inputTexture: glitchResult
            )
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Render Pass Helpers

    private func renderPass(
        commandBuffer: MTLCommandBuffer,
        pipeline: MTLRenderPipelineState?,
        targetTexture: MTLTexture,
        inputTexture: MTLTexture?,
        additionalTextures: [MTLTexture]
    ) {
        guard let pipeline = pipeline else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = targetTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipeline)

        var uniformsCopy = uniforms
        encoder.setVertexBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)

        // Bind palette buffer
        if let palette = paletteBuffer {
            encoder.setFragmentBuffer(palette, offset: 0, index: 1)
        }

        // Bind input texture
        if let input = inputTexture {
            encoder.setFragmentTexture(input, index: 0)
        }

        // Bind additional textures
        for (i, texture) in additionalTextures.enumerated() {
            encoder.setFragmentTexture(texture, index: i + 1)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    private func renderPassWithMultipleTextures(
        commandBuffer: MTLCommandBuffer,
        pipeline: MTLRenderPipelineState?,
        targetTexture: MTLTexture,
        textures: [MTLTexture]
    ) {
        guard let pipeline = pipeline else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = targetTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipeline)

        var uniformsCopy = uniforms
        encoder.setVertexBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)

        // Bind palette buffer
        if let palette = paletteBuffer {
            encoder.setFragmentBuffer(palette, offset: 0, index: 1)
        }

        // Bind all textures
        for (i, texture) in textures.enumerated() {
            encoder.setFragmentTexture(texture, index: i)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    private func renderFinalPass(
        commandBuffer: MTLCommandBuffer,
        pipeline: MTLRenderPipelineState?,
        descriptor: MTLRenderPassDescriptor,
        inputTexture: MTLTexture
    ) {
        guard let pipeline = pipeline,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipeline)

        var uniformsCopy = uniforms
        encoder.setVertexBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniformsCopy, length: MemoryLayout<Uniforms>.stride, index: 0)

        encoder.setFragmentTexture(inputTexture, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    // MARK: - Reset

    func triggerReset() {
        // New random seed and pattern
        currentSeed = UInt32.random(in: 0..<UInt32.max)
        uniforms.randomSeed = currentSeed
        activePattern = Int32(currentSeed % 8)
        uniforms.activePattern = activePattern

        print("🎨 Visual reset: new pattern \(activePattern)")

        // Randomize which textures are active
        if !inspirationTextures.isEmpty, let loader = textureLoader {
            let randomTextures = loader.getRandomTextures(count: 4, seed: currentSeed)
            if !randomTextures.isEmpty {
                // Shuffle textures by putting random selection first
                var newOrder = randomTextures
                for tex in inspirationTextures {
                    if !newOrder.contains(where: { $0 === tex }) {
                        newOrder.append(tex)
                    }
                }
                inspirationTextures = newOrder
            }
        }

        // Start transition
        transitionProgress = 0.0
    }

    private func easeInOut(_ t: Float) -> Float {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

// MARK: - Uniforms Type
// This matches ShaderTypes.h exactly
struct Uniforms {
    var time: Float
    var deltaTime: Float

    // Audio - expanded for better reactivity
    var audioLevel: Float
    var audioBass: Float
    var audioMid: Float
    var audioHigh: Float
    var audioFreqBand: Float
    var audioPeak: Float
    var audioSmooth: Float

    // Controls
    var intensity: Float
    var glitchAmount: Float
    var speed: Float
    var colorShift: Float
    var isMonochrome: Int32

    // Resolution
    var resolution: simd_float2

    // Random seed
    var randomSeed: UInt32

    // Texture info
    var textureCount: Int32
    var activePattern: Int32

    // Glitch timing
    var lastGlitchTime: Float
    var glitchHoldTime: Float
}
