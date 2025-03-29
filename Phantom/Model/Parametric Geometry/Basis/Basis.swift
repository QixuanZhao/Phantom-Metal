//
//  Basis.swift
//  Phantom
//
//  Created by TSAR Weasley on 2025/3/24.
//

import Foundation

protocol PolynomialBasis {
    var degree: Int { get }
}

struct BernsteinPolynomialBasis {
    let degree: Int
}


