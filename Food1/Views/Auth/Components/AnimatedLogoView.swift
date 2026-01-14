//
//  AnimatedLogoView.swift
//  Food1
//
//  Prismae logo for authentication and welcome screens.
//  Simple golden double-chevron design.
//

import SwiftUI

struct AnimatedLogoView: View {
    private let goldColor = Color(hex: "D6AC25")

    var body: some View {
        PrismaeLogoShape()
            .fill(goldColor)
            .frame(width: 80, height: 80)
    }
}

#Preview {
    ZStack {
        Color.black
        AnimatedLogoView()
    }
}
