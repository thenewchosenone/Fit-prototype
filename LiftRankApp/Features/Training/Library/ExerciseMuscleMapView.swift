import SwiftUI

struct ExerciseMuscleMap: View {
    let profile: ExerciseMuscleProfile

    var body: some View {
        GeometryReader { geometry in
            let showsLabels = geometry.size.width >= 150 && geometry.size.height >= 140
            let isCompact = geometry.size.width < 90 || geometry.size.height < 90
            let cardShape = RoundedRectangle(
                cornerRadius: min(14, geometry.size.height * 0.22),
                style: .continuous
            )
            ZStack {
                cardShape
                    .fill(Color(red: 0.075, green: 0.08, blue: 0.095))
                    .overlay {
                        cardShape
                            .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    }

                VStack(spacing: showsLabels ? 5 : 0) {
                    HStack(spacing: geometry.size.width * 0.025) {
                        if isCompact && compactOrientation == .front {
                            AnatomicalMuscleFigure(profile: profile, side: .front)
                                .scaleEffect(compactScale, anchor: compactFocus)
                        } else if isCompact {
                            AnatomicalMuscleFigure(profile: profile, side: .back)
                                .scaleEffect(compactScale, anchor: compactFocus)
                        } else {
                            if profile.orientation == .front || profile.orientation == .split {
                                AnatomicalMuscleFigure(profile: profile, side: .front)
                            }
                            if profile.orientation == .back || profile.orientation == .split {
                                AnatomicalMuscleFigure(profile: profile, side: .back)
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
                .padding(.horizontal, geometry.size.height * 0.065)
                .padding(.vertical, geometry.size.height * 0.045)
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
        guard !active.isEmpty else { return 0.92 }
        if active.contains(where: { [.quads, .hamstrings, .calves, .tibialis, .adductors].contains($0) }) {
            return 1.58
        }
        if active.contains(.glutes) { return 2.05 }
        if active.contains(where: { [.abs, .obliques, .spinalErectors].contains($0) }) {
            return 1.95
        }
        return 2.05
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
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Color.liftMuted)
            .frame(maxWidth: .infinity)
    }
}

struct AnatomicalMuscleFigure: View {
    enum Side { case front, back }
    let profile: ExerciseMuscleProfile
    let side: Side

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let wholeBody = profile.primary.contains(.fullBody)
            let bodyFill = Color(red: 0.105, green: 0.11, blue: 0.135)
            let bodyOutline = Color.black.opacity(0.42)
            let segmentFill = Color(red: 0.155, green: 0.165, blue: 0.205)
            let segmentOutline = Color.black.opacity(0.34)
            let lineWidth = max(0.45, min(size.width, size.height) * 0.018)

            for path in bodyPaths(in: size) {
                context.fill(path, with: .color(bodyFill))
                context.stroke(path, with: .color(bodyOutline), lineWidth: lineWidth)
            }

            // Establish the complete anatomy before applying exercise-specific color.
            // This keeps unworked muscles visible instead of leaving a flat silhouette.
            draw(
                visibleMuscleSegments,
                color: segmentFill,
                outline: segmentOutline,
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.58
            )

            draw(
                profile.secondary.filter(isVisible),
                color: Color(red: 0.02, green: 0.52, blue: 1.0).opacity(0.48),
                outline: Color.black.opacity(0.28),
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.65
            )
            draw(
                wholeBody ? visibleMuscleSegments : profile.primary.filter(isVisible),
                color: Color(red: 0.01, green: 0.53, blue: 1.0),
                outline: Color.black.opacity(0.28),
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.85
            )

            // Redraw every boundary last so neutral and highlighted regions retain
            // the same anatomical segmentation at compact and expanded sizes.
            strokeMuscleSegments(
                visibleMuscleSegments,
                color: Color.black.opacity(0.34),
                in: &context,
                size: size,
                lineWidth: lineWidth * 0.48
            )

            let centerLine = centerAnatomyLine(in: size)
            context.stroke(centerLine, with: .color(Color.black.opacity(0.20)), lineWidth: lineWidth * 0.55)
            for landmark in anatomicalLandmarkPaths(in: size) {
                context.stroke(landmark, with: .color(Color.black.opacity(0.16)), lineWidth: lineWidth * 0.48)
            }
        }
        .aspectRatio(0.48, contentMode: .fit)
    }

    private var visibleMuscleSegments: [ExerciseMuscleRegion] {
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

    private func draw(
        _ regions: [ExerciseMuscleRegion],
        color: Color,
        outline: Color,
        in context: inout GraphicsContext,
        size: CGSize,
        lineWidth: CGFloat
    ) {
        for region in regions {
            for path in musclePaths(for: region, in: size) {
                context.fill(path, with: .color(color))
                context.stroke(path, with: .color(outline), lineWidth: lineWidth)
            }
        }
    }

    private func strokeMuscleSegments(
        _ regions: [ExerciseMuscleRegion],
        color: Color,
        in context: inout GraphicsContext,
        size: CGSize,
        lineWidth: CGFloat
    ) {
        for region in regions {
            for path in musclePaths(for: region, in: size) {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
        }
    }

    private func isVisible(_ region: ExerciseMuscleRegion) -> Bool {
        if region == .fullBody { return true }
        return side == .back ? region.isBackFacing : !region.isBackFacing
    }

    private func bodyPaths(in size: CGSize) -> [Path] {
        let leftArm: [(CGFloat, CGFloat)] = [
            (0.29, 0.22), (0.20, 0.225), (0.145, 0.285), (0.115, 0.38),
            (0.085, 0.515), (0.105, 0.595), (0.155, 0.59), (0.19, 0.49),
            (0.225, 0.36), (0.315, 0.285)
        ]
        let leftLeg: [(CGFloat, CGFloat)] = [
            (0.285, 0.555), (0.49, 0.585), (0.465, 0.755), (0.44, 0.865),
            (0.425, 0.975), (0.355, 0.99), (0.315, 0.945), (0.32, 0.84),
            (0.295, 0.75), (0.245, 0.64)
        ]

        var torso = Path()
        torso.move(to: point(0.42, 0.17, size))
        torso.addCurve(to: point(0.19, 0.25, size), control1: point(0.38, 0.20, size), control2: point(0.25, 0.20, size))
        torso.addCurve(to: point(0.29, 0.52, size), control1: point(0.22, 0.35, size), control2: point(0.25, 0.45, size))
        torso.addCurve(to: point(0.26, 0.62, size), control1: point(0.30, 0.56, size), control2: point(0.27, 0.59, size))
        torso.addCurve(to: point(0.50, 0.67, size), control1: point(0.34, 0.65, size), control2: point(0.42, 0.67, size))
        torso.addCurve(to: point(0.74, 0.62, size), control1: point(0.58, 0.67, size), control2: point(0.66, 0.65, size))
        torso.addCurve(to: point(0.71, 0.52, size), control1: point(0.73, 0.59, size), control2: point(0.70, 0.56, size))
        torso.addCurve(to: point(0.81, 0.25, size), control1: point(0.75, 0.45, size), control2: point(0.78, 0.35, size))
        torso.addCurve(to: point(0.58, 0.17, size), control1: point(0.75, 0.20, size), control2: point(0.62, 0.20, size))
        torso.closeSubpath()

        return [
            ellipse(0.405, 0.012, 0.19, 0.145, size),
            roundedRect(0.445, 0.14, 0.11, 0.10, radius: 0.03, size),
            torso,
            polygon(leftArm, size),
            polygon(mirrored(leftArm), size),
            polygon(leftLeg, size),
            polygon(mirrored(leftLeg), size)
        ]
    }

    private func musclePaths(for region: ExerciseMuscleRegion, in size: CGSize) -> [Path] {
        switch region {
        case .neck:
            return [roundedRect(0.435, 0.155, 0.13, 0.075, radius: 0.025, size)]
        case .upperChest:
            return pairedPolygons([(0.30, 0.265), (0.48, 0.245), (0.48, 0.305), (0.31, 0.32)], size)
        case .chest:
            return pairedPolygons([(0.28, 0.275), (0.48, 0.26), (0.48, 0.39), (0.31, 0.37)], size)
        case .lowerChest:
            return pairedPolygons([(0.31, 0.345), (0.48, 0.355), (0.48, 0.405), (0.33, 0.395)], size)
        case .frontDelts, .rearDelts:
            return [ellipse(0.185, 0.235, 0.155, 0.12, size), ellipse(0.66, 0.235, 0.155, 0.12, size)]
        case .sideDelts:
            return [ellipse(0.17, 0.245, 0.13, 0.13, size), ellipse(0.70, 0.245, 0.13, 0.13, size)]
        case .biceps, .triceps:
            return pairedPolygonGroups([
                [(0.16, 0.32), (0.23, 0.33), (0.205, 0.405), (0.14, 0.41), (0.12, 0.37)],
                [(0.14, 0.405), (0.205, 0.40), (0.20, 0.46), (0.13, 0.47), (0.115, 0.435)]
            ], size)
        case .forearms:
            return pairedPolygonGroups([
                [(0.13, 0.44), (0.17, 0.445), (0.145, 0.58), (0.10, 0.58)],
                [(0.17, 0.445), (0.20, 0.45), (0.16, 0.58), (0.145, 0.58)]
            ], size)
        case .traps:
            return [polygon([(0.40, 0.19), (0.50, 0.23), (0.60, 0.19), (0.68, 0.30), (0.32, 0.30)], size)]
        case .upperBack:
            return pairedPolygons([(0.27, 0.29), (0.48, 0.27), (0.48, 0.40), (0.31, 0.39)], size)
        case .lats:
            return pairedPolygons([(0.27, 0.34), (0.43, 0.38), (0.39, 0.54), (0.31, 0.50)], size)
        case .spinalErectors:
            return [
                roundedRect(0.44, 0.35, 0.045, 0.22, radius: 0.02, size),
                roundedRect(0.515, 0.35, 0.045, 0.22, radius: 0.02, size)
            ]
        case .abs:
            return abdominalPaths(in: size)
        case .obliques:
            return pairedPolygons([(0.30, 0.39), (0.39, 0.40), (0.40, 0.55), (0.32, 0.54)], size)
        case .glutes:
            return [ellipse(0.30, 0.55, 0.20, 0.13, size), ellipse(0.50, 0.55, 0.20, 0.13, size)]
        case .adductors:
            return pairedPolygons([(0.40, 0.64), (0.48, 0.63), (0.44, 0.80), (0.38, 0.79)], size)
        case .quads:
            return pairedPolygonGroups([
                [(0.285, 0.64), (0.355, 0.64), (0.36, 0.77), (0.335, 0.82), (0.30, 0.76)],
                [(0.355, 0.64), (0.41, 0.635), (0.405, 0.79), (0.36, 0.80)],
                [(0.41, 0.635), (0.455, 0.63), (0.435, 0.78), (0.405, 0.79)]
            ], size)
        case .hamstrings:
            return pairedPolygonGroups([
                [(0.29, 0.64), (0.37, 0.635), (0.375, 0.80), (0.34, 0.82), (0.30, 0.75)],
                [(0.37, 0.635), (0.455, 0.63), (0.43, 0.80), (0.375, 0.80)]
            ], size)
        case .calves:
            return pairedPolygonGroups([
                [(0.33, 0.80), (0.38, 0.80), (0.38, 0.92), (0.355, 0.95), (0.33, 0.91)],
                [(0.38, 0.80), (0.43, 0.80), (0.42, 0.94), (0.38, 0.92)]
            ], size)
        case .tibialis:
            return pairedPolygons([(0.35, 0.81), (0.40, 0.80), (0.40, 0.95), (0.36, 0.94)], size)
        case .fullBody:
            return []
        }
    }

    private func abdominalPaths(in size: CGSize) -> [Path] {
        var paths: [Path] = []
        for row in 0..<3 {
            let y = 0.385 + CGFloat(row) * 0.057
            paths.append(roundedRect(0.415, y, 0.075, 0.048, radius: 0.015, size))
            paths.append(roundedRect(0.510, y, 0.075, 0.048, radius: 0.015, size))
        }
        return paths
    }

    private func centerAnatomyLine(in size: CGSize) -> Path {
        var path = Path()
        path.move(to: point(0.50, side == .front ? 0.25 : 0.29, size))
        path.addLine(to: point(0.50, 0.61, size))
        return path
    }

    private func anatomicalLandmarkPaths(in size: CGSize) -> [Path] {
        var shoulderLine = Path()
        shoulderLine.move(to: point(0.31, 0.27, size))
        if side == .front {
            shoulderLine.addQuadCurve(to: point(0.50, 0.25, size), control: point(0.41, 0.24, size))
            shoulderLine.addQuadCurve(to: point(0.69, 0.27, size), control: point(0.59, 0.24, size))
        } else {
            shoulderLine.addQuadCurve(to: point(0.50, 0.34, size), control: point(0.40, 0.31, size))
            shoulderLine.addQuadCurve(to: point(0.69, 0.27, size), control: point(0.60, 0.31, size))
        }

        var pelvis = Path()
        pelvis.move(to: point(0.29, 0.58, size))
        pelvis.addQuadCurve(to: point(0.50, 0.63, size), control: point(0.39, 0.61, size))
        pelvis.addQuadCurve(to: point(0.71, 0.58, size), control: point(0.61, 0.61, size))

        var joints = Path()
        let jointLines: [(CGFloat, CGFloat, CGFloat)] = [
            (0.105, 0.195, 0.455), (0.805, 0.895, 0.455),
            (0.315, 0.445, 0.80), (0.555, 0.685, 0.80)
        ]
        for (x1, x2, y) in jointLines {
            joints.move(to: point(x1, y, size))
            joints.addLine(to: point(x2, y, size))
        }

        return [shoulderLine, pelvis, joints]
    }

    private func pairedPolygons(_ left: [(CGFloat, CGFloat)], _ size: CGSize) -> [Path] {
        [polygon(left, size), polygon(mirrored(left), size)]
    }

    private func pairedPolygonGroups(
        _ leftGroups: [[(CGFloat, CGFloat)]],
        _ size: CGSize
    ) -> [Path] {
        leftGroups.flatMap { pairedPolygons($0, size) }
    }

    private func mirrored(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
        points.map { (1 - $0.0, $0.1) }
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    private func polygon(_ points: [(CGFloat, CGFloat)], _ size: CGSize) -> Path {
        var path = Path()
        guard points.count > 2, let first = points.first, let last = points.last else { return path }

        // Muscle groups have soft connective boundaries rather than sharp corners.
        // Drawing quadratic arcs through each control point keeps the normalized
        // anatomy scalable while producing the rounded shapes used by modern
        // training apps.
        path.move(to: midpoint(last, first, size))
        for index in points.indices {
            let current = points[index]
            let next = points[points.index(after: index) == points.endIndex ? points.startIndex : points.index(after: index)]
            path.addQuadCurve(
                to: midpoint(current, next, size),
                control: point(current.0, current.1, size)
            )
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(
        _ first: (CGFloat, CGFloat),
        _ second: (CGFloat, CGFloat),
        _ size: CGSize
    ) -> CGPoint {
        point((first.0 + second.0) / 2, (first.1 + second.1) / 2, size)
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ size: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height))
    }

    private func roundedRect(
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        radius: CGFloat,
        _ size: CGSize
    ) -> Path {
        Path(
            roundedRect: CGRect(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height),
            cornerRadius: radius * min(size.width, size.height)
        )
    }
}
