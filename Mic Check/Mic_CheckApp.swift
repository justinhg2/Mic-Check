//
//  Mic_CheckApp.swift
//  Mic Check
//
//  Created by Justin Greenberg on 10/1/25.
//

import SwiftUI

@main
struct Mic_CheckApp: App {
    @StateObject private var controller: AudioInputController = {
        let c = AudioInputController()
        c.refreshDefaultInputDevice()
        return c
    }()
   
    private var micIcon: String {
        if controller.currentVolume < 0.001 {
            return "mic.slash.fill"
        } else {
            return "mic.fill"
        }
    }
    
    var body: some Scene {
        
        MenuBarExtra {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: micIcon)
                        .accessibilityLabel("Input volume")
                        .imageScale(.medium)

                    Spacer()

                    Slider(value: Binding(
                        get: { controller.currentVolume },
                        set: { newValue in controller.setInputVolume(newValue) }
                    ))
                    .controlSize(.small)
                    .frame(width: 180)
                    .disabled(!controller.isAdjustable)
                }
                .padding()
                .padding(.horizontal)

            }
        } label: {
            Label("Mic Check", systemImage: micIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

