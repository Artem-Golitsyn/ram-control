import AppKit
import SwiftUI

/// Time runs left to right and the series is anchored on the right: now is the right edge,
/// older samples sit to the left. Height is occupied memory, scaled to the minimum and maximum
/// currently visible. Each sample keeps the color it was given when it was stored.
struct MemoryHistoryChart: View {
    var samples: [MemoryHistorySample]
    var window: TimeInterval
    var now: Date
    var unit: MemoryUnit
    var language: AppLanguage
    var minutes: Int

    @Environment(\.colorScheme) private var colorScheme

    private let chartHeight: CGFloat = 118

    var body: some View {
        let visible = MemoryHistory.visibleSamples(samples, window: window, now: now)
        let red = components(.systemRed)
        let yellow = components(.systemYellow)
        let gray = components(.systemGray)
        let grid = components(.systemGray)
        let usedBytes = visible.map(\.usedBytes)
        let minimum = usedBytes.min() ?? 0
        let maximum = usedBytes.max() ?? 0
        Canvas { context, size in
            let track = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6)
            context.fill(track, with: .color(Color.primary.opacity(0.06)))
            let plot = plotRect(in: size)
            drawVerticalGrid(context: context, plot: plot, grid: grid)
            guard window > 0, !visible.isEmpty else { return }
            drawHorizontalGrid(
                context: context,
                plot: plot,
                minimum: minimum,
                maximum: maximum,
                grid: grid
            )
            let minimumValue = Double(minimum)
            let maximumValue = Double(maximum)
            for run in MemoryHistory.runs(visible) {
                let curve = smoothed(
                    run,
                    plot: plot,
                    minimum: minimumValue,
                    maximum: maximumValue,
                    red: red,
                    yellow: yellow,
                    gray: gray
                )
                guard let only = curve.first else { continue }
                if curve.count == 1 {
                    let dot = CGRect(x: only.point.x - 0.5, y: only.point.y - 0.5, width: 1, height: 1)
                    context.fill(Path(ellipseIn: dot), with: .color(only.color.swiftUI))
                    continue
                }
                var stroke = Path()
                stroke.move(to: only.point)
                for sample in curve.dropFirst() {
                    stroke.addLine(to: sample.point)
                }
                context.stroke(
                    stroke,
                    with: gradient(curve, size: size),
                    style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)
                )
            }
        }
        .frame(height: chartHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.memoryGraphAccessibility(minutes: minutes, language: language))
    }

    private func plotRect(in size: CGSize) -> CGRect {
        let inset: CGFloat = 4
        let labelBand: CGFloat = 14
        return CGRect(
            x: inset,
            y: inset,
            width: max(1, size.width - inset * 2),
            height: max(1, size.height - inset * 2 - labelBand)
        )
    }

    private func drawVerticalGrid(context: GraphicsContext, plot: CGRect, grid: RGB) {
        let style = StrokeStyle(lineWidth: 1, dash: [2, 3])
        let tint = grid.swiftUI.opacity(0.55)
        for age in MemoryHistory.verticalTickAges(window: window) {
            guard let across = MemoryHistory.horizontalPosition(age: age, window: window) else { continue }
            let x = plot.minX + CGFloat(across) * plot.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: plot.minY))
            line.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(line, with: .color(tint), style: style)
            let label = Text(L10n.graphTickLabel(seconds: age, language: language))
                .font(.system(size: 9))
                .foregroundStyle(Color(nsColor: .systemGray))
            let anchor: UnitPoint = across < 0.08 ? .topLeading : .top
            context.draw(label, at: CGPoint(x: x, y: plot.maxY + 1), anchor: anchor)
        }
    }

    private func drawHorizontalGrid(
        context: GraphicsContext,
        plot: CGRect,
        minimum: UInt64,
        maximum: UInt64,
        grid: RGB
    ) {
        let style = StrokeStyle(lineWidth: 1, dash: [2, 3])
        let tint = grid.swiftUI.opacity(0.55)
        if minimum == maximum {
            let y = yPosition(up: 0.5, plot: plot)
            strokeHorizontal(context: context, plot: plot, y: y, tint: tint, style: style)
            drawLevelLabel(ByteFormatter.string(bytes: minimum, unit: unit), y: y, plot: plot, above: true, context: context)
            return
        }
        let maxY = yPosition(up: 1, plot: plot)
        let minY = yPosition(up: 0, plot: plot)
        strokeHorizontal(context: context, plot: plot, y: maxY, tint: tint, style: style)
        strokeHorizontal(context: context, plot: plot, y: minY, tint: tint, style: style)
        drawLevelLabel(
            ByteFormatter.string(bytes: maximum, unit: unit),
            y: maxY,
            plot: plot,
            above: false,
            context: context
        )
        drawLevelLabel(
            ByteFormatter.string(bytes: minimum, unit: unit),
            y: minY,
            plot: plot,
            above: true,
            context: context
        )
    }

    private func strokeHorizontal(
        context: GraphicsContext,
        plot: CGRect,
        y: CGFloat,
        tint: Color,
        style: StrokeStyle
    ) {
        var line = Path()
        line.move(to: CGPoint(x: plot.minX, y: y))
        line.addLine(to: CGPoint(x: plot.maxX, y: y))
        context.stroke(line, with: .color(tint), style: style)
    }

    private func drawLevelLabel(
        _ text: String,
        y: CGFloat,
        plot: CGRect,
        above: Bool,
        context: GraphicsContext
    ) {
        let label = Text(text)
            .font(.system(size: 9))
            .foregroundStyle(Color(nsColor: .systemGray))
        let point = CGPoint(x: plot.minX + 2, y: above ? y - 1 : y + 1)
        context.draw(label, at: point, anchor: above ? .bottomLeading : .topLeading)
    }

    private func yPosition(up: Double, plot: CGRect) -> CGFloat {
        plot.minY + (1 - CGFloat(up)) * plot.height
    }

    private func smoothed(
        _ run: [MemoryHistorySample],
        plot: CGRect,
        minimum: Double,
        maximum: Double,
        red: RGB,
        yellow: RGB,
        gray: RGB
    ) -> [(point: CGPoint, color: RGB)] {
        let knots = run.compactMap { sample -> (point: CGPoint, color: RGB)? in
            let age = now.timeIntervalSince(sample.date)
            guard let across = MemoryHistory.horizontalPosition(age: age, window: window) else { return nil }
            let up = MemoryHistory.verticalPosition(used: Double(sample.usedBytes), minimum: minimum, maximum: maximum)
            let point = CGPoint(
                x: plot.minX + CGFloat(across) * plot.width,
                y: yPosition(up: up, plot: plot)
            )
            return (point, mix(red: red, yellow: yellow, gray: gray, blend: sample.blend))
        }
        guard knots.count >= 3, knots.count < 80 else { return knots }
        var curve: [(point: CGPoint, color: RGB)] = []
        let steps = 8
        for index in 0..<(knots.count - 1) {
            let p0 = knots[max(0, index - 1)].point
            let p1 = knots[index].point
            let p2 = knots[index + 1].point
            let p3 = knots[min(knots.count - 1, index + 2)].point
            let c1 = knots[index].color
            let c2 = knots[index + 1].color
            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                var plotted = catmull(p0, p1, p2, p3, t)
                plotted.x = min(max(plotted.x, min(p1.x, p2.x)), max(p1.x, p2.x))
                plotted.y = min(max(plotted.y, plot.minY), plot.maxY)
                curve.append((plotted, c1.mixed(with: c2, t: t)))
            }
        }
        if let last = knots.last {
            curve.append(last)
        }
        return curve
    }

    private func gradient(
        _ curve: [(point: CGPoint, color: RGB)],
        size: CGSize
    ) -> GraphicsContext.Shading {
        var stops: [Gradient.Stop] = []
        let strideBy = max(1, curve.count / 24)
        var lastLocation = -1.0
        for index in Swift.stride(from: 0, to: curve.count, by: strideBy) {
            let location = min(1, max(0, Double(curve[index].point.x / max(size.width, 1))))
            guard location > lastLocation + 0.000_1 else { continue }
            lastLocation = location
            stops.append(.init(color: curve[index].color.swiftUI, location: location))
        }
        if let last = curve.last {
            let location = min(1, max(0, Double(last.point.x / max(size.width, 1))))
            if location > lastLocation + 0.000_1 {
                stops.append(.init(color: last.color.swiftUI, location: location))
            }
        }
        if stops.isEmpty, let first = curve.first {
            stops.append(.init(color: first.color.swiftUI, location: 0))
        }
        return .linearGradient(
            Gradient(stops: stops),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: size.width, y: 0)
        )
    }

    private func catmull(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * (
                (2 * b)
                    + (-a + c) * CGFloat(t)
                    + (2 * a - 5 * b + 4 * c - d) * CGFloat(t2)
                    + (-a + 3 * b - 3 * c + d) * CGFloat(t3)
            )
        }
        return CGPoint(
            x: axis(p0.x, p1.x, p2.x, p3.x),
            y: axis(p0.y, p1.y, p2.y, p3.y)
        )
    }

    private func mix(red: RGB, yellow: RGB, gray: RGB, blend: MemoryGraphBlend) -> RGB {
        RGB(
            red: blend.red * red.red + blend.yellow * yellow.red + blend.gray * gray.red,
            green: blend.red * red.green + blend.yellow * yellow.green + blend.gray * gray.green,
            blue: blend.red * red.blue + blend.yellow * yellow.blue + blend.gray * gray.blue
        )
    }

    private func components(_ color: NSColor) -> RGB {
        let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        appearance?.performAsCurrentDrawingAppearance {
            let converted = color.usingColorSpace(.sRGB) ?? color
            converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }
        return RGB(red: Double(red), green: Double(green), blue: Double(blue))
    }
}

private struct RGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var swiftUI: Color {
        Color(red: red, green: green, blue: blue)
    }

    func mixed(with other: RGB, t: Double) -> RGB {
        let t = min(1, max(0, t))
        return RGB(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }
}
