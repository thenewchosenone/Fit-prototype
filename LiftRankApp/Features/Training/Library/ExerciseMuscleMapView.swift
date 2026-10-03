import MuscleMap
import SwiftUI

enum ExerciseMuscleMapDisplayStyle {
    case hero
    case standard
    case compact
}

struct ExerciseMuscleMap: View {
    let profile: ExerciseMuscleProfile
    let displayStyle: ExerciseMuscleMapDisplayStyle

    init(profile: ExerciseMuscleProfile, displayStyle: ExerciseMuscleMapDisplayStyle = .standard) {
        self.profile = profile
        self.displayStyle = displayStyle
    }

    var body: some View {
        GeometryReader { geometry in
            let showsLabels = displayStyle != .compact && geometry.size.width >= 140 && geometry.size.height >= 110
            let isCompact = displayStyle == .compact || geometry.size.width < 90 || geometry.size.height < 90
            let cardShape = RoundedRectangle(
                cornerRadius: min(displayStyle == .hero ? 18 : 14, geometry.size.height * 0.22),
                style: .continuous
            )
            ZStack {
                cardShape
                    .fill(
                        LinearGradient(
                            colors: [
                                displayStyle == .compact
                                    ? Color(red: 0.075, green: 0.082, blue: 0.105)
                                    : Color(red: 0.045, green: 0.05, blue: 0.065),
                                displayStyle == .compact
                                    ? Color(red: 0.115, green: 0.122, blue: 0.15)
                                    : Color(red: 0.085, green: 0.09, blue: 0.11)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        cardShape
                            .stroke(Color.white.opacity(displayStyle == .hero ? 0.08 : 0.055), lineWidth: 1)
                    }

                VStack(spacing: showsLabels ? 5 : 0) {
                    HStack(spacing: figureSpacing(width: geometry.size.width)) {
                        if isCompact && compactOrientation == .front {
                            AnatomicalMuscleFigure(profile: profile, side: .front, displayStyle: displayStyle)
                                .scaleEffect(compactScale, anchor: compactFocus)
                        } else if isCompact {
                            AnatomicalMuscleFigure(profile: profile, side: .back, displayStyle: displayStyle)
                                .scaleEffect(compactScale, anchor: compactFocus)
                        } else {
                            if profile.orientation == .front || profile.orientation == .split {
                                AnatomicalMuscleFigure(profile: profile, side: .front, displayStyle: displayStyle)
                            }
                            if profile.orientation == .back || profile.orientation == .split {
                                AnatomicalMuscleFigure(profile: profile, side: .back, displayStyle: displayStyle)
                            }
                        }
                    }
                    if showsLabels {
                        HStack(spacing: 4) {
                            if profile.orientation == .front || profile.orientation == .split {
                                orientationLabel("FRONT")
                            }
                            if profile.orientation == .back || profile.orientation == .split {
                                orientationLabel("BACK")
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding(height: geometry.size.height))
                .padding(.vertical, verticalPadding(height: geometry.size.height))
            }
            .clipShape(cardShape)
        }
    }

    private var compactOrientation: ExerciseMuscleMapOrientation {
        guard profile.orientation == .split else { return profile.orientation }
        let active = profile.primary.filter { $0 != .fullBody }
        let backCount = active.filter(\.isBackFacing).count
        return backCount > active.count - backCount ? .back : .front
    }

    private var compactScale: CGFloat {
        let active = profile.primary.filter { $0 != .fullBody }
        guard !active.isEmpty else { return displayStyle == .compact ? 1.12 : 0.92 }
        if active.contains(where: { [.quads, .hamstrings, .calves, .tibialis, .adductors].contains($0) }) {
            return displayStyle == .compact ? 1.60 : 1.58
        }
        if active.contains(.glutes) { return displayStyle == .compact ? 1.95 : 2.05 }
        if active.contains(where: { [.abs, .obliques, .spinalErectors].contains($0) }) {
            return displayStyle == .compact ? 1.90 : 1.95
        }
        return displayStyle == .compact ? 1.92 : 2.05
    }

    private var compactFocus: UnitPoint {
        let active = profile.primary.filter { $0 != .fullBody }
        if active.contains(where: { [.quads, .hamstrings, .calves, .tibialis, .adductors].contains($0) }) {
            return .bottom
        }
        if active.contains(.glutes) { return UnitPoint(x: 0.5, y: 0.66) }
        if active.contains(where: { [.abs, .obliques, .spinalErectors].contains($0) }) {
            return UnitPoint(x: 0.5, y: 0.42)
        }
        return UnitPoint(x: 0.5, y: 0.20)
    }

    private func orientationLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: displayStyle == .hero ? 10 : 9, weight: .black, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Color.liftMuted)
            .frame(maxWidth: .infinity)
    }

    private func figureSpacing(width: CGFloat) -> CGFloat {
        switch displayStyle {
        case .hero: return max(18, width * 0.055)
        case .standard: return max(10, width * 0.035)
        case .compact: return width * 0.025
        }
    }

    private func horizontalPadding(height: CGFloat) -> CGFloat {
        switch displayStyle {
        case .hero: return height * 0.075
        case .standard: return height * 0.065
        case .compact: return height * 0.045
        }
    }

    private func verticalPadding(height: CGFloat) -> CGFloat {
        switch displayStyle {
        case .hero: return height * 0.055
        case .standard: return height * 0.045
        case .compact: return height * 0.035
        }
    }
}

struct AnatomicalMuscleFigure: View {
    enum Side { case front, back }

    let profile: ExerciseMuscleProfile
    let side: Side
    let displayStyle: ExerciseMuscleMapDisplayStyle

    var body: some View {
        configuredFigure
            .aspectRatio(0.56, contentMode: .fit)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var configuredFigure: BodyView {
        let wholeBody = profile.primary.contains(.fullBody)
        let primaryRegions = wholeBody ? visibleRegions : profile.primary.filter(isVisible)
        let secondaryRegions = profile.secondary.filter(isVisible)
        var figure = BodyView(gender: .male, side: bodySide, style: bodyStyle)
            .showSubGroups()

        for muscle in mappedMuscles(for: secondaryRegions) {
            figure = figure.highlight(
                muscle,
                color: Color.liftGreen,
                opacity: displayStyle == .compact ? 0.78 : 0.58
            )
        }
        for muscle in mappedMuscles(for: primaryRegions) {
            figure = figure.highlight(
                muscle,
                linearGradient: [Color(red: 0.89, green: 1.0, blue: 0.38), Color.liftBlue],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return figure
    }

    private var bodyStyle: BodyViewStyle {
        let isCompact = displayStyle == .compact
        return BodyViewStyle(
            defaultFillColor: isCompact
                ? Color(red: 0.255, green: 0.27, blue: 0.33)
                : Color(red: 0.18, green: 0.19, blue: 0.235),
            strokeColor: Color.black.opacity(isCompact ? 0.34 : 0.48),
            strokeWidth: isCompact ? 0.5 : 0.7,
            selectionColor: Color.liftBlue,
            selectionStrokeColor: Color.black.opacity(0.25),
            selectionStrokeWidth: 0.8,
            headColor: isCompact
                ? Color(red: 0.19, green: 0.20, blue: 0.25)
                : Color(red: 0.095, green: 0.10, blue: 0.125),
            hairColor: isCompact
                ? Color(red: 0.105, green: 0.11, blue: 0.14)
                : Color(red: 0.055, green: 0.06, blue: 0.075),
            shadowColor: Color.liftBlue.opacity(0.32),
            shadowRadius: 3
        )
    }

    private var bodySide: BodySide {
        switch side {
        case .front: .front
        case .back: .back
        }
    }

    private var visibleRegions: [ExerciseMuscleRegion] {
        switch side {
        case .front:
            [
                .neck, .upperChest, .chest, .lowerChest,
                .frontDelts, .sideDelts, .biceps, .forearms,
                .abs, .obliques, .adductors, .quads, .tibialis
            ]
        case .back:
            [
                .neck, .traps, .rearDelts, .triceps, .forearms,
                .upperBack, .lats, .spinalErectors, .glutes,
                .hamstrings, .calves
            ]
        }
    }

    private func isVisible(_ region: ExerciseMuscleRegion) -> Bool {
        if region == .fullBody { return true }
        return side == .back ? region.isBackFacing : !region.isBackFacing
    }

    private func mappedMuscles(for regions: [ExerciseMuscleRegion]) -> [Muscle] {
        regions.compactMap(mappedMuscle).reduce(into: []) { result, muscle in
            if !result.contains(muscle) {
                result.append(muscle)
            }
        }
    }

    private func mappedMuscle(for region: ExerciseMuscleRegion) -> Muscle? {
        switch region {
        case .neck: .neck
        case .upperChest: .upperChest
        case .chest: .chest
        case .lowerChest: .lowerChest
        case .frontDelts: .frontDeltoid
        case .sideDelts: .deltoids
        case .rearDelts: .rearDeltoid
        case .biceps: .biceps
        case .triceps: .triceps
        case .forearms: .forearm
        case .traps: .trapezius
        case .upperBack: .rhomboids
        case .lats: .upperBack
        case .spinalErectors: .lowerBack
        case .abs: .abs
        case .obliques: .obliques
        case .glutes: .gluteal
        case .adductors: .adductors
        case .quads: .quadriceps
        case .hamstrings: .hamstring
        case .calves: .calves
        case .tibialis: .tibialis
        case .fullBody: nil
        }
    }
}
