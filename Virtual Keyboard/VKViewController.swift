//
//  VKViewController.swift
//  Virtual Keyboard
//
//  Created by Zezhou Li on 12/14/16.
//  Copyright © 2016 Zezhou Li. All rights reserved.
//

import UIKit


class VKViewController: UIViewController {
    
    private struct DataStruct {
        var Frequency: [Float]
        var Magnitude: [Float]
        
        init(_ length: Int) {
            Frequency = [Float](repeating: 0.0, count: length)
            Magnitude = [Float](repeating: 0.0, count: length)
        }
        
    }
    
    private var audioInput: VKAudioController!
    private var svm: VKSVM!
    private var XArray = [[Float]]()
    private var YArray = [Float]()
    private var classNum: Float = -1.0
    private var count = 0
    private var TempBuffer = [[Float]]()
    
    @IBOutlet weak var Label: UILabel!
    
    @IBAction func StartPlaying(_ sender: UIButton) {
        audioInput.playButtonPressedSound()
        audioInput.startRecording()
    }
    
    @IBAction func StopPlaying(_ sender: UIButton) {
        audioInput.stopRecording()
        audioInput.stopButtonPressedSound()
        ExtractInstances()
        svm.finalSamples.removeAll()
    }
    
    private func splitData(_ sampledata: [Float]) -> DataStruct {
        var datastruct = DataStruct(sampledata.count/2)
        var j = 0
        var i = 0
        while i < sampledata.count {
            j = i/2
            datastruct.Frequency[j] = sampledata[i]
            i += 1
            datastruct.Magnitude[j] = sampledata[i]
            i += 1
        }
        return datastruct
    }
    
    private func findAttrNumber(_ sampledata: [Float]) -> Int {
        var num: Int = 0
        while num < sampledata.count {
            num += 1
            if sampledata[num] == sampledata[0] && num > 8 {
                return num
            }
        }
        return 0
    }
    
    private func RemoveZeroInstance( _ AttrNum: Int) {
        var i = 0
        while i < XArray.count {
            if XArray[i].max() == 0.0 {
                XArray.remove(at: i)
                continue
            }
            i += 1
        }
    }
    
    private func ExtractInstances() {
        let sampleDataStruct: DataStruct = splitData(svm.finalSamples)
        let attrNum: Int = findAttrNumber(sampleDataStruct.Frequency)
        let instanceNum: Int = sampleDataStruct.Magnitude.count / attrNum
        
        XArray = [[Float]](repeating: [Float](repeating: 0.0, count: attrNum), count: instanceNum)
        var i = 0
        var j = 0
        for k in 0..<sampleDataStruct.Magnitude.count {
            XArray[i][j] = sampleDataStruct.Magnitude[k]
            j += 1
            if j == attrNum {
                j = 0
                i += 1
                if i == instanceNum {
                    break
                }
            }
        }
        RemoveZeroInstance(attrNum)
        Label.text = "\(XArray.count)"
        print(XArray)
        
    }
    
//    private func readFile(_ name: String, _ isXArray: Bool) {
//        
//        do {
//            let url = URL(fileURLWithPath: Bundle.main.path(forResource: name, ofType: "txt")!)
//            let content = try String(contentsOf: url, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
//            let newContent = content.replacingOccurrences(of: "\n", with: ",").components(separatedBy: ",")
//            if isXArray {
//                XArray = [[Float]](repeating: [Float](repeating: 0.0, count: 2), count: newContent.count/2)
//                for i in 0..<newContent.count/2 {
//                    XArray[i][0] = ((newContent[2*i] as NSString).floatValue)
//                    XArray[i][1] = ((newContent[2*i+1] as NSString).floatValue)
//                }
//            } else {
//                YArray = [Float](repeating: 0.0, count: newContent.count)
//                for i in 0..<newContent.count {
//                    if newContent[i]=="1" {
//                        YArray[i] = ((newContent[i] as NSString).floatValue)
//                    } else {
//                        YArray[i] = ((newContent[i] as NSString).floatValue-1.0)
//                    }
//                    
//                }
//            }
//        } catch {
//            print("Error")
//        }
//    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        svm = VKSVM()
        
        let audioInputCallback: VKAudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            self.gotSomeAudio(timeStamp: Double(timeStamp), numberOfFrames: Int(numberOfFrames), samples: samples)
        }
        audioInput = VKAudioController(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        audioInput.createButtonPressedSound()
        audioInput.startIO()
    }
    
    func gotSomeAudio(timeStamp: Double, numberOfFrames: Int, samples: [Float]) {
        let fft = VKFFT(withSize: numberOfFrames, sampleRate: 44100.0)
        fft.windowType = VKFFTWindowType.hanning
        fft.fftForward(samples)
        fft.calculateLinearBands(minFrequency: 0, maxFrequency: fft.nyquistFrequency, numberOfBands: 1200)
        
        vk_dispatch_main { () -> () in
            self.svm.fft = fft
            self.svm.GetFFTOutput()
        }
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

