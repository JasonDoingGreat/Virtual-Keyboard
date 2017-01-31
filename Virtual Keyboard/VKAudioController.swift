//
//  VKAudioController.swift
//  Virtual Keyboard
//
//  Created by Zezhou Li on 12/15/16.
//  Copyright © 2016 Zezhou Li. All rights reserved.
//

// Framework
import AVFoundation


typealias VKAudioInputCallback = (
    _ timeStamp: Double,
    _ numberOfFrames: Int,
    _ samples: [Float]
    ) -> Void

class VKAudioController: NSObject {
    
    private(set) var audioUnit: AudioUnit!
    let audioSession : AVAudioSession = AVAudioSession.sharedInstance()
    var sampleRate: Float
    var numberOfChannels: Int
    
    private let outputBus: UInt32 = 0
    private let inputBus: UInt32 = 1
    private var audioInputCallback: VKAudioInputCallback!
    
    var audioPlayer: AVAudioPlayer?
    
    init(audioInputCallback callback: @escaping VKAudioInputCallback, sampleRate: Float = 44100.0, numberOfChannels: Int = 2) {
        self.sampleRate = sampleRate
        self.numberOfChannels = numberOfChannels
        audioInputCallback = callback
    }
    
    func CheckError(_ error: OSStatus, operation: String) {
        guard error != noErr else {
            return
        }
        
        var result: String = ""
        var char = Int(error.bigEndian)
        
        for _ in 0..<4 {
            guard isprint(Int32(char&255)) == 1 else {
                result = "\(error)"
                break
            }
            result.append(String(describing: UnicodeScalar(char&255)))
            char = char/256
        }
        
        print("Error: \(operation) (\(result))")
        
        exit(1)
    }
    
    private let recordingCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData)
        -> OSStatus in
        
        let audioInput = unsafeBitCast(inRefCon, to: VKAudioController.self)
        var osErr: OSStatus = 0
        
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(audioInput.numberOfChannels),
                mDataByteSize: 4,
                mData: nil))
        
        osErr = AudioUnitRender(audioInput.audioUnit,
                                ioActionFlags,
                                inTimeStamp,
                                inBusNumber,
                                inNumberFrames,
                                &bufferList)
        assert(osErr == noErr, "Audio Unit Render Error \(osErr)")
        
        var monoSamples = [Float]()
        let ptr = bufferList.mBuffers.mData?.assumingMemoryBound(to: Float.self)
        monoSamples.append(contentsOf: UnsafeBufferPointer(start: ptr, count: Int(inNumberFrames)))
        
        audioInput.audioInputCallback(inTimeStamp.pointee.mSampleTime / Double(audioInput.sampleRate),
                                      Int(inNumberFrames),
                                      monoSamples)
        
        return noErr
    }

    // Setup audio session
    private func setupAudioSession() {
        // Configure the audio session
        
        if !audioSession.availableCategories.contains(AVAudioSessionCategoryPlayAndRecord) {
            print("can't record! bailing.")
            return
        }
        
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            
            try audioSession.overrideOutputAudioPort(.speaker)
            
            // Set Session Sample Rate
            try audioSession.setPreferredSampleRate(Double(sampleRate))
            
            // Set Session Buffer Duration
            let bufferDuration: TimeInterval = 0.01
            try audioSession.setPreferredIOBufferDuration(bufferDuration)
            
            audioSession.requestRecordPermission { (granted) -> Void in
                if !granted {
                    print("Record permission denied")
                }
            }

        } catch {
            print("Setup Audio Session Error: \(error)")
        }

    }
    
    // Setup IO unit
    private func setupAudioUnit() {
        // Create a new instance of AURemoteIO
        var desc: AudioComponentDescription = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_Output),
            componentSubType: OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,
            componentFlagsMask: 0)
        
        // Get component
        let inputComponent: AudioComponent! = AudioComponentFindNext(nil, &desc)
        assert(inputComponent != nil, "Couldn't find a default component")
        
        // Create an instance of the AudioUnit
        var tempUnit: AudioUnit?
        CheckError(AudioComponentInstanceNew(inputComponent, &tempUnit), operation: "Could not get component!")
        self.audioUnit = tempUnit
        
        //  Enable input and output on AURemoteIO
        var one: UInt32 = 1
        
        CheckError(AudioUnitSetProperty(audioUnit,
                                        kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Input,
                                        inputBus,
                                        &one,
                                        UInt32(MemoryLayout<UInt32>.size)),
                   operation: "Could not enable input on AURemoteIO")
        
        CheckError(AudioUnitSetProperty(audioUnit,
                                        kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Output,
                                        outputBus,
                                        &one,
                                        UInt32(MemoryLayout<UInt32>.size)),
                   operation: "Could not enable output on AURemoteIO")
        
        // Explicitly set the input and output client formats
        var streamFormatDesc: AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate:        Double(sampleRate),
            mFormatID:          kAudioFormatLinearPCM,
            mFormatFlags:       kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket:    4,
            mFramesPerPacket:   1,
            mBytesPerFrame:     4,
            mChannelsPerFrame:  UInt32(self.numberOfChannels),
            mBitsPerChannel:    4 * 8,
            mReserved: 0
        )
        
        // Set format for input and output busses
        CheckError(AudioUnitSetProperty(audioUnit,
                                        kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Output,
                                        inputBus,
                                        &streamFormatDesc,
                                        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
                   operation: "Couldn't set the input client format on AURemoteIO")
//        CheckError(AudioUnitSetProperty(audioUnit,
//                                        kAudioUnitProperty_StreamFormat,
//                                        kAudioUnitScope_Input,
//                                        outputBus,
//                                        &streamFormatDesc,
//                                        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
//                   operation: "Couldn't set the output client format on AURemoteIO")
        
        // Setup callback on AURemoteIO
        var inputCallbackStruct = AURenderCallbackStruct(
            inputProc: recordingCallback,
            inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        CheckError(AudioUnitSetProperty(audioUnit,
                                        AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                        AudioUnitScope(kAudioUnitScope_Global),
                                        inputBus,
                                        &inputCallbackStruct,
                                        UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                   operation: "couldn't set render callback on AURemoteIO")
        
         CheckError(AudioUnitSetProperty(audioUnit,
                                     AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
                                     AudioUnitScope(kAudioUnitScope_Output),
                                     inputBus,
                                     &one,
                                     UInt32(MemoryLayout<UInt32>.size)),
                    operation: "couldn't allocate buffers")
        
    }
    
    func startIO() {
        do {
            if self.audioUnit == nil {
                setupAudioSession()
                setupAudioUnit()
            }
            
            try self.audioSession.setActive(true)
            CheckError(AudioUnitInitialize(self.audioUnit), operation: "AudioUnit Initialize Error!")
        } catch {
            print("Start Recording error: \(error)")
        }
    }
    
    func startRecording() {
        CheckError(AudioOutputUnitStart(self.audioUnit), operation: "Audio Output Unit Start Error!")
    }
    
    func stopRecording() {
        CheckError(AudioOutputUnitStop(self.audioUnit), operation: "Audio Output Unit Start Error!")
    }
    
    func createButtonPressedSound() {
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: "sound", ofType: "wav")!)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            print("Couldn't create AVAudioPlayer")
            audioPlayer = nil
        }
        audioPlayer?.numberOfLoops = -1
        
    }
    
    func playButtonPressedSound() {
        audioPlayer?.play()
    }
    
    func stopButtonPressedSound() {
        audioPlayer?.stop()
    }
}


