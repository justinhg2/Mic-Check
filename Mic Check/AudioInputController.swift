//
//  AudioInputController.swift
//  Mic Check
//
//  Created by Justin Greenberg on 10/1/25.
//

import Foundation
import Combine
import CoreAudio
import AudioToolbox

final class AudioInputController: ObservableObject {
    // Published state for SwiftUI
    @Published var currentVolume: Double = 0.0
    @Published var isAdjustable: Bool = false
}
