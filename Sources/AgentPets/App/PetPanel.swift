import AppKit
import SwiftUI

enum PetPanelMode: Equatable, Sendable {
    case collapsed
    case expanded
}

struct PetPanelViewModel: Equatable, Sendable {
    var mode: PetPanelMode = .collapsed

    mutating func toggle() {
        mode = mode == .collapsed ? .expanded : .collapsed
    }

    mutating func collapseAfterTaskActivation() {
        mode = .collapsed
    }

    mutating func collapse() {
        mode = .collapsed
    }

    static func orderedTasks(_ tasks: [AgentTaskSnapshot]) -> [AgentTaskSnapshot] {
        tasks.sorted { lhs, rhs in
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
            if lhs.state.priority != rhs.state.priority {
                return lhs.state.priority > rhs.state.priority
            }
            if lhs.cpu != rhs.cpu {
                return lhs.cpu > rhs.cpu
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    static func dotAccent(for state: PetState) -> PanelAccent {
        switch state {
        case .offline, .idle:
            return .gray
        case .listening:
            return .blue
        case .thinking, .compacting:
            return .violet
        case .working, .searching, .editing, .running, .reading:
            return .aqua
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

struct PetPanelPlacement: Equatable, Sendable {
    private var manualBottomTrailingAnchor: CGPoint?

    mutating func capture(frame: NSRect) {
        manualBottomTrailingAnchor = CGPoint(x: frame.maxX, y: frame.minY)
    }

    func frame(for mode: PetPanelMode, taskCount: Int, in screenFrame: NSRect) -> NSRect {
        PetPanelMetrics.frame(
            for: mode,
            taskCount: taskCount,
            in: screenFrame,
            bottomTrailingAnchor: manualBottomTrailingAnchor
        )
    }
}

struct PetPanelDragSession: Equatable, Sendable {
    let startFrame: NSRect
    let startScreenPoint: CGPoint

    func frameOrigin(for currentScreenPoint: CGPoint, within screenFrame: NSRect) -> CGPoint {
        let proposedOrigin = CGPoint(
            x: startFrame.origin.x + (currentScreenPoint.x - startScreenPoint.x),
            y: startFrame.origin.y + (currentScreenPoint.y - startScreenPoint.y)
        )
        return PetPanelMetrics.clampedOrigin(
            for: proposedOrigin,
            size: startFrame.size,
            in: screenFrame
        )
    }
}

/// Non-activating, always-on-top floating panel in the bottom-right corner.
/// Shows the pet at all times without stealing focus from Terminal.
@MainActor
final class PetPanel: NSPanel {
    var touchBarProvider: (() -> NSTouchBar?)?
    var onFrameChanged: ((NSRect) -> Void)?
    private var dragSession: PetPanelDragSession?
    private var hostingView: NSHostingView<PetCornerView>?

    init(
        model: PetModel,
        config: PetConfig,
        pack: Pack,
        mode: PetPanelMode,
        placement: PetPanelPlacement,
        onTap: @escaping () -> Void,
        onActivateTask: @escaping (AgentTaskSnapshot) -> Void
    ) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 200, height: 100)
        let rect = placement.frame(for: mode, taskCount: model.tasks.count, in: screenFrame)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false

        updateContent(
            model: model,
            config: config,
            pack: pack,
            mode: mode,
            onTap: onTap,
            onActivateTask: onActivateTask
        )
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func makeTouchBar() -> NSTouchBar? { touchBarProvider?() }

    func updateLayout(mode: PetPanelMode, taskCount: Int, placement: PetPanelPlacement, animated: Bool) {
        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
        let targetFrame = placement.frame(for: mode, taskCount: taskCount, in: screenFrame)
        setFrame(targetFrame, display: true, animate: animated && dragSession == nil)
        onFrameChanged?(frame)
    }

    func updateContent(
        model: PetModel,
        config: PetConfig,
        pack: Pack,
        mode: PetPanelMode,
        onTap: @escaping () -> Void,
        onActivateTask: @escaping (AgentTaskSnapshot) -> Void
    ) {
        let corner = PetCornerView(
            model: model,
            config: config,
            pack: pack,
            mode: mode,
            onTap: onTap,
            onActivateTask: onActivateTask,
            onStagePress: { [weak self] screenPoint in
                self?.beginStageDrag(at: screenPoint)
            },
            onStageDrag: { [weak self] screenPoint in
                self?.dragStage(to: screenPoint)
            },
            onStageDragEnd: { [weak self] in
                self?.endStageDrag()
            }
        )

        if let hostingView {
            hostingView.rootView = corner
            hostingView.frame = contentView?.bounds ?? NSRect(origin: .zero, size: frame.size)
            return
        }

        let hostingView = NSHostingView(rootView: corner)
        hostingView.frame = contentView?.bounds ?? NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
        self.hostingView = hostingView
    }

    private func beginStageDrag(at screenPoint: CGPoint) {
        dragSession = PetPanelDragSession(
            startFrame: frame,
            startScreenPoint: screenPoint
        )
    }

    private func dragStage(to screenPoint: CGPoint) {
        guard let dragSession else { return }
        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? dragSession.startFrame
        let origin = dragSession.frameOrigin(for: screenPoint, within: screenFrame)
        setFrameOrigin(origin)
        onFrameChanged?(frame)
    }

    private func endStageDrag() {
        dragSession = nil
    }
}

// MARK: - Corner panel content

private enum PetPanelMetrics {
    static let collapsedWidth: CGFloat = 168
    static let collapsedHeight: CGFloat = 168
    static let expandedWidth: CGFloat = 296
    static let expandedBaseHeight: CGFloat = 228
    static let taskRowHeight: CGFloat = 54
    static let emptyTaskHeight: CGFloat = 34
    static let maxVisibleRows: Int = 6
    static let cornerInset: CGFloat = 16
    static let spriteStage: CGFloat = 142
    static let spriteSize: CGFloat = 122

    static func size(for mode: PetPanelMode, taskCount: Int, in screenFrame: NSRect) -> NSSize {
        switch mode {
        case .collapsed:
            return NSSize(width: collapsedWidth, height: collapsedHeight)
        case .expanded:
            let nominalHeight = expandedBaseHeight + taskViewportHeight(for: taskCount)
            let maxHeight = max(collapsedHeight, screenFrame.height - (cornerInset * 2))
            return NSSize(
                width: expandedWidth,
                height: min(nominalHeight, maxHeight)
            )
        }
    }

    static func frame(for mode: PetPanelMode, taskCount: Int, in screenFrame: NSRect) -> NSRect {
        let size = size(for: mode, taskCount: taskCount, in: screenFrame)
        return frame(for: mode, taskCount: taskCount, in: screenFrame, bottomTrailingAnchor: nil, size: size)
    }

    static func frame(
        for mode: PetPanelMode,
        taskCount: Int,
        in screenFrame: NSRect,
        bottomTrailingAnchor: CGPoint?
    ) -> NSRect {
        let size = size(for: mode, taskCount: taskCount, in: screenFrame)
        return frame(
            for: mode,
            taskCount: taskCount,
            in: screenFrame,
            bottomTrailingAnchor: bottomTrailingAnchor,
            size: size
        )
    }

    static func clampedOrigin(for proposedOrigin: CGPoint, size: NSSize, in screenFrame: NSRect) -> CGPoint {
        let minX = screenFrame.minX + cornerInset
        let maxX = max(minX, screenFrame.maxX - size.width - cornerInset)
        let minY = screenFrame.minY + cornerInset
        let maxY = max(minY, screenFrame.maxY - size.height - cornerInset)

        return CGPoint(
            x: min(max(proposedOrigin.x, minX), maxX),
            y: min(max(proposedOrigin.y, minY), maxY)
        )
    }

    private static func frame(
        for mode: PetPanelMode,
        taskCount: Int,
        in screenFrame: NSRect,
        bottomTrailingAnchor: CGPoint?,
        size: NSSize
    ) -> NSRect {
        let defaultOrigin = CGPoint(
            x: screenFrame.maxX - size.width - cornerInset,
            y: screenFrame.minY + cornerInset
        )
        let proposedOrigin = bottomTrailingAnchor.map {
            CGPoint(x: $0.x - size.width, y: $0.y)
        } ?? defaultOrigin
        let origin = clampedOrigin(for: proposedOrigin, size: size, in: screenFrame)

        return NSRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )
    }

    static func taskViewportHeight(for taskCount: Int) -> CGFloat {
        if taskCount <= 0 {
            return emptyTaskHeight
        }
        return CGFloat(min(taskCount, maxVisibleRows)) * taskRowHeight
    }
}

struct PetCornerView: View {
    @Bindable var model: PetModel
    let config: PetConfig
    let pack: Pack
    let mode: PetPanelMode
    let onTap: () -> Void
    let onActivateTask: (AgentTaskSnapshot) -> Void
    let onStagePress: (CGPoint) -> Void
    let onStageDrag: (CGPoint) -> Void
    let onStageDragEnd: () -> Void
    @State private var patImpulse: Int = 0

    var body: some View {
        let presentation = PanelStatusPresentation.for(model.state)
        let orderedTasks = PetPanelViewModel.orderedTasks(model.tasks)
        let dotAccent = PetPanelViewModel.dotAccent(for: model.state)

        return Group {
            switch mode {
            case .collapsed:
                collapsedBody(accent: dotAccent.color)
            case .expanded:
                expandedBody(
                    presentation: presentation,
                    orderedTasks: orderedTasks
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .accessibilityLabel(Text(presentation.accessibilityLabel))
    }

    private func collapsedBody(accent: Color) -> some View {
        ZStack(alignment: .topTrailing) {
            petStage(accent: accent)
            CollapsedStatusDot(accent: accent)
                .padding(.top, 22)
                .padding(.trailing, 18)
        }
        .padding(8)
    }

    private func expandedBody(
        presentation: PanelStatusPresentation,
        orderedTasks: [AgentTaskSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            taskSection(tasks: orderedTasks)

            Spacer(minLength: 0)

            Divider()
                .overlay(Color.white.opacity(0.08))

            ZStack(alignment: .bottomTrailing) {
                petStage(accent: presentation.accent.color)
                    .offset(x: -18, y: -8)
                StatusBadge(
                    state: model.state,
                    text: presentation.badgeText,
                    accent: presentation.accent.color,
                    symbolName: presentation.symbolName
                )
                .padding(.trailing, 4)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func taskSection(tasks: [AgentTaskSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("任务状态")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.88))
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if tasks.isEmpty {
                Text("暂无活跃任务")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(tasks, id: \.id) { task in
                            TaskListRow(task: task, onActivate: { onActivateTask(task) })
                            if task.id != tasks.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.08))
                            }
                        }
                    }
                }
                .frame(maxHeight: PetPanelMetrics.taskViewportHeight(for: tasks.count))
            }
        }
    }

    private func petStage(accent: Color) -> some View {
        ZStack {
            PresenceHalo(state: model.state, accent: accent)
            Ellipse()
                .fill(
                    Color.black.opacity(model.state == .offline ? 0.10 : 0.20)
                )
                .frame(width: 92, height: 15)
                .blur(radius: 5)
                .offset(y: 51)
            sprite
                .offset(y: -7)
        }
        .frame(width: PetPanelMetrics.spriteStage, height: PetPanelMetrics.spriteStage)
        .contentShape(Rectangle())
        .overlay {
            PetStageInteractionSurface(
                onTap: {
                    patImpulse += 1
                    onTap()
                },
                onPress: onStagePress,
                onDrag: onStageDrag,
                onDragEnd: onStageDragEnd
            )
        }
    }

    private var sprite: some View {
        let map = config.spriteName(for: model.state)
        return SpritePlayer(
            state: model.state,
            pack: pack,
            fps: model.fps,
            spriteMapName: map
        )
        .frame(width: PetPanelMetrics.spriteSize, height: PetPanelMetrics.spriteSize)
        .modifier(CornerAnim(state: model.state))
        .modifier(PatAnim(trigger: patImpulse))
        .saturation(model.state == .offline ? 0 : 1)
        .opacity(model.state == .offline ? 0.6 : 1.0)
    }
}

private struct PetStageInteractionSurface: NSViewRepresentable {
    let onTap: () -> Void
    let onPress: (CGPoint) -> Void
    let onDrag: (CGPoint) -> Void
    let onDragEnd: () -> Void

    func makeNSView(context: Context) -> PetStageInteractionNSView {
        let view = PetStageInteractionNSView()
        view.onTap = onTap
        view.onPress = onPress
        view.onDrag = onDrag
        view.onDragEnd = onDragEnd
        return view
    }

    func updateNSView(_ nsView: PetStageInteractionNSView, context: Context) {
        nsView.onTap = onTap
        nsView.onPress = onPress
        nsView.onDrag = onDrag
        nsView.onDragEnd = onDragEnd
    }
}

private final class PetStageInteractionNSView: NSView {
    var onTap: (() -> Void)?
    var onPress: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onDragEnd: (() -> Void)?

    private var mouseDownScreenPoint: CGPoint?
    private var didDrag = false
    private let dragThreshold: CGFloat = 4

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let screenPoint = screenPoint(for: event) else { return }
        mouseDownScreenPoint = screenPoint
        didDrag = false
        onPress?(screenPoint)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = mouseDownScreenPoint,
              let screenPoint = screenPoint(for: event) else { return }

        let dx = screenPoint.x - startPoint.x
        let dy = screenPoint.y - startPoint.y
        if !didDrag && hypot(dx, dy) >= dragThreshold {
            didDrag = true
        }
        if didDrag {
            onDrag?(screenPoint)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onTap?()
        }
        mouseDownScreenPoint = nil
        didDrag = false
        onDragEnd?()
    }

    private func screenPoint(for event: NSEvent) -> CGPoint? {
        guard let window else { return nil }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}

private struct TaskListRow: View {
    let task: AgentTaskSnapshot
    let onActivate: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        Button(action: onActivate) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(task.agent.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primaryAccent)
                        Text(task.hostDisplayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.88))
                        .lineLimit(1)
                    Text(footerText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: task.activationCapability == .exact ? "arrow.up.forward.square" : "macwindow")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryAccent.opacity(0.92))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var primaryAccent: Color {
        task.agent == .claude ? Color.orange : Color.cyan
    }

    private var footerText: String {
        let relative = Self.relativeFormatter.localizedString(for: task.lastActivityAt, relativeTo: .now)
        return "\(stateText) · \(relative)"
    }

    private var stateText: String {
        switch task.state {
        case .idle: return "idle"
        case .listening: return "listening"
        case .thinking: return "thinking"
        case .working: return "working"
        case .searching: return "searching"
        case .editing: return "editing"
        case .running: return "running"
        case .reading: return "reading"
        case .success: return "success"
        case .error: return "error"
        case .compacting: return "compacting"
        case .offline: return "offline"
        }
    }
}

private struct PresenceHalo: View {
    let state: PetState
    let accent: Color
    @State private var breathe = false

