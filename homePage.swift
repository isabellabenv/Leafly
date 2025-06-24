//
//  homePage.swift
//  test
//
//  Created by Isabella Benvenuto on 19/6/2025.
//

import SwiftUI

struct homePage: View {
    var body: some View {
        RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
            .ignoresSafeArea()
    }
}

#Preview {
    homePage()
}
