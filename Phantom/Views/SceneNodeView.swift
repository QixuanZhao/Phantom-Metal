//
//  SceneNodeView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/25.
//

import simd
import SwiftUI
import ModelIO
import MetalKit

struct SceneNodeView: View {
    var node: SceneNode
    
    @Environment(Renderer.self) private var renderer
    @Environment(DrawableCollection.self) private var drawables
    @Environment(MaterialCollection.self) private var materials
    
    private var visible: Binding<Bool>
    private var fillTriangles: Binding<Bool>
    private var showAxes: Binding<Bool>
    
    @State private var showInspector = false
    @State private var showDrawableList = false
    
    private var translation: Binding<SIMD3<Float>>
    private var scaling:     Binding<SIMD3<Float>>
    @State private var rotationAAA: SIMD3<Float> // Axis Azimuth, Axis Altitude, Angle
    
    @State private var expanded = false
    
    @State private var hoveringOnEmptyIcon: Bool = false
    
    private var nodeName: Binding<String>
    @State private var drawableName: String?
    @State private var materialName: String?
    
    var currentDrawable: DrawableBase? { drawables[drawableName] }
    var currentMaterial: MaterialWrapper? { materials[materialName] }
    
    @ViewBuilder
    var nodeProperties: some View {
        VectorPicker(value: translation,
                     label: "Translation X Y Z"
        )
        VectorPicker(value: $rotationAAA,
                     boundingBox: (
                        [-Float.pi, -Float.pi/2, -Float.pi],
                        [ Float.pi,  Float.pi/2,  Float.pi]
                     ),
                     integerLength: 3,
                     scale: 180 / Double.pi,
                     label: "Axis Azimuth, Axis Altitude, Rotation Angle"
        ).onChange(of: rotationAAA) {
            let axis = SIMD3<Float>(
                cos(rotationAAA.y) * cos(rotationAAA.x),
                cos(rotationAAA.y) * sin(rotationAAA.x),
                sin(rotationAAA.y)
            )
            node.rotation = simd_quatf(angle: rotationAAA.z, axis: axis)
        }
        VectorPicker(value: scaling,
                     label: "Scaling X Y Z"
        )
    }
    
    var attachButton: some View {
        Button { showDrawableList = true } label: { Image(systemName: "paperclip") }
            .foregroundStyle(node.drawable == nil ? Color.primary : Color.accentColor)
        .popover(isPresented: $showDrawableList) {
            VStack {
//                DrawableList(selected: $drawableName)
                DrawableNameList(selected: $drawableName)
                MaterialNameList(selected: $materialName)
            }.controlSize(.small).frame(height: 300)
        }.simultaneousGesture(
            TapGesture(count: 1).onEnded { showDrawableList = true }
        ).onChange(of: currentDrawable) {
            node.drawable = currentDrawable
        }.onChange(of: currentMaterial) {
            node.material = currentMaterial
        }
    }
    
    var childAppender: some View {
        Image(systemName: hoveringOnEmptyIcon ? "square.dashed" : (node.children.count > 0 ? "square" : "square.dotted"))
            .background {
                if !hoveringOnEmptyIcon {
                    if !node.children.isEmpty { Text("\(node.children.count)").font(.caption).monospaced() } 
                }
                else { Image(systemName: "plus").imageScale(.small) }
            }
            .imageScale(.large)
            .onHover { hoveringOnEmptyIcon = $0 }
            .onTapGesture {
                node.insertChild(SceneNode(name: "New Node"))
            }
    }
    
