//
//  MaterialList.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/4.
//

import SwiftUI

struct MaterialNameList: View {
    @Environment(MaterialCollection.self) private var materials
    
    @Binding var selected: String?
    
    struct StringWrapper: Identifiable {
        var id: String { name }
        var name: String
    }
    
    var tableData: [StringWrapper] {
        materials.keys.map { StringWrapper(name: $0) }
    }
    
    var body: some View {
        Table(tableData, selection: $selected) {
            TableColumn("Name") { nameWrapper in
                Text(nameWrapper.name)
            }
        }
    }
}

struct MaterialPanel: View {
    @Environment(\.self) private var environment
    @Environment(MaterialCollection.self) private var materials
    let material: MaterialWrapper
    
    @State private var showPopover = false
    @State private var expanded = false
    
    @State private var albedo: Color
    @State private var specularRoughness: SIMD3<Float>
    @State private var refractiveIndices: SIMD3<Float>
    @State private var extinctionCoefficients: SIMD3<Float>
    
    var body: some View {
        DisclosureGroup (isExpanded: $expanded) {
            VStack {
                VectorPicker(value: $specularRoughness,
                             boundingBox: ([0, 0, 0], [1, 1, 1]),
                             label: "Specular, Roughness X Y")
                VectorPicker(value: $refractiveIndices,
                             label: "Refractive Indices for RGB")
                VectorPicker(value: $extinctionCoefficients,
                             label: "Extinction Coefficients for RGB")
            }.controlSize(.small)
        } label: {
            HStack (alignment: .center) {
                Text(material.id)
                Spacer()
                ColorPicker("Albedo", selection: $albedo)
            }.contextMenu {
                Button("Delete") {
                    materials.remove(key: material.id)
                }
            }
        }.onChange(of: specularRoughness.x) {
            material.specular = specularRoughness.x
        }.onChange(of: specularRoughness.y) { material.roughness.x = specularRoughness.y }
        .onChange(of: specularRoughness.z) { material.roughness.y = specularRoughness.z }
        .onChange(of: refractiveIndices) {
            material.refractiveIndices = refractiveIndices
        }.onChange(of: extinctionCoefficients) {
            material.extinctionCoefficients = extinctionCoefficients
        }.onChange(of: albedo) {
            let resolved = albedo.resolve(in: environment)
            material.albedo = SIMD3<Float>(resolved.red, resolved.green, resolved.blue)
        }
    }
    
    init(material: MaterialWrapper) {
        self.material = material
        _albedo = State (initialValue: Color(.displayP3,
                red: Double(material.albedo.x),
                green: Double(material.albedo.y),
                blue: Double(material.albedo.z)
            )
        )
        _specularRoughness = State(initialValue: [material.specular, material.roughness.x, material.roughness.y])
        _refractiveIndices = State(initialValue: material.refractiveIndices)
        _extinctionCoefficients = State(initialValue: material.extinctionCoefficients)
    }
}

struct MaterialList: View {
    @Environment(MaterialCollection.self) private var materials
    
    @State private var showFileLoader = false
    @State private var newMaterialName: String = "Material"
    
    var materialListData: [String] { materials.keys }
    
    var body: some View {
        VStack {
            HStack {
                TextField("Name", text: $newMaterialName).textFieldStyle(.roundedBorder)
                Button {
                    let newMeterial = MaterialWrapper(material: system.defaultMaterial)
                    let uniqueName = materials.uniqueName(name: newMaterialName)
                    newMeterial.id = uniqueName
                    materials.insert(key: uniqueName, value: newMeterial)
                } label: {
                    Image(systemName: "plus")
                }
            }
            ForEach (materialListData, id: \.self) { name in
                MaterialPanel(material: materials[name]!)
            }
        }
    }
}

#Preview {
    let collection = MaterialCollection()
    let material = MaterialWrapper(material: system.defaultMaterial)
    collection.insert(key: material.id, value: material)
    return ScrollView {
        HStack {
            MaterialList().padding()
            MaterialNameList(selected: .constant(nil))
        }
    }.environment(collection)
}