    private var isAwake: Bool { state != .offline }
    private var isBusy: Bool { state.isWorking || state == .thinking || state == .compacting }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        accent.opacity(isBusy ? 0.18 : 0.09),
                        Color.white.opacity(isAwake ? 0.05 : 0.02),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: 66
                )
            )
            .scaleEffect(breathe ? 1.06 : 0.96)
            .opacity(isAwake ? 1.0 : 0.55)
            .onAppear(perform: update)
            .onChange(of: state) { _, _ in update() }
    }

    private func update() {
        breathe = false
        let duration = isBusy ? 0.7 : 2.2
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            breathe = true
        }
    }
}

private struct CollapsedStatusDot: View {
    let accent: Color

    var body: some View {
        Circle()
            .fill(accent)
            .frame(width: 11, height: 11)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.72), lineWidth: 1.6)
            }
            .shadow(color: accent.opacity(0.34), radius: 8, x: 0, y: 2)
    }
}

private struct StatusBadge: View {
    let state: PetState
    let text: String
    let accent: Color
    let symbolName: String
    @State private var pulse = false

    private var isActive: Bool {
        state.isWorking || state == .thinking || state == .compacting
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(accent.opacity(state == .offline ? 0.65 : 0.98))
                .frame(width: 12, height: 12)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(state == .offline ? 0.66 : 0.92))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.52),
                            accent.opacity(state == .offline ? 0.24 : 0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        .shadow(color: accent.opacity(isActive ? 0.24 : 0.10), radius: 12, x: 0, y: 4)
        .overlay(alignment: .leading) {
            if isActive {
                Capsule()
                    .stroke(accent.opacity(0.26), lineWidth: 2)
                    .scaleEffect(x: pulse ? 1.08 : 0.96, y: pulse ? 1.20 : 0.92)
                    .opacity(pulse ? 0 : 0.65)
            }
        }
        .onAppear(perform: updatePulse)
        .onChange(of: isActive) { _, _ in updatePulse() }
    }

    private func updatePulse() {
        pulse = false
        guard isActive else { return }
        withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

private struct CornerAnim: ViewModifier {
    let state: PetState
    @State private var scale: CGFloat = 1.0
    @State private var y: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(y: y)
            .onAppear { apply(state) }
            .onChange(of: state) { _, new in
                apply(new)
            }
    }

    private func apply(_ new: PetState) {
        if new.isWorking {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                y = -3; scale = 1.06
            }
        } else if new == .idle {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                scale = 1.05; y = 0
            }
        } else if new == .success {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scale = 1.2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { scale = 1.0; y = 0 }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { scale = 1.0; y = 0 }
        }
    }
}

private struct PatAnim: ViewModifier {
    let trigger: Int
    @State private var scale: CGFloat = 1.0
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(angle))
            .onChange(of: trigger) { _, _ in
                withAnimation(.spring(response: 0.20, dampingFraction: 0.42)) {
                    scale = 1.13
                    angle = -4
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.58)) {
                        scale = 1.0
                        angle = 0
                    }
                }
            }
    }
}
