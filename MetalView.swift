import SwiftUI
import MetalKit

class MetalView: MTKView {
    var commandQueue: MTLCommandQueue?
    var pipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var rotation: Float = 0

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Device loading error")
        }
        self.device = defaultDevice
        self.commandQueue = defaultDevice.makeCommandQueue()
        self.colorPixelFormat = .bgra8Unorm
        self.depthStencilPixelFormat = .depth32Float

        let vertexData: [Float] = [
             1, -1,  1,       1, 0, 0, 1,
            -1, -1,  1,       0, 1, 0, 1,
            -1,  1,  1,       0, 0, 1, 1,
             1,  1,  1,       1, 1, 0, 1,
             1, -1, -1,       1, 0, 1, 1,
            -1, -1, -1,       0, 1, 1, 1,
            -1,  1, -1,       1, 1, 1, 1,
             1,  1, -1,       0, 0, 0, 1,
        ]
        
        let indices: [UInt16] = [
            0, 1, 2, 2, 3, 0,
            0, 3, 7, 7, 4, 0, 
            4, 7, 6, 6, 5, 4,
            1, 5, 6, 6, 2, 1,
            3, 2, 6, 6, 7, 3,
            0, 4, 5, 5, 1, 0  
        ]

        vertexBuffer = defaultDevice.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.stride, options: [])
        indexBuffer = defaultDevice.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])

        let library = defaultDevice.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        pipelineState = try? defaultDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        self.depthStencilState = defaultDevice.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            self.rotation += 0.02
            self.draw()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let drawable = currentDrawable, let descriptor = currentRenderPassDescriptor else { return }
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.depthAttachment.clearDepth = 1.0
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .dontCare

        let commandBuffer = commandQueue?.makeCommandBuffer()
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        renderEncoder?.setRenderPipelineState(pipelineState!)
        renderEncoder?.setDepthStencilState(depthStencilState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        var modelMatrix = matrix_identity_float4x4
        modelMatrix = matrix_multiply(modelMatrix, matrix4x4_rotation(radians: rotation, axis: SIMD3<Float>(1, 1, 0)))
        
        renderEncoder?.setVertexBytes(&modelMatrix, length: MemoryLayout<float4x4>.stride, index: 1)
        
        renderEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: 36, indexType: .uint16, indexBuffer: indexBuffer!, indexBufferOffset: 0)
        
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}

func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> float4x4 {
    let unitAxis = normalize(axis)
    let ct = cos(radians)
    let st = sin(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z

    return float4x4(SIMD4<Float>( ct + x*x*ci,   x*y*ci - z*st, x*z*ci + y*st, 0),
                    SIMD4<Float>( y*x*ci + z*st, ct + y*y*ci,   y*z*ci - x*st, 0),
                    SIMD4<Float>( z*x*ci - y*st, z*y*ci + x*st, ct + z*z*ci,   0),
                    SIMD4<Float>( 0, 0, 0, 1))
}

extension float4x4 {
    static var identity: float4x4 {
        return matrix_identity_float4x4
    }
}