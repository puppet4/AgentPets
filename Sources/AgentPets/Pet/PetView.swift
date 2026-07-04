import SwiftUI

// MARK: - Touch Bar 主视图

/// 渲染在 Touch Bar 上的顶层 SwiftUI 视图.
/// 布局:仅精灵 + 小圆点,无文字标签.
struct PetView: View {
    @Bindable var model: PetModel
    let config: PetConfig
    let pack: Pack
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            spriteLayer
            Spacer()
            ProgressDot(state: model.state)
                .padding(.trailing, 4)
        }
        .padding(.leading, 4)
        .frame(width: 1009, height: 30, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var spriteLayer: some View {
        let mapName = config.spriteName(for: model.state)
        return SpritePlayer(
            state: model.state,
            pack: pack,
            fps: model.fps,
            spriteMapName: mapName
        )
        .frame(width: 28, height: 28)
        .modifier(StateAnimator(state: model.state))
        .saturation(model.state == .offline ? 0 : 1)
        .opacity(model.state == .offline ? 0.5 : 1.0)
    }
}

// MARK: - 状态动画

/// 根据状态叠加对应的 SwiftUI 动画修饰器.
private struct StateAnimator: ViewModifier {
    let state: PetState
    @State private var trigger: Bool = false

    func body(content: Content) -> some View {
        content
            .modifier(IdleBreathing(state: state))
            .modifier(ThinkingTilt(state: state))
            .modifier(WorkingBob(state: state))
            .modifier(SuccessBounce(state: state))
            .modifier(ErrorShake(state: state))
            .modifier(CompactingSpin(state: state))
    }
}

private struct IdleBreathing: ViewModifier {
    let state: PetState
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: state) { _, new in
                if new == .idle {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        scale = 1.06
                    }
                } else {
                    scale = 1.0
                }
            }
            .onAppear {
                if state == .idle {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        scale = 1.06
                    }
                }
            }
    }
}

private struct ThinkingTilt: ViewModifier {
    let state: PetState
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: state) { _, new in
                if new == .thinking {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        angle = 4
                    }
                } else {
                    angle = 0
                }
            }
            .onAppear {
                if state == .thinking {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        angle = 4
                    }
                }
            }
    }
}

private struct WorkingBob: ViewModifier {
    let state: PetState
    @State private var y: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: y)
            .onChange(of: state) { _, new in
                if new.isWorking {
                    withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                        y = -1.5
                    }
                } else {
                    y = 0
                }
            }
            .onAppear {
                if state.isWorking {
                    withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                        y = -1.5
                    }
                }
            }
    }
}

private struct SuccessBounce: ViewModifier {
    let state: PetState
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: state) { _, new in
                if new == .success {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        scale = 1.3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            scale = 1.0
                        }
                    }
                }
            }
    }
}

private struct ErrorShake: ViewModifier {
    let state: PetState
    @State private var x: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: x)
            .onChange(of: state) { _, new in
                if new == .error {
                    runShake()
                }
            }
    }

    private func runShake() {
        for i in 0..<4 {
            let dx: CGFloat = (i % 2 == 0) ? 3 : -3
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                withAnimation(.linear(duration: 0.04)) { x = dx }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.linear(duration: 0.04)) { x = 0 }
        }
    }
}

private struct CompactingSpin: ViewModifier {
    let state: PetState
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: state) { _, new in
                if new == .compacting {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                } else {
                    angle = 0
                }
            }
            .onAppear {
                if state == .compacting {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }
            }
    }
}
