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
    
    // Refreshes variables using other functions
    @MainActor
    func refreshDefaultInputDevice() {
        do {
            let id = try fetchDefaultInputDeviceID()
            let volume = try readInputVolume(deviceID: id)
            let adjustable = try isInputVolumeAdjustable(deviceID: id)
            
            self.currentVolume = volume
            self.isAdjustable = adjustable
        } catch {
            self.currentVolume = 0.0
            self.isAdjustable = false
        }
            
    }
    
    // Attempts to find the AudioDeviceID
    private func fetchDefaultInputDeviceID() throws -> AudioDeviceID {
        // Variable to return the deviceID
        var deviceID = AudioDeviceID(bitPattern: 0)
        
        // How may bytes to write into deviceID
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        // Get the property to read
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Which obeject to query, the property, size of buffer, where to write the result
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to read Input Device (OSStatus \(status))"
            ])
        }
        
        return deviceID
    }
    
    private func readInputVolume(deviceID: AudioDeviceID) throws -> Double {
        // Try the main/master element first, then fall back to channel 1
        if let vol = try? readVolumeScalar(deviceID: deviceID, element: kAudioObjectPropertyElementMain) {
            return Double(max(0.0, min(1.0, vol)))
        }
        if let vol = try? readVolumeScalar(deviceID: deviceID, element: 1) {
            return Double(max(0.0, min(1.0, vol)))
        }

        throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudio_ParamError), userInfo: [
            NSLocalizedDescriptionKey: "Input volume not available for this device"
        ])
    }
    
    /// Reads the scalar volume [0.0, 1.0] for a specific element (channel) on the input scope.
    private func readVolumeScalar(deviceID: AudioDeviceID, element: UInt32) throws -> Float32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element
        )

        // Ensure the property exists for this device/element
        var addressHas = address
        guard AudioObjectHasProperty(deviceID, &addressHas) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudio_ParamError), userInfo: [
                NSLocalizedDescriptionKey: "Volume property not present on this input element"
            ])
        }

        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addressRead = address
        let status = AudioObjectGetPropertyData(deviceID, &addressRead, 0, nil, &size, &volume)
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to read input volume (OSStatus \(status))"
            ])
        }

        return volume
    }
    
    private func isInputVolumeAdjustable(deviceID: AudioDeviceID) throws -> Bool {
        if let settable = try? isVolumePropertySettable(deviceID: deviceID, element: kAudioObjectPropertyElementMain) {
            return settable
        }
        if let settable = try? isVolumePropertySettable(deviceID: deviceID, element: 1) {
            return settable
        }
        return false
    }
    
    /// Determines whether the input volume property is settable for a given element (channel).
    private func isVolumePropertySettable(deviceID: AudioDeviceID, element: UInt32) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element
        )

        // Ensure the property exists
        var addressHas = address
        guard AudioObjectHasProperty(deviceID, &addressHas) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudio_ParamError), userInfo: [
                NSLocalizedDescriptionKey: "Volume property not present on this input element"
            ])
        }

        var isSettable: DarwinBoolean = false
        var addressSet = address
        let status = AudioObjectIsPropertySettable(deviceID, &addressSet, &isSettable)
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to query settable status (OSStatus \(status))"
            ])
        }

        return isSettable.boolValue
    }
    
    @MainActor
    func setInputVolume(_ value: Double) {
        // Clamp to [0, 1]
        let clamped = max(0.0, min(1.0, value))

        do {
            let id = try fetchDefaultInputDeviceID()

            // Try main element first, then channel 1
            if (try? isVolumePropertySettable(deviceID: id, element: kAudioObjectPropertyElementMain)) == true {
                try setVolumeScalar(deviceID: id, element: kAudioObjectPropertyElementMain, value: Float32(clamped))
            } else if (try? isVolumePropertySettable(deviceID: id, element: 1)) == true {
                try setVolumeScalar(deviceID: id, element: 1, value: Float32(clamped))
            } else {
                // Not adjustable; just refresh state and return
                try awaitRefresh(id: id)
                return
            }

            // Refresh state after setting
            try awaitRefresh(id: id)
        } catch {
            // If anything fails, try a best-effort refresh and keep going
            do {
                let id = try fetchDefaultInputDeviceID()
                try awaitRefresh(id: id)
            } catch {
                // ignore
            }
        }
    }

    /// Writes the scalar volume [0.0, 1.0] for a specific element (channel) on the input scope.
    private func setVolumeScalar(deviceID: AudioDeviceID, element: UInt32, value: Float32) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element
        )

        // Ensure the property exists
        var addressHas = address
        guard AudioObjectHasProperty(deviceID, &addressHas) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudio_ParamError), userInfo: [
                NSLocalizedDescriptionKey: "Volume property not present on this input element"
            ])
        }

        // Ensure it is settable
        var isSettable: DarwinBoolean = false
        var addressSet = address
        let settableStatus = AudioObjectIsPropertySettable(deviceID, &addressSet, &isSettable)
        guard settableStatus == noErr, isSettable.boolValue else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(settableStatus), userInfo: [
                NSLocalizedDescriptionKey: "Input volume is not settable for this element (OSStatus \(settableStatus))"
            ])
        }

        var v = value
        var size = UInt32(MemoryLayout<Float32>.size)
        var addressWrite = address
        let status = AudioObjectSetPropertyData(deviceID, &addressWrite, 0, nil, size, &v)
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to set input volume (OSStatus \(status))"
            ])
        }
    }

    /// Helper to refresh current state using a known device ID (avoids re-querying ID multiple times).
    @MainActor
    private func awaitRefresh(id: AudioDeviceID) throws {
        let volume = try readInputVolume(deviceID: id)
        let adjustable = try isInputVolumeAdjustable(deviceID: id)
        self.currentVolume = volume
        self.isAdjustable = adjustable
    }
}
