//
//  AnglePicker.swift
//  Phantom
//
//  Created by Rachel on 2025/8/7.
//

import SwiftUI

infix operator &*

func &* (lhs: CGSize, rhs: CGSize) -> CGSize {
    .init(width: lhs.width * rhs.width, height: lhs.height * rhs.height)
}

func * (lhs: CGFloat, rhs: CGSize) -> CGSize {
    .init(width: lhs * rhs.width, height: lhs * rhs.height)
}

func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
    rhs * lhs
}

func + (lhs: CGFloat, rhs: CGSize) -> CGSize {
    .init(width: lhs + rhs.width, height: lhs + rhs.height)
}

func + (lhs: CGSize, rhs: CGFloat) -> CGSize {
    rhs + lhs
}

func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    .init(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

func - (lhs: CGFloat, rhs: CGSize) -> CGSize {
    .init(width: lhs - rhs.width, height: lhs - rhs.height)
}

func - (lhs: CGSize, rhs: CGFloat) -> CGSize {
    rhs - lhs
}

func - (lhs: CGSize, rhs: CGSize) -> CGSize {
    .init(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
}

struct AnglePicker: View {
    @Binding var angle: Angle
    
    let title: String
    
    init(angle: Binding<Angle>, title: String) {
        _angle = angle
        self.title = title
    }
    
    private var unitCoordinates: CGSize {
        .init(width: cos(angle.radians), height: -sin(angle.radians))
    }
    
    var body: some View {
        GeometryReader { proxy in
            let sideLength = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
            
            ZStack {
                Circle()
                    .fill(Color.secondary)
                
                Path { path in
                    path.move(to: center)
                    path.addLine(to: .init(x: center.x + sideLength / 2 * unitCoordinates.width, y: center.y + sideLength / 2 * unitCoordinates.height))
                }
                .stroke(Color.white, lineWidth: sideLength * 0.01)
                .stroke(Color.accentColor)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 0.05 * proxy.size.width, height: 0.05 * proxy.size.height)
                
                Circle()
                    .inset(by: sideLength * 0.02)
                    .stroke(Color.white, lineWidth: sideLength * 0.01)
                
                Path { path in
                    path.move(to: .init(x: center.x, y: center.y + sideLength / 2))
                    path.addLine(to: .init(x: center.x, y: center.y - sideLength / 2))
                }
                .stroke(Color.white, lineWidth: sideLength * 0.005)
                
                Path { path in
                    path.move(to: .init(x: center.x + sideLength / 2, y: center.y))
                    path.addLine(to: .init(x: center.x - sideLength / 2, y: center.y))
                }
                .stroke(Color.white, lineWidth: sideLength * 0.005)
                
                Circle()
                    .fill(Color.accentColor)
                    .stroke(Color.white)
                    .offset(unitCoordinates * sideLength * 0.35)
                    .frame(width: 0.05 * proxy.size.width, height: 0.05 * proxy.size.height)
                
                Circle()
                    .fill(Color.clear)
                    .contentShape(.circle)
                    .gesture(
                        DragGesture(minimumDistance: .zero, coordinateSpace: .local)
                            .onChanged { state in
                                let dir = CGSize(
                                    width: state.location.x / sideLength * 2 - 1,
                                    height: -(state.location.y / sideLength * 2 - 1)
                                )
                                angle = .radians(atan2(dir.height, dir.width))
                            }
                    )
            }
        }
    }
}

#Preview {
    @Previewable @State var angle: Angle = .init(degrees: 0)
    
    VStack {
        AnglePicker(
            angle: $angle,
            title: "Azimuth"
        )
        Text("\(angle.degrees) Degrees")
    }
}
