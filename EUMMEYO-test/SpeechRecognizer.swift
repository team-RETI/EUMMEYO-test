//
//  SpeechRecognizer.swift
//  EUMMEYO-test
//
//  Created by eunchanKim on 4/22/25.
//

import Foundation
import AVFoundation
import Speech

class SpeechRecognizer: ObservableObject {
    @Published var transcribedText: String = ""
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition not authorized")
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone permission not granted")
            }
        }
    }
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        self.audioFileURL = fileURL
        
        audioRecorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record()
        
        print("🎙️ 녹음 시작")
    }
    
    func stopRecordingAndTranscribe() {
        audioRecorder?.stop()
        print("🛑 녹음 종료")
        
        guard let url = audioFileURL else { return }
        print("URL : \(url)")
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        recognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    print("📝 변환된 텍스트: \(self.transcribedText)")
                }
            } else if let error = error {
                print("Speech recognition error: \(error.localizedDescription)")
            }
        }
    }

}
