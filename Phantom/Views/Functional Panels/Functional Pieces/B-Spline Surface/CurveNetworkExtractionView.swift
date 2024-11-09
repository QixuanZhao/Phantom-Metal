//
//  CurveNetworkExtractionView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/10/19.
//

import SwiftUI
import Charts
import simd

struct CurveNetworkExtractionView: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showPopover = false
    
    @State private var isoV: [Float] = [0, 1]
    @State private var newV: Float = 0
    @State private var uSections: [BSplineCurve]? = nil
    
    @State private var isoU: [Float] = [0, 1]
    @State private var newU: Float = 0
    @State private var vSections: [BSplineCurve]? = nil
    
    @State private var selectedSurfaceName: String? = nil
    
    var surface: BSplineSurface? {
        if let selectedSurfaceName {
            drawables[selectedSurfaceName] as? BSplineSurface
        } else { nil }
    }
    
    struct GuideCurveNode {
        let parameter: SIMD2<Float>
        let attachedIsoline: IsolineAttachment
        let offsetAlongNormal: Float
        
        enum IsolineAttachment {
        case v
        case u
        case both
        case neither
        }
    }
    
    @State private var pointSeries: [GuideCurveNode] = []
    @State private var temporaryPoint: SIMD2<Float>? = nil
    @State private var estimatedPoint: GuideCurveNode? = nil
    
    @State private var parameterCurveSamples: [SIMD2<Float>] = []
    @State private var sampleCount: Int = 50
    
    @State private var needInterpolation = false
    @State private var showParameterCurve: Bool = false
    
    @State private var parameterInterpolationResult: BSplineInterpolator.InterpolationResult? = nil
    @State private var spatialPositionInterpolationResult: BSplineInterpolator.InterpolationResult? = nil
    
    var surfaces: [TableStringItem] {
        drawables.keys.filter { drawables[$0] is BSplineSurface }
            .map { TableStringItem(name: $0) }
    }
    
    var vListView: some View {
        GroupBox {
            HStack {
                TextField("Inner V", value: $newV, format: .number)
                Button {
                    if let index = isoV.firstIndex(where: { newV <= $0 }) {
                        if index != 0 && newV < isoV[index] {
                            isoV.insert(newV, at: index)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            Table(isoV.map { TableStringItem(name: "\($0)") }) {
                TableColumn("#") { Text($0.name).monospacedDigit() }
            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                .copyable([String(data: try! JSONSerialization.data(withJSONObject: isoV), encoding: .utf8)!])
                .pasteDestination(for: String.self,
                    action: { strings in
                    if let string = strings.first {
                        if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                            let parameters = json.map { Float($0) }
                            isoV = parameters
                        }
                    }
                })
        } label: {
            HStack {
                Text("Fixed V")
                Spacer()
                Button {
                    guard let surface else { return }
                    uSections = isoV.map { surface.isocurve(v: $0)! }
                    uSections!.enumerated().forEach { (i, ucurve) in
                        ucurve.name = drawables.uniqueName(name: "U\(i + 1)")
                        drawables.insert(key: ucurve.name, value: ucurve)
                    }
                } label: {
                    Label("Export U Curves", systemImage: "square.and.arrow.up")
                }.disabled(surface == nil)
                    .buttonStyle(.plain)
            }
        }
    }
    
    var uListView: some View {
        GroupBox {
            HStack {
                TextField("Inner U", value: $newU, format: .number)
                Button {
                    if let index = isoU.firstIndex(where: { newU <= $0 }) {
                        if index != 0 && newU < isoU[index] {
                            isoU.insert(newU, at: index)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            Table(isoU.map { TableStringItem(name: "\($0)") }) {
                TableColumn("#") { Text($0.name).monospacedDigit() }
            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                .copyable([String(data: try! JSONSerialization.data(withJSONObject: isoU), encoding: .utf8)!])
                .pasteDestination(for: String.self,
                    action: { strings in
                    if let string = strings.first {
                        if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                            let parameters = json.map { Float($0) }
                            isoU = parameters
                        }
                    }
                })
        } label: {
            HStack {
                Text("Fixed U")
                Spacer()
                Button {
                    guard let surface else { return }
                    vSections = isoU.map { surface.isocurve(u: $0)! }
                    vSections!.enumerated().forEach { (i, vcurve) in
                        vcurve.name = drawables.uniqueName(name: "V\(i + 1)")
                        drawables.insert(key: vcurve.name, value: vcurve)
                    }
                } label: {
                    Label("Export V Curves", systemImage: "square.and.arrow.up")
                }.disabled(surface == nil)
                    .buttonStyle(.plain)
            }
        }
    }
    
    var surfacePicker: some View {
        GroupBox {
            Table(surfaces, selection: $selectedSurfaceName) {
                TableColumn("Name") { Text($0.name) }
            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
        } label: {
            Text("Base Surface")
        }
    }
    
    var extractionChart: some View {
        GroupBox {
            HStack {
                Chart {
                    ForEach (isoU, id: \.self) { u in
                        RuleMark(x: .value("U", u))
                            .foregroundStyle(Color.secondary)
                    }
                    ForEach (isoV, id: \.self) { v in
                        RuleMark(y: .value("V", v))
                            .foregroundStyle(Color.secondary)
                    }
                    
                    ForEach (isoU, id: \.self) { u in
                        ForEach (isoV, id: \.self) { v in
                            PointMark(x: .value("U", u), y: .value("V", v))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    
                    ForEach (pointSeries, id: \.parameter) { point in
                        PointMark(x: .value("U", point.parameter.x),
                                  y: .value("V", point.parameter.y))
                        .foregroundStyle(Color.primary)
                    }
                    
                    if needInterpolation || !showParameterCurve {
                        ForEach (pointSeries, id: \.parameter) { point in
                            LineMark(x: .value("U", point.parameter.x),
                                     y: .value("V", point.parameter.y),
                                     series: .value("Series", 0))
                            .lineStyle(.init(dash: [5, 5]))
                            .foregroundStyle(Color.primary)
                        }
                    }
                    
                    if let estimatedPoint {
                        if needInterpolation || !showParameterCurve {
                            LineMark(x: .value("U", estimatedPoint.parameter.x),
                                     y: .value("V", estimatedPoint.parameter.y),
                                     series: .value("Series", 0))
                            .lineStyle(.init(dash: [5, 5]))
                            .foregroundStyle(Color.primary)
                        }
                        
                        PointMark(x: .value("U", estimatedPoint.parameter.x),
                                  y: .value("V", estimatedPoint.parameter.y))
                        .foregroundStyle(Color.gray.opacity(0.5))
                    }
                    
                    if let temporaryPoint {
                        PointMark(x: .value("U", temporaryPoint.x),
                                  y: .value("V", temporaryPoint.y))
                        .foregroundStyle(Color.gray)
                    }
                    
                    
                    if let temporaryPoint,
                       let estimatedPoint {
                        Plot {
                            LineMark(x: .value("U", temporaryPoint.x),
                                     y: .value("V", temporaryPoint.y),
                                     series: .value("Series", 1))
                            
                            LineMark(x: .value("U", estimatedPoint.parameter.x),
                                     y: .value("V", estimatedPoint.parameter.y),
                                     series: .value("Series", 1))
                        }.foregroundStyle(Color.gray.opacity(0.5))
                        .lineStyle(.init(dash: [2, 2]))
                    }
                    
                    if !needInterpolation,
                       let parameterInterpolationResult {
                        if showParameterCurve {
                            ForEach(parameterCurveSamples, id: \.self) { point in
                                LineMark(x: .value("U", point.x),
                                         y: .value("V", point.y),
                                         series: .value("Series", 2))
                                .foregroundStyle(Color.secondary.opacity(0.6))
                            }
                            ForEach(parameterInterpolationResult.curve.controlPoints, id: \.self) { cp in
                                LineMark(x: .value("U", cp.x),
                                         y: .value("V", cp.y),
                                         series: .value("Series", 3))
                                .lineStyle(.init(dash: [4, 4]))
                                .foregroundStyle(Color.secondary.opacity(0.4))
                            }
                            ForEach(parameterInterpolationResult.curve.controlPoints, id: \.self) { cp in
                                PointMark(x: .value("U", cp.x),
                                          y: .value("V", cp.y))
                                .foregroundStyle(Color.secondary.opacity(0.4))
                            }
                        }
                    }
                    
                }.aspectRatio(1, contentMode: .fit)
                    .frame(minWidth: 500, minHeight: 500)
                    .chartXScale(domain: [0, 1])
                    .chartYScale(domain: [0, 1])
                    .chartXAxis { AxisMarks() }
                    .chartYAxis { AxisMarks() }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onContinuousHover { hovering in
                                    switch hovering {
                                    case .active(let point):
                                        if let plotFrame = proxy.plotFrame {
                                            let origin = geometry[plotFrame].origin
                                            let location = CGPoint(
                                                x: point.x - origin.x,
                                                y: point.y - origin.y
                                            )
                                            
                                            if let uv: (Float, Float) = proxy.value(at: location) {
                                                let point = clamp(SIMD2<Float>(x: uv.0, y: uv.1),
                                                                  min: .zero,
                                                                  max: .one)
                                                temporaryPoint = point
                                                
                                                if isoU.isEmpty || isoV.isEmpty {
                                                    return
                                                }
                                                
                                                let i = isoU.firstIndex(where: { $0 > point.x }) ?? (isoU.endIndex - 1)
                                                let j = isoV.firstIndex(where: { $0 > point.y }) ?? (isoV.endIndex - 1)
                                                let u0 = isoU[i - 1]
                                                let u1 = isoU[i]
                                                
                                                let du0 = point.x - u0
                                                let du1 = u1 - point.x
                                                
                                                let v0 = isoV[j - 1]
                                                let v1 = isoV[j]
                                                
                                                let dv0 = point.y - v0
                                                let dv1 = v1 - point.y
                                                
                                                let sequence = [
                                                    (du0, Alignment.leading, Axis.horizontal),
                                                    (du1, Alignment.trailing, Axis.horizontal),
                                                    (dv0, Alignment.bottom, Axis.vertical),
                                                    (dv1, Alignment.top, Axis.vertical)
                                                ].sorted { $0.0 < $1.0 }
                                                
                                                var position = Alignment.center
                                                
                                                if !NSEvent.modifierFlags.contains(.command) {
                                                    if sequence[0].2 != sequence[1].2 && sequence[1].0 < 0.05 {
                                                        if sequence[0].2 == .horizontal {
                                                            position = Alignment(horizontal: sequence[0].1.horizontal,
                                                                                 vertical: sequence[1].1.vertical)
                                                        } else {
                                                            position = Alignment(horizontal: sequence[1].1.horizontal,
                                                                                 vertical: sequence[0].1.vertical)
                                                        }
                                                    } else {
                                                        position = sequence.first!.1
                                                    }
                                                }
                                                
                                                if position == .leading {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: u0, y: point.y),
                                                                                    attachedIsoline: .v,
                                                                                    offsetAlongNormal: .zero)
                                                } else if position == .trailing {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: u1, y: point.y),
                                                                                    attachedIsoline: .v,
                                                                                    offsetAlongNormal: .zero)
                                                } else if position == .bottom {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: point.x, y: v0),
                                                                                    attachedIsoline: .u,
                                                                                    offsetAlongNormal: .zero)
                                                } else if position == .top {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: point.x, y: v1),
                                                                                    attachedIsoline: .u,
                                                                                    offsetAlongNormal: .zero)
                                                } else if position == .topLeading {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: u0, y: v1),
                                                                                    attachedIsoline: .both,
                                                                                    offsetAlongNormal: .zero)
                                                } else if position == .topTrailing {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: u1, y: v1),
                                                                                    attachedIsoline: .both,
                                                                                    offsetAlongNormal: .zero)
                                                } else if position == .bottomLeading {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: u0, y: v0),
                                                                                    attachedIsoline: .both,
                                                                                    offsetAlongNormal: .zero)
                                                } else if position == .bottomTrailing {
                                                    estimatedPoint = GuideCurveNode(parameter: SIMD2<Float>(x: u1, y: v0),
                                                                                    attachedIsoline: .both,
                                                                                    offsetAlongNormal: .zero)
                                                } else {
                                                    estimatedPoint = GuideCurveNode(parameter: point,
                                                                                    attachedIsoline: .neither,
                                                                                    offsetAlongNormal: .zero)
                                                }
                                            }
                                        }
                                    case .ended:
                                        temporaryPoint = nil
                                        estimatedPoint = nil
                                    }
                                }
                                .onTapGesture {
                                    if let point = estimatedPoint {
                                        pointSeries.append(point)
                                        needInterpolation = true
                                    }
                                    temporaryPoint = nil
                                    estimatedPoint = nil
                                }
                        }
                    }
            }
        } label: { Text("Guide Curve Parameter Pattern") }
    }
    
    var interpolationPanel: some View {
        VStack {
            List (pointSeries.enumerated().map { ($0.offset, $0.element) }, id: \.0) { item in
                HStack {
                    Text("\(item.0) ").monospacedDigit()
                    
                    switch item.1.attachedIsoline {
                    case .neither:
                        TextField("U", value: .init(get: { item.1.parameter.x },
                                                    set: {
                            pointSeries[item.0] = .init(parameter: .init($0, item.1.parameter.y),
                                                        attachedIsoline: item.1.attachedIsoline,
                                                        offsetAlongNormal: item.1.offsetAlongNormal)
                        }), format: .number)
                        .frame(width: 70)
                        
                        TextField("V", value: .init(get: { item.1.parameter.y },
                                                    set: {
                            pointSeries[item.0] = .init(parameter: .init(item.1.parameter.x, $0),
                                                        attachedIsoline: item.1.attachedIsoline,
                                                        offsetAlongNormal: item.1.offsetAlongNormal)
                        }), format: .number)
                        .frame(width: 70)
                        
                        TextField("Offset Along Normal", value: .init(get: {
                            item.1.offsetAlongNormal
                        }, set: {
                            pointSeries[item.0] = .init(parameter: item.1.parameter,
                                                        attachedIsoline: .neither,
                                                        offsetAlongNormal: $0)
                        }), format: .number)
                        .frame(width: 70)
                    case .u:
                        TextField("U", value: .init(get: { item.1.parameter.x },
                                                    set: {
                            pointSeries[item.0] = .init(parameter: .init($0, item.1.parameter.y),
                                                        attachedIsoline: item.1.attachedIsoline,
                                                        offsetAlongNormal: item.1.offsetAlongNormal)
                        }), format: .number)
                        .frame(width: 70)
                        Text("\(item.1.parameter.y)").foregroundStyle(Color.accentColor)
                            .frame(width: 70)
                    case .v:
                        Text("\(item.1.parameter.x)").foregroundStyle(Color.accentColor)
                            .frame(width: 70)
                        TextField("V", value: .init(get: { item.1.parameter.y },
                                                    set: {
                            pointSeries[item.0] = .init(parameter: .init(item.1.parameter.x, $0),
                                                        attachedIsoline: item.1.attachedIsoline,
                                                        offsetAlongNormal: item.1.offsetAlongNormal)
                        }), format: .number)
                        .frame(width: 70)
                    case .both:
                        Text("\(item.1.parameter.x)").foregroundStyle(Color.accentColor)
                            .frame(width: 70)
                        Text("\(item.1.parameter.y)").foregroundStyle(Color.accentColor)
                            .frame(width: 70)
                    }
                    
                    Spacer()
                    
                    if !needInterpolation,
                       let parameterInterpolationResult {
                        Text("\(parameterInterpolationResult.blendParameters[item.0])")
                    }
                    
                    Button {
                        pointSeries.remove(at: item.0)
                        needInterpolation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }.monospacedDigit().buttonStyle(.plain)
                .textFieldStyle(.roundedBorder)
                .controlSize(.mini)
                .foregroundStyle(Color.secondary)
            
            HStack {
                Button {
                    guard let surface else { return }
                    let parameterPoints = pointSeries.map { SIMD3<Float>($0.parameter, 0) }
                    
                    let spatialPoints: [SIMD3<Float>] = pointSeries.map { point in
                        let p = surface.point(at: point.parameter)!
                        if point.offsetAlongNormal > 0
                           && point.attachedIsoline == .neither {
                            let du = surface.point(at: point.parameter, derivativeOrder: (1, 0))!
                            let dv = surface.point(at: point.parameter, derivativeOrder: (0, 1))!
                            let normal = normalize(cross(du, dv))
                            return p + normal * point.offsetAlongNormal
                        } else { return p }
                    }
                    
                    do {
                        parameterInterpolationResult = try BSplineInterpolator.interpolate(points: parameterPoints)
                        spatialPositionInterpolationResult = try BSplineInterpolator.interpolate(points: spatialPoints,
                                                                                                 parameters: parameterInterpolationResult!.blendParameters)
                    } catch { print(error.localizedDescription) }
                    
                    let sampleCount = 500
                    parameterCurveSamples = (0..<sampleCount).map { index in
                        let t = Float(index) / Float(sampleCount - 1)
                        let point = parameterInterpolationResult!.curve.point(at: t)!
                        return SIMD2<Float>(x: point.x, y: point.y)
                    }
                    
                    needInterpolation = false
                } label: {
                    Label("Interpolate", systemImage: "scribble")
                }.disabled(surface == nil)
                Spacer()
                Stepper("Sample Count: \(sampleCount)", value: $sampleCount, in: 0...1000, step: 10)
            }
            
            if !needInterpolation,
               let _ = parameterInterpolationResult {
                HStack {
                    Text("Parameter Curve")
                    Toggle(isOn: $showParameterCurve) {
                        Label("Show", systemImage: showParameterCurve ? "eye.fill" : "eye.slash.fill")
                    }.toggleStyle(.button).labelStyle(.iconOnly)
                    Spacer()
                }
            }
            
            if !needInterpolation,
               let spatialPositionInterpolationResult {
                HStack {
                    Text("Spatial Curve")
                    Spacer()
                    Button {
                        spatialPositionInterpolationResult.curve.name = drawables.uniqueName(name: "Guide Curve")
                        drawables.insert(key: spatialPositionInterpolationResult.curve.name,
                                         value: spatialPositionInterpolationResult.curve)
                    } label: { Label("Export", systemImage: "square.and.arrow.up") }
                }
            }
            
            if !needInterpolation,
               let parameterInterpolationResult {
                HStack {
                    Text("P Curve")
                    Spacer()
                    Button {
                        parameterInterpolationResult.curve.name = drawables.uniqueName(name: "Guide P Curve")
                        drawables.insert(key: parameterInterpolationResult.curve.name,
                                         value: parameterInterpolationResult.curve)
                    } label: { Label("Export", systemImage: "square.and.arrow.up") }
                }
            }
            
            if !needInterpolation,
               let spatialPositionInterpolationResult,
               let parameterInterpolationResult {
                HStack {
                    VStack {
                        Button {
                            guard let surface else { return }
                            
                            if uSections == nil {
                                uSections = isoV.map { surface.isocurve(v: $0)! }
                            }
                            
                            if vSections == nil {
                                vSections = isoU.map { surface.isocurve(u: $0)! }
                            }
                            
                            var samplePoints: [(SIMD2<Float>, SIMD3<Float>)] = []
                            for i in 0..<isoV.count {
                                let v = isoV[i]
                                let uSection = uSections![i]
                                for k in 0..<sampleCount {
                                    let u = Float(k) / Float(sampleCount - 1)
                                    samplePoints.append(([u, v], uSection.point(at: u)!))
                                }
                            }
                            
                            for i in 0..<isoU.count {
                                let u = isoU[i]
                                let vSection = vSections![i]
                                for k in 0..<sampleCount {
                                    let v = Float(k) / Float(sampleCount - 1)
                                    samplePoints.append(([u, v], vSection.point(at: v)!))
                                }
                            }
                            
                            let guideCurve = spatialPositionInterpolationResult.curve
                            let pCurve = parameterInterpolationResult.curve
                            
                            for k in 0..<sampleCount {
                                let t = Float(k) / Float(sampleCount - 1)
                                let param = pCurve.point(at: t)!
                                let uv: SIMD2<Float> = [param.x, param.y]
                                let point = guideCurve.point(at: t)!
                                samplePoints.append((uv, point))
                            }
                            
                            let ps1 = PointSet(points: samplePoints.map { $0.1 })
                            ps1.name = drawables.uniqueName(name: "Points s")
                            drawables.insert(key: ps1.name, value: ps1)
                            
                            let ps2 = PointSet(points: samplePoints.map { SIMD3<Float>($0.0, 0) })
                            ps2.name = drawables.uniqueName(name: "Points uv")
                            drawables.insert(key: ps2.name, value: ps2)
                        } label: {
                            Label("Sample All", systemImage: "hand.point.up.left")
                        }.disabled(surface == nil)
                        
                        Button {
                            var samplePoints: [(SIMD2<Float>, SIMD3<Float>)] = []
                            
                            let guideCurve = spatialPositionInterpolationResult.curve
                            let pCurve = parameterInterpolationResult.curve
                            
                            for k in 0..<sampleCount {
                                let t = Float(k) / Float(sampleCount - 1)
                                let param = pCurve.point(at: t)!
                                let uv: SIMD2<Float> = [param.x, param.y]
                                let point = guideCurve.point(at: t)!
                                samplePoints.append((uv, point))
                            }
                            
                            let ps1 = PointSet(points: samplePoints.map { $0.1 })
                            ps1.name = drawables.uniqueName(name: "Points guide")
                            drawables.insert(key: ps1.name, value: ps1)
                            
                            let ps2 = PointSet(points: samplePoints.map { SIMD3<Float>($0.0, 0) })
                            ps2.name = drawables.uniqueName(name: "Points uv guide")
                            drawables.insert(key: ps2.name, value: ps2)
                            
                        } label: {
                            Label("Sample Guide", systemImage: "hand.point.up.left")
                        }.disabled(surface == nil)
                    }
                    TextField("Count", value: $sampleCount, format: .number)
                }
            }
        }
    }
    
    var panel: some View {
        VStack {
            HStack {
                uListView
                vListView
                surfacePicker
            }.frame(minWidth: 1000)
            HStack {
                extractionChart
                interpolationPanel
            }.frame(minWidth: 1000)
        }.padding()
    }
    
    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Label("Extract", systemImage: "scribble")
        }.popover(isPresented: $showPopover) {
            panel.textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    drawables.insert(key: "What", value: PointSet(points: [.zero]))
    drawables.insert(key: "Ever", value: PointSet(points: [.zero]))
    drawables.insert(key: "You", value: PointSet(points: [.zero]))
    
    return CurveNetworkExtractionView().padding()
        .environment(drawables)
}
