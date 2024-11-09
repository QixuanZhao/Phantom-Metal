//
//  LowGordonSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/27.
//

import simd
import SwiftUI
import Charts

struct LowGordonSurfaceConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor: Bool = false
    
    @State private var pickedUSections: [String] = []
    @State private var pickedGuideCurves: [String] = []
    
    @State private var restCurves: [String] = []
    
    @State private var guideTimes: Int = 1
    @State private var loftedSurface: BSplineSurface? = nil
    @State private var needRegenerateLoftedSurafce = false
    
    @State private var generatedVSections: [BSplineCurve] = []
    @State private var generatedVSectionsDegree: Int = 3
    @State private var needRegenerateVSections = false
    @State private var canExport = false
    
    @State private var selectedUCurveName: String? = nil
    @State private var selectedVCurveName: String? = nil
    @State private var selectedGuideCurveName: String? = nil
    @State private var selectedCurveName: String? = nil
    
    @State private var vIsoCurveParameters: [Float] = [0, 1]
    @State private var newParameter: Float = 0
    
    @State private var uIsoCurveParameters: [Float] = []
    @State private var needRefreshV = true
    
    @State private var intersections: [[SIMD3<Float>]] = []
    @State private var needRefreshIntersections = false
    
    @State private var sampleCount: Int = 50
    
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
    
    @State private var spatialPosition: [SIMD3<Float>] = []
    @State private var pointSeriesParameters: [Float] = []
    @State private var needInterpolation = false
    
    @State private var parameterInterpolationResult: BSplineInterpolator.InterpolationResult? = nil
    @State private var spatialPositionInterpolationResult: BSplineInterpolator.InterpolationResult? = nil
    
    @State private var parameterCurveSamples: [SIMD2<Float>] = []
    @State private var showParameterCurve: Bool = false
    
    var uSections: [TableStringItem] {
        pickedUSections.map { TableStringItem(name: $0) }
    }
    
    var vSections: [TableStringItem] {
        generatedVSections.map { TableStringItem(name: $0.name) }
    }
    
    var guides: [TableStringItem] {
        pickedGuideCurves.map { TableStringItem(name: $0) }
    }
    
    var rest: [TableStringItem] {
        restCurves.map { TableStringItem(name: $0) }
    }
    
    @ViewBuilder
    var gordonPanel: some View {
        Grid {
            GridRow {
                GroupBox {
                    if let surface = loftedSurface {
                        VStack {
                            Spacer()
                            Text("Lofted Surface").font(.title)
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Ready")
                                Spacer()
                                Button {
                                    surface.name = drawables.uniqueName(name: "Lofted Surface")
                                    drawables.insert(key: surface.name,
                                                     value: surface)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView("Empty",
                                               systemImage: "questionmark.square.dashed",
                                               description: Text("generate v first"))
                    }
                } label: {
                    Text("Lofting")
                }.frame(minWidth: 200, minHeight: 200)
                
                Button {
                    do {
                        let loftResult = try BSplineInterpolator.loft(sections: pickedUSections.map { drawables[$0]! as! BSplineCurve },
                                                                      parameters: uIsoCurveParameters)
//                        loftResult.surface.name = drawables.uniqueName(name: "Lofted Surface")
                        loftResult.surface.name = "Lofted Surface"
                        loftedSurface = loftResult.surface
                        needRegenerateLoftedSurafce = false
                    } catch {
                        print(error.localizedDescription.endIndex)
                    }
                } label: {
                    Label("", systemImage: "arrowshape.left.fill").labelStyle(.iconOnly)
                }.disabled(!needRegenerateLoftedSurafce)
                
                GroupBox {
                    if needRefreshV {
                        ContentUnavailableView("Obselete",
                                               systemImage: "exclamationmark.arrow.circlepath",
                                               description: Text("refresh required"))
                    } else {
                        List {
                            ForEach(uIsoCurveParameters, id: \.self) { v in
                                HStack {
                                    Text("\(v)")
                                    Gauge(value: v, in: 0...1) {
                                        Text("\(v)")
                                    }.gaugeStyle(.accessoryLinear)
                                }
                            }
                        }.copyable([String(data: try! JSONSerialization.data(withJSONObject: uIsoCurveParameters), encoding: .utf8)!])
                            .monospacedDigit()
                    }
                } label: {
                    HStack {
                        Text("v")
                        Spacer()
                        Button {
                            uIsoCurveParameters = BSplineInterpolator.evaluateParametersByChordLength(for: pickedUSections.map { drawables[$0]! as! BSplineCurve })
                            needRefreshV = false
                            needRegenerateVSections = true
                            needRegenerateLoftedSurafce = true
                        } label: { Label("Refresh", systemImage: "arrow.counterclockwise") }
                            .disabled(pickedUSections.count < 2 || !needRefreshV)
                    }
                }.frame(minWidth: 200, minHeight: 200)
                
                Label("", systemImage: "arrow.left")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                
                GroupBox {
                    Table(uSections, selection: $selectedUCurveName) {
                        TableColumn("Name") { Text($0.name) }
                    }.frame(minHeight: 100)
                        .tableColumnHeaders(.hidden)
                } label: {
                    HStack {
                        Text("u Sections")
                        Spacer()
                        Text("Mind the Order").foregroundStyle(.mint)
                    }
                }.frame(minWidth: 200, minHeight: 200)
                
                VStack {
                    Button {
                        restCurves.append(selectedUCurveName!)
                        pickedUSections.remove(at: pickedUSections.firstIndex(of: selectedUCurveName!)!)
                        selectedUCurveName = nil
                        
                        loftedSurface = nil
                        
                        needRefreshV = true
                        needRefreshIntersections = true
                    } label: {
                        Image(systemName: "arrowshape.right.fill")
                    }.disabled(selectedUCurveName == nil)
                    Button {
                        pickedUSections.append(selectedCurveName!)
                        restCurves.remove(at: restCurves.firstIndex(of: selectedCurveName!)!)
                        selectedCurveName = nil
                        
                        loftedSurface = nil
                        
                        needRefreshV = true
                        needRefreshIntersections = true
                    } label: {
                        Image(systemName: "arrowshape.left.fill")
                    }.disabled(selectedCurveName == nil)
                }
                
                GroupBox("B-Spline Curves") {
                    Table(rest, selection: $selectedCurveName) {
                        TableColumn("Name") { Text($0.name) }
                    }.tableColumnHeaders(.hidden)
                }.frame(minWidth: 200, minHeight: 200)
            }
            
            GridRow {
                Label("", systemImage: "arrow.down")
                    .foregroundStyle(.secondary)
                Label("", systemImage: "arrow.down.backward")
                    .foregroundStyle(.secondary)
                HStack { }
                HStack { }
                Label("", systemImage: "arrow.down")
                    .foregroundStyle(.secondary)
            }.labelStyle(.iconOnly)
            
            GridRow {
                GroupBox {
                    if !needInterpolation && !needRegenerateVSections,
                       let parameterInterpolationResult,
                       let spatialPositionInterpolationResult,
                       let loftedSurface {
                        VStack {
                            Spacer()
                            HStack {
                                Stepper("times", value: $guideTimes, in: 1...100)
                                TextField("times", value: $guideTimes, format: .number)
                            }.textFieldStyle(.roundedBorder)
                            HStack {
                                Spacer()
                                Button {
//                                    let surface = loftedSurface
                                    let curve = spatialPositionInterpolationResult.curve
                                    let pcurve = parameterInterpolationResult.curve
                                    
                                    let U = vIsoCurveParameters
                                    let V = uIsoCurveParameters
                                    
                                    do {
                                        var currentSurface = loftedSurface
                                        for _ in 1...guideTimes {
                                            let result = try BSplineApproximator.guide(originalSurface: currentSurface,
                                                                                       pcurve: pcurve,
                                                                                       targetCurve: curve,
                                                                                       sampleCount: sampleCount,
                                                                                       isoU: U,
                                                                                       isoV: V)
                                            currentSurface = result.modifiedSurface
                                            currentSurface.name = drawables.uniqueName(name: "Modified Surface")
                                            drawables.insert(key: currentSurface.name,
                                                             value: currentSurface)
                                        }
                                    } catch {
                                        print(error.localizedDescription)
                                    }
                                } label: { Label("Guide", systemImage: "lasso") }
                                Spacer()
                            }
                            Spacer()
                        }
                    } else {
                        ContentUnavailableView("Preconditions Unsatified",
                                               systemImage: "exclamationmark.triangle.fill")
                    }
                } label: {
                    Text("Guiding")
                }.frame(minWidth: 200, minHeight: 200)
                
                Label("", systemImage: "arrow.backward")
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                
                GroupBox {
                    List {
                        ForEach(vIsoCurveParameters, id: \.self) { u in
                            HStack {
                                Text("\(u)")
                                Gauge(value: u, in: 0...1) {
                                    Text("\(u)")
                                }.gaugeStyle(.accessoryLinear)
                            }.contextMenu {
                                Button("Delete") {
                                    vIsoCurveParameters.remove(at: vIsoCurveParameters.firstIndex(of: u)!)
                                }
                            }
                        }.monospacedDigit()
                        VStack {
                            HStack {
                                TextField("u",
                                          value: .init(get: { newParameter },
                                                       set: { newParameter = max(min(1, $0), 0) }),
                                          format: .number)
                                    .monospaced()
                                Button {
                                    var changed = true
                                    if let index = vIsoCurveParameters.firstIndex(where: { $0 >= newParameter }) {
                                        if vIsoCurveParameters[index] != newParameter {
                                            vIsoCurveParameters.insert(newParameter, at: index)
                                        } else { changed = false }
                                    } else {
                                        vIsoCurveParameters.append(newParameter)
                                    }
                                    
                                    if changed {
                                        needRegenerateVSections = true
                                    }
                                    
                                    if !needRefreshIntersections {
                                        needRefreshIntersections = changed
                                    }
                                } label: { Label("Add", systemImage: "plus") }
                            }
                            Slider(value: $newParameter, in: 0...1)
                        }
                    }.copyable([String(data: try! JSONSerialization.data(withJSONObject: vIsoCurveParameters), encoding: .utf8)!])
                        .pasteDestination(for: String.self,
                            action: { strings in
                            print(strings.count)
                            if let string = strings.first {
                                print(string)
                                if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                                    let parameters = json.map { Float($0) }
                                    vIsoCurveParameters = parameters
                                }
                            }
                        })
                } label: {
                    Text("u")
                }.frame(minWidth: 200, minHeight: 200)
                
                Label("", systemImage: "arrow.right")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                
                GroupBox {
                    if needRefreshIntersections {
                        ContentUnavailableView("Obselete",
                                               systemImage: "exclamationmark.arrow.circlepath",
                                               description: Text("refresh required"))
                    } else if intersections.flatMap({ $0 }).isEmpty {
                        ContentUnavailableView("Empty",
                                               systemImage: "questionmark.square.dashed",
                                               description: Text("select u curve(s)"))
                    } else {
                        ScrollView ([.horizontal, .vertical]) {
                            Grid (horizontalSpacing: 5, verticalSpacing: 5) {
                                ForEach (intersections, id: \.self) { points in
                                    GridRow {
                                        ForEach (points, id: \.self) { point in
                                            VStack {
                                                Text("\(point.x)")
                                                Text("\(point.y)")
                                                Text("\(point.z)")
                                            }
                                        }
                                    }
                                }
                            }.buttonStyle(.automatic)
                        }.controlSize(.mini)
                    }
                } label: {
                    HStack {
                        Text("Intersections")
                        Spacer()
                        Button {
                            intersections = vIsoCurveParameters.map { u in
                                pickedUSections.map {
                                    (drawables[$0]! as! BSplineCurve).point(at: u)!
                                }
                            }
                            needRefreshIntersections = false
                            needRegenerateVSections = true
                        } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                            .disabled(!needRefreshIntersections)
                    }
                }.frame(minWidth: 200, minHeight: 200)
                
                Button {
                    // interpolate
                    do {
                        generatedVSections = try intersections.map { points in
                            let interpolateionResult = try BSplineInterpolator.interpolate(points: points,
                                                                parameters: uIsoCurveParameters,
                                                                idealDegree: generatedVSectionsDegree)
                            return interpolateionResult.curve
                        }
                        
                        for (index, curve) in generatedVSections.enumerated() {
                            curve.name = "V Section \(index + 1)"
                        }
                        
                        needRegenerateVSections = false
                        needInterpolation = true
                        canExport = true
                    } catch { print(error.localizedDescription) }
                } label: {
                    VStack {
                        Text("v")
                        Label("", systemImage: "arrowshape.right.fill")
                            .labelStyle(.iconOnly)
                    }
                }.disabled(!needRegenerateVSections || needRefreshV || needRefreshIntersections)
                
                GroupBox {
                    if !needRegenerateVSections {
                        Table(vSections, selection: $selectedVCurveName) {
                            TableColumn("Name") { Text($0.name) }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                    } else {
                        ContentUnavailableView("Unavailable",
                                               systemImage: "exclamationmark.transmission",
                                               description: Text("update prerequisites"))
                    }
                } label: {
                    HStack {
                        Text("v Sections")
                        Stepper("Degree: \(generatedVSectionsDegree)",
                                value: $generatedVSectionsDegree,
                                in: 1...16)
                        Spacer()
                        Button {
                            // export
                            generatedVSections.forEach { section in
                                section.name = drawables.uniqueName(name: section.name)
                                drawables.insert(key: section.name, value: section)
                            }
                            canExport = false
                        } label: { Label("Export", systemImage: "square.and.arrow.up") }
                            .disabled(generatedVSections.isEmpty || !canExport)
                    }
                    .labelStyle(.iconOnly)
                }.frame(minWidth: 200)
            }
            
            GridRow {
                Label("", systemImage: "arrow.up")
                    .foregroundStyle(.secondary)
                HStack {}
                HStack {}
                HStack {}
                HStack {}
                HStack {}
                Label("", systemImage: "arrow.down")
                    .foregroundStyle(.secondary)
            }.labelStyle(.iconOnly)
            
            GroupBox {
                HStack {
                    Chart {
                        ForEach (vIsoCurveParameters, id: \.self) { u in
                            RuleMark(x: .value("U", u))
                                .foregroundStyle(Color.secondary)
                        }
                        ForEach (uIsoCurveParameters, id: \.self) { v in
                            RuleMark(y: .value("V", v))
                                .foregroundStyle(Color.secondary)
                        }
                        
                        ForEach (vIsoCurveParameters, id: \.self) { u in
                            ForEach (uIsoCurveParameters, id: \.self) { v in
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
                        .frame(minWidth: 300, minHeight: 300)
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
                                                    
                                                    if vIsoCurveParameters.isEmpty || uIsoCurveParameters.isEmpty {
                                                        return
                                                    }
                                                    
                                                    let i = vIsoCurveParameters.firstIndex(where: { $0 > point.x }) ?? (vIsoCurveParameters.endIndex - 1)
                                                    let j = uIsoCurveParameters.firstIndex(where: { $0 > point.y }) ?? (uIsoCurveParameters.endIndex - 1)
                                                    let u0 = vIsoCurveParameters[i - 1]
                                                    let u1 = vIsoCurveParameters[i]
                                                    
                                                    let du0 = point.x - u0
                                                    let du1 = u1 - point.x
                                                    
                                                    let v0 = uIsoCurveParameters[j - 1]
                                                    let v1 = uIsoCurveParameters[j]
                                                    
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
                    
                    if pointSeries.isEmpty {
                        HStack {
                            Spacer()
                            ContentUnavailableView("No guide curve node selected",
                                                   systemImage: "rectangle.inset.filled.and.cursorarrow",
                                                   description: Text("Click the chart to add node(s)"))
                            Spacer()
                        }
                    } else {
                        VStack {
                            Stepper("Sample Count: \(sampleCount)", value: $sampleCount, in: 0...1000, step: 10)
                            List {
                                ForEach (pointSeries.enumerated().map { ($0.offset, $0.element) }, id: \.0) { item in
                                    HStack {
                                        Text("\(item.0) ").monospacedDigit()
                                        Text("\(item.1.parameter.x)")
                                            .foregroundStyle((item.1.attachedIsoline == .both || item.1.attachedIsoline == .v) ? Color.accentColor : Color.primary)
                                        Text("\(item.1.parameter.y)")
                                            .foregroundStyle((item.1.attachedIsoline == .both || item.1.attachedIsoline == .u) ? Color.accentColor : Color.primary)

                                        Spacer()
                                        
                                        if item.1.attachedIsoline == .neither {
                                            TextField("Offset Along Normal", value: .init(get: {
                                                item.1.offsetAlongNormal
                                            }, set: {
                                                pointSeries[item.0] = .init(parameter: item.1.parameter,
                                                                            attachedIsoline: .neither,
                                                                            offsetAlongNormal: $0)
                                            }), format: .number)
                                            .textFieldStyle(.roundedBorder)
                                        }
                                        
                                        if !needInterpolation,
                                           let parameterInterpolationResult {
                                            Text("\(parameterInterpolationResult.blendParameters[item.0])")
                                        }
                                        Button {
                                            pointSeries.remove(at: item.0)
                                            needInterpolation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }.controlSize(.mini)
                                    }
                                }
                            }.monospacedDigit()
                            
                            Button {
                                // interpolate spatial & parameter domain curves
//                                let pointSeries = pointSeries.filter { $0.attachedIsoline != .neither }
                                let parameterPoints = pointSeries.map { SIMD3<Float>($0.parameter, 0) }
                                do {
                                    let spatialPoints: [SIMD3<Float>] = try pointSeries.map { point in
                                        if let loftedSurface {
                                            let p = loftedSurface.point(at: point.parameter)!
                                            if point.attachedIsoline == .neither {
                                                let du = loftedSurface.point(at: point.parameter, derivativeOrder: (1, 0))!
                                                let dv = loftedSurface.point(at: point.parameter, derivativeOrder: (0, 1))!
                                                let normal = normalize(cross(du, dv))
                                                return p + normal * point.offsetAlongNormal
                                            } else {
                                                return p
                                            }
                                        } else {
                                            throw PhantomError.unknown("loft surface first")
                                        }
                                    }
                                
                                    parameterInterpolationResult = try BSplineInterpolator.interpolate(points: parameterPoints)
                                    spatialPositionInterpolationResult = try BSplineInterpolator.interpolate(points: spatialPoints,
                                                                                                             parameters: parameterInterpolationResult!.blendParameters)
                                    
                                    let sampleCount = 500
                                    parameterCurveSamples = (0..<sampleCount).map { index in
                                        let t = Float(index) / Float(sampleCount - 1)
                                        let point = parameterInterpolationResult!.curve.point(at: t)!
                                        return SIMD2<Float>(x: point.x, y: point.y)
                                    }
                                    
                                    needInterpolation = false
                                } catch {
                                    print(error.localizedDescription)
                                }
                            } label: {
                                Label("Interpolate", systemImage: "scribble")
                            }.disabled(loftedSurface == nil)
                            
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
                                            let U = vIsoCurveParameters
                                            let V = uIsoCurveParameters
                                            
                                            var samplePoints: [(SIMD2<Float>, SIMD3<Float>)] = []
                                            let uSectionCurves = pickedUSections.map { drawables[$0]! as! BSplineCurve }
                                            for i in 0..<V.count {
                                                let v = V[i]
                                                let uSection = uSectionCurves[i]
                                                for k in 0..<sampleCount {
                                                    let u = Float(k) / Float(sampleCount - 1)
                                                    samplePoints.append(([u, v], uSection.point(at: u)!))
                                                }
                                            }
                                            
                                            let vSectionCurves = generatedVSections
                                            for i in 0..<U.count {
                                                let u = U[i]
                                                let vSection = vSectionCurves[i]
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
                                        }
                                        
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
                                        }
                                    }
                                    TextField("Count", value: $sampleCount, format: .number)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
            } label: { Text("Guide Curve Parameter Pattern") }
            
        }.controlSize(.small)
            .buttonStyle(.plain)
    }
    
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("Gordon Surface (\(restCurves.count))", systemImage: "rectangle.split.3x3.fill")
        }.popover(isPresented: $showConstructor) {
            VStack {
                gordonPanel
            }.padding()
        }.onAppear {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedUSections.contains($0) &&
                !pickedGuideCurves.contains($0)
            }
        }.onChange(of: drawables.count) {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedUSections.contains($0) &&
                !pickedGuideCurves.contains($0)
            }
        }
    }
}

#Preview {
    let dc = DrawableCollection()
    let curves = [BSplineCurve(),
                  BSplineCurve(knots: [.init(value: 0, multiplicity: 4),
                                       .init(value: 0.5, multiplicity: 1),
                                       .init(value: 0.7, multiplicity: 3),
                                       .init(value: 1, multiplicity: 4)],
                               controlPoints: [.init(x: -1, y: -1, z: -1, w: 1),
                                               .init(x: -1, y: -1, z:  1, w: 1),
                                               .init(x: -1, y:  1, z: -1, w: 1),
                                               .init(x: -1, y:  1, z:  1, w: 1),
                                               .init(x:  1, y: -1, z: -1, w: 1),
                                               .init(x:  1, y: -1, z:  1, w: 1),
                                               .init(x:  1, y:  1, z: -1, w: 1),
                                               .init(x:  1, y:  1, z:  1, w: 1)],
                               degree: 3),
                  BSplineCurve(),
                  BSplineCurve(),
                  BSplineCurve(),
                  BSplineCurve(),
                  BSplineCurve(),
                  BSplineCurve()]
    for (index, curve) in curves.enumerated() {
        dc.insert(key: "c\(index)", value: curve)
    }
//    dc.insert(key: curve.name, value: curve)
    
    return LowGordonSurfaceConstructor().padding()
        .environment(dc)
}