    var body: some View {
        DisclosureGroup (isExpanded: $expanded) {
            HStack {
                Divider()
                if node.children.count > 0 {
                    Spacer()
                    VStack (alignment: .trailing, spacing: 0) {
                        ForEach(node.children.values.map { $0 }) { child in
                            SceneNodeView(node: child)
                        }
                    }
                } else {
                    childAppender
                    Spacer()
                }
            }
        } label: {
            HStack {
                if let currentDrawable {
                    Text(currentDrawable.name).foregroundStyle(Color.secondary)
                        .font(.footnote)
                } else {
                    LineEditor(text: nodeName, editable: .constant(true))
                    //                    .onChange(of: nodeName) { node.name = nodeName }
                        .textFieldStyle(.roundedBorder)
                }
                Spacer()
                childAppender
                attachButton
                Button { showInspector.toggle() } label: {
                    Image(systemName: "gear")
                }.popover(isPresented: $showInspector) {
                    nodeProperties.padding().frame(width: 300).controlSize(.small)
                }
                ControlGroup {
                    Toggle(isOn: fillTriangles) {
                        Label("Fill Triangles", systemImage: node.fillTriangles ? "triangle.fill" : "triangle")
                    }
                    Toggle(isOn: visible) {
                        Label("Visible", systemImage: node.visible ? "eye.fill" : "eye.slash.fill")
                    }
                    Toggle(isOn: showAxes) {
                        Label("Show Axes", systemImage: "move.3d")
                    }
                }.frame(width: 90).labelStyle(.iconOnly)
            }.buttonStyle(.plain).contextMenu(ContextMenu(menuItems: {
                Button("Zoom") {
                    if let drawable = node.drawable {
                        if drawable is BSplineCurve {
                            let curve = drawable as! BSplineCurve
                            let boundingBox = curve.boundingBox
                            let center = boundingBox.center
                            let length = boundingBox.diagonalLength
                            
                            renderer.camera.position = center - length * renderer.camera.front
                        } else if drawable is BSplineSurface {
                            let surface = drawable as! BSplineSurface
                            let boundingBox = surface.boundingBox
                            let center = boundingBox.center
                            let length = boundingBox.diagonalLength
                            
                            renderer.camera.position = center - length * renderer.camera.front
                        }
                    }
                }.disabled(node.drawable == nil)
                Button("Delete") {
                    node.parent?.removeChild(node)
                }.disabled(node.parent == nil)
                Button("Delete Children") {
                    while node.children.count > 0 {
                        node.removeChild(node.children.keys.first!)
                    }
                }.disabled(node.children.count == 0)
            }))
        }.toggleStyle(.button)
    }
    
    init(node: SceneNode) {
        fillTriangles = .init(get: { node.fillTriangles }, set: { node.fillTriangles = $0 })
        showAxes = .init(get: { node.showAxes }, set: { node.showAxes = $0 })
        visible = .init(get: { node.visible }, set: { node.visible =  $0 })
        translation = .init(get: { node.translation }, set: { node.translation = $0 })
        scaling = .init(get: { node.scaling }, set: { node.scaling = $0 })
        let angle = node.rotation.angle
        
        let axis = if angle == 0.0 {
            SIMD3<Float>(0, 0, 1)
        } else { node.rotation.axis }
        
        let altitude = asin(axis.z)
        let cosAzimuth = axis.x / cos(altitude)
        let sinAzimuth = axis.y / cos(altitude)
        let azimuth = if sinAzimuth > 0 {
            acos(cosAzimuth)
        } else if cosAzimuth > 0 {
            asin(sinAzimuth)
        } else {
            -Float.pi - asin(sinAzimuth)
        }
        
        _rotationAAA = State(initialValue: [azimuth, altitude, angle])
        nodeName = .init(get: { node.name }, set: { node.name = $0 })
        _drawableName = State(initialValue: node.drawable?.name)
        
        self.node = node
    }
}

#Preview {
    let node = SceneNode(name: "Whatever")
    let child = SceneNode(name: "You")
    let grandchild = SceneNode(name: "Like")
    node.showAxes = true
    node.insertChild(child)
    child.insertChild(grandchild)
    return ScrollView {
        SceneNodeView(node: node)
        VStack {
//            DrawableList(selected: .constant(nil))
            DrawableNameList(selected: .constant(nil))
            MaterialNameList(selected: .constant(nil))
        }.frame(height: 300)
    }.controlSize(.small)
        .environment(Renderer())
        .environment(DrawableCollection())
        .environment(MaterialCollection())
}
