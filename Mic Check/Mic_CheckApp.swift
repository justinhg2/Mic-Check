//
//  Mic_CheckApp.swift
//  Mic Check
//
//  Created by Justin Greenberg on 10/1/25.
//

import SwiftUI

@main
struct Mic_CheckApp: App {
    @State private var inputVolume: Double = 0.5
   
    private var micIcon: String {
        if inputVolume < 0.001 {
            return "mic.slash.fill"
        } else {
            return "mic.fill"
        }
    }
    
    var body: some Scene {
        MenuBarExtra("Mic Check", systemImage: "mic") {
            
            HStack {
                
                Image(systemName: micIcon)
                    .accessibilityLabel("Input volume")
                    .imageScale(.medium)
                
                Spacer()
                
                Slider(value: $inputVolume)
                    .controlSize(.small)
                    .frame(width: 240)
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
