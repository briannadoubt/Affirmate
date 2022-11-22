//
//  AffirmateLogo.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import SwiftUI

struct AffirmateLogo: View {
    var width: CGFloat = 128
    var height: CGFloat = 128
    var body: some View {
        Image("Affirmate")
            .resizable()
            .frame(width: width, height: height, alignment: .center)
            .background {
                Circle()
                    #if os(macOS)
                    .fill(Color(.windowBackgroundColor).opacity(0.8))
                    #else
                    .fill(.background.opacity(0.8))
                    #if !os(watchOS)
                    .backgroundStyle(.bar)
                    #endif
                    #endif
            }
            .shadow(radius: 1)
    }
}

struct AffirmateLogo_Previews: PreviewProvider {
    static var previews: some View {
        AffirmateLogo()
    }
}
