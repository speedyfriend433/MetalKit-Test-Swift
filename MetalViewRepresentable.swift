import SwiftUI

struct MetalViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MetalView {
        let metalView = MetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        return metalView
    }

    func updateUIView(_ uiView: MetalView, context: Context) {}
}