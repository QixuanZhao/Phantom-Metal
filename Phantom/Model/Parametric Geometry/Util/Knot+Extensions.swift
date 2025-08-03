//
//  Knot+Extensions.swift
//  Phantom
//
//  Created by Rachel on 2025/8/1.
//

import Foundation

extension BSplineBasis.Knot: CustomStringConvertible {
    var description: String {
        "\(value) (\(multiplicity))"
    }
}
