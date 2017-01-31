//
//  VKViewController.swift
//  Virtual Keyboard
//
//  Created by Zezhou Li on 12/14/16.
//  Copyright © 2016 Zezhou Li. All rights reserved.
//

import UIKit


class VKViewController: UIViewController {
    
    private var audioInput: VKAudioController!
    private var svm: VKSVM!
    private var fft: VKFFT!

    private var totalFrames: Int = 0
    private var audioSamples = [Float]()
    
    private var FFTResult = [[Float]]()
    private var pressedCount: Float = -1.0
    
    @IBOutlet weak var Label: UILabel!
    
    @IBAction func StartPlaying(_ sender: UIButton) {
        audioInput.playButtonPressedSound()
        audioInput.startRecording()
    }
    
    @IBAction func StopPlaying(_ sender: UIButton) {
        audioInput.stopRecording()
        audioInput.stopButtonPressedSound()
        fft = VKFFT(withSize: totalFrames, sampleRate: 44100)
        fft.GetFFTResult(totalFrames, audioSamples)
        FFTResult = fft.ReturnFFTResult()
        let Y = [Float](repeating: pressedCount, count: FFTResult.count)
        svm.SVMTrain(FFTResult, Y, 1.0, "linearKernel", 0.001, 20)
        svm.printModel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        svm = VKSVM()
        fft = VKFFT(withSize: 0, sampleRate: 44100)
        let audioInputCallback: VKAudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            self.gotSomeAudio(timeStamp: Double(timeStamp), numberOfFrames: Int(numberOfFrames), samples: samples)
        }
        audioInput = VKAudioController(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        audioInput.createButtonPressedSound()
        audioInput.startIO()
    }
    
    func gotSomeAudio(timeStamp: Double, numberOfFrames: Int, samples: [Float]) {
        audioSamples.append(contentsOf: samples)
        totalFrames += numberOfFrames
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

