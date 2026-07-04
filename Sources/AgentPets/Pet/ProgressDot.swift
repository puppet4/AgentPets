import SwiftUI

/// Tiny color dot indicating state. Just a hint, the sprite is the main signal.
struct ProgressDot: View {
    let state: PetState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .overlay(
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
    }

    private var color: Color {
        switch state {
        case .idle:        return .gray
        case .listening:   return .blue
        case .thinking:    return .purple
        case .working, .searching, .editing, .running, .reading: return .orange
        case .success:     return .green
        case .error:       return .red
        case .compacting:  return .yellow
        case .offline:     return Color.gray.opacity(0.4)
        }
    }
}