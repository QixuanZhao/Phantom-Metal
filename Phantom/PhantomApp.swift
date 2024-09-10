//
//  PhantomApp.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI

@main
struct PhantomApp: App {
    @State var renderer = Renderer()
    @State var scene = SceneGraph()
    @State var drawables = DrawableCollection()
    @State var textures = TextureCollection()
    @State var materials = MaterialCollection()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(renderer)
        .environment(scene)
        .environment(drawables)
        .environment(textures)
        .environment(materials)
    }
    
    init() {
        // 0.6149 0.5442 0.4642
        
        let aluminum = MaterialWrapper(albedo: [0.91304, 0.91403, 0.91860],
                                       specular: 0.9,
                                       roughness: [0.6, 0.6],
                                       refractiveIndices: [1.1963, 0.94484, 0.66436],
                                       extinctionCoefficents: [7.0855, 6.3386, 5.4659])
        let brass = MaterialWrapper(albedo: [0.86736, 0.77761, 0.48982],
                                    specular: 0.9,
                                    roughness: [0.2, 0.2],
                                    refractiveIndices: [0.45053, 0.53976, 0.95452],
                                    extinctionCoefficents: [3.3886, 2.7087, 1.9141])
        let copper = MaterialWrapper(albedo: [0.88539, 0.70092, 0.51110],
                                     specular: 0.9,
                                     roughness: [0.2, 0.2],
                                     refractiveIndices: [0.35548, 2.7087, 1.2692],
                                     extinctionCoefficents: [3.2511, 2.7087, 2.2880])
        let gold = MaterialWrapper(albedo: [0.92074, 0.75022, 0.38393],
                                   specular: 0.9,
                                   roughness: [0.2, 0.2],
                                   refractiveIndices: [0.21653, 0.45678, 1.2586],
                                   extinctionCoefficents: [3.0736, 2.2787, 1.7523])
        let iron = MaterialWrapper(albedo: [0.52656, 0.51183, 0.49963],
                                   specular: 0.9,
                                   roughness: [0.2, 0.2],
                                   refractiveIndices: [2.8836, 2.9346, 2.6428],
                                   extinctionCoefficents: [3.0464, 2.9266, 2.8030])
        let lead = MaterialWrapper(albedo: [0.62420, 0.62479, 0.63061],
                                   specular: 0.9,
                                   roughness: [0.2, 0.2],
                                   refractiveIndices: [1.9400, 1.8184, 1.5568],
                                   extinctionCoefficents: [3.4649, 3.3826, 3.2126])
        let mercury = MaterialWrapper(albedo: [0.78137, 0.77931, 0.77889],
                                      specular: 0.9,
                                      roughness: [0.2, 0.2],
                                      refractiveIndices: [1.8841, 1.5229, 1.1269],
                                      extinctionCoefficents: [5.1140, 4.6085, 3.9828])
        let platinum = MaterialWrapper(albedo: [0.66792, 0.63976, 0.59708],
                                       specular: 0.9,
                                       roughness: [0.2, 0.2],
                                       refractiveIndices: [2.2679, 2.0695, 1.8774],
                                       extinctionCoefficents: [4.0790, 3.6820, 3.2185])
        let silver = MaterialWrapper(albedo: [0.95844, 0.94846, 0.92797],
                                     specular: 0.9,
                                     roughness: [0.2, 0.2],
                                     refractiveIndices: [0.15408, 0.14438, 0.13616],
                                     extinctionCoefficents: [3.6741, 3.1458, 2.5040])
        let titanium = MaterialWrapper(albedo: [0.60817, 0.57993, 0.54829],
                                       specular: 0.9,
                                       roughness: [0.2, 0.2],
                                       refractiveIndices: [2.6658, 2.5229, 2.3030],
                                       extinctionCoefficents: [3.7116, 3.4077, 3.0796])
        
        aluminum.id = "Aluminum (Al)"
        brass.id = "Brass (Cu-Zn alloy)"
        copper.id = "Copper (Cu)"
        gold.id = "Gold (Au)"
        iron.id = "Iron (Fe)"
        lead.id = "Lead (Pb)"
        mercury.id = "Mercury (Hg)"
        platinum.id = "Platinum (Pt)"
        silver.id = "Silver (Ag)"
        titanium.id = "Titanium (Ti)"
        
        let pmma = MaterialWrapper(albedo: [0.038651, 0.039098, 0.039889],
                                   specular: 0.5,
                                   roughness: [0.2, 0.2],
                                   refractiveIndices: [1.4894, 1.4929, 1.4991],
                                   extinctionCoefficents: [0, 0, 0])
        let pvp = MaterialWrapper(albedo: [0.043366, 0.043926, 0.045065],
                                  specular: 0.5,
                                  roughness: [0.2, 0.2],
                                  refractiveIndices: [1.5260, 1.5303, 1.5390],
                                  extinctionCoefficents: [0.0019495, 0.0023169, 0.0030045])
        let ps = MaterialWrapper(albedo: [0.051762, 0.052796, 0.054659],
                                 specular: 0.5,
                                 roughness: [0.2, 0.2],
                                 refractiveIndices: [1.5890, 1.5966, 1.6103],
                                 extinctionCoefficents: [0, 0, 0])
        let pc = MaterialWrapper(albedo: [0.050815, 0.051894, 0.053843],
                                 specular: 0.5,
                                 roughness: [0.2, 0.2],
                                 refractiveIndices: [1.5820, 1.5900, 1.6043],
                                 extinctionCoefficents: [0, 0, 0])
        let cellulose = MaterialWrapper(albedo: [0.036083, 0.036497, 0.037230],
                                        specular: 0.5,
                                        roughness: [0.2, 0.2],
                                        refractiveIndices: [1.4690, 1.4723, 1.4782],
                                        extinctionCoefficents: [0, 0, 0])
        let nas21 = MaterialWrapper(albedo: [0.049062, 0.049953, 0.051554],
                                    specular: 0.5,
                                    roughness: [0.2, 0.2],
                                    refractiveIndices: [1.5690, 1.5757, 1.5875],
                                    extinctionCoefficents: [0, 0, 0])
        let optorez1330 = MaterialWrapper(albedo: [0.041049, 0.041536, 0.042399],
                                          specular: 0.5,
                                          roughness: [0.2, 0.2],
                                          refractiveIndices: [1.5082, 1.5119, 1.5186],
                                          extinctionCoefficents: [0, 0, 0])
        let zeonexE48R = MaterialWrapper(albedo: [0.043777, 0.044288, 0.045194],
                                         specular: 0.5,
                                         roughness: [0.2, 0.2],
                                         refractiveIndices: [1.5292, 1.5331, 1.5400],
                                         extinctionCoefficents: [0, 0, 0])
        
        pmma.id = "PMMA Poly(methyl methacrylate)"
        pvp.id = "PVP Polyvinylpyrrolidone"
        ps.id = "PS Polystyren"
        pc.id = "PC Polycarbonate"
        cellulose.id = "Cellulose"
        nas21.id = "NAS-21"
        optorez1330.id = "Optorez1330"
        zeonexE48R.id = "ZeonexE48R"
        
        let diamond = MaterialWrapper(albedo: [0.17130, 0.17288, 0.17288],
                                      specular: 0.9,
                                      roughness: [0.2, 0.2],
                                      refractiveIndices: [2.4123, 2.4234, 2.4351],
                                      extinctionCoefficents: [0, 0, 0])
        let germanium = MaterialWrapper(albedo: [0.49939, 0.51839, 0.47336],
                                        specular: 0.9,
                                        roughness: [0.2, 0.2],
                                        refractiveIndices: [5.6151, 5.1080, 4.1097],
                                        extinctionCoefficents: [1.0518, 2.2620, 2.2595])
        let ice = MaterialWrapper(albedo: [0.017904, 0.018133, 0.018499],
                                  specular: 0.5,
                                  roughness: [0.2, 0.2],
                                  refractiveIndices: [1.3090, 1.3112, 1.3148],
                                  extinctionCoefficents: [7.7181e-9, 2.0129e-9, 1.5900e-10])
        let quartz = MaterialWrapper(albedo: [0.034664, 0.034986, 0.035528],
                                     specular: 0.5,
                                     roughness: [0.2, 0.2],
                                     refractiveIndices: [1.4576, 1.4602, 1.4645],
                                     extinctionCoefficents: [0, 0, 0])
        let salt = MaterialWrapper(albedo: [0.045536, 0.046173, 0.047315],
                                   specular: 0.5,
                                   roughness: [0.2, 0.2],
                                   refractiveIndices: [1.5426, 1.5474, 1.5560],
                                   extinctionCoefficents: [0, 0, 0])
        let sapphire = MaterialWrapper(albedo: [0.076801, 0.077393, 0.078393],
                                       specular: 0.5,
                                       roughness: [0.2, 0.2],
                                       refractiveIndices: [1.7667, 1.7708, 1.7777],
                                       extinctionCoefficents: [0, 0, 0])
        let silicon = MaterialWrapper(albedo: [0.35120, 0.36870, 0.40861],
                                      specular: 0.5,
                                      roughness: [0.2, 0.2],
                                      refractiveIndices: [3.9095, 4.0917, 4.5428],
                                      extinctionCoefficents: [0.0021605, 0.0075678, 0.061677])
        
        diamond.id = "Diamond (C)"
        germanium.id = "Germanium (Ge)"
        ice.id = "Ice (H₂O)"
        quartz.id = "Quartz (SiO₂)"
        salt.id = "Salt (NaCl)"
        sapphire.id = "Sapphire (Al₂O₃)"
        silicon.id = "Silicon (Si)"
        
        materials.insert(key: aluminum.id, value: aluminum)
        materials.insert(key: brass.id, value: brass)
        materials.insert(key: copper.id, value: copper)
        materials.insert(key: gold.id, value: gold)
        materials.insert(key: iron.id, value: iron)
        materials.insert(key: lead.id, value: lead)
        materials.insert(key: mercury.id, value: mercury)
        materials.insert(key: platinum.id, value: platinum)
        materials.insert(key: silver.id, value: silver)
        materials.insert(key: titanium.id, value: titanium)
        
        materials.insert(key: pmma.id, value: pmma)
        materials.insert(key: pvp.id, value: pvp)
        materials.insert(key: ps.id, value: ps)
        materials.insert(key: pc.id, value: pc)
        materials.insert(key: cellulose.id, value: cellulose)
        materials.insert(key: nas21.id, value: nas21)
        materials.insert(key: optorez1330.id, value: optorez1330)
        materials.insert(key: zeonexE48R.id, value: zeonexE48R)
        
        materials.insert(key: diamond.id, value: diamond)
        materials.insert(key: germanium.id, value: germanium)
        materials.insert(key: ice.id, value: ice)
        materials.insert(key: quartz.id, value: quartz)
        materials.insert(key: salt.id, value: salt)
        materials.insert(key: sapphire.id, value: sapphire)
        materials.insert(key: silicon.id, value: silicon)
    }
}
