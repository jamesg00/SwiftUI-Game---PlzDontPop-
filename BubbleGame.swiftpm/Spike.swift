import SwiftUI

struct Spike: Identifiable {
    let id = UUID()
    var position: CGPoint
    var direction: CGVector
    var angle: Double
    var speed: CGFloat
    var creationTime: TimeInterval
}
