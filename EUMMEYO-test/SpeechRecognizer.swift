//
//  SpeechRecognizer.swift
//  EUMMEYO-test
//
//  Created by eunchanKim on 4/22/25.
//

import Foundation
import AVFoundation
import Speech
import Combine

class SpeechRecognizer: ObservableObject {
    
    /// 비동기 스트림을 구독한 뒤 메모리 해제를 관리하기 위한 저장소
    private var cancellables = Set<AnyCancellable>()
    
    /// 음성인식결과
    @Published var transcribedText: String = ""
    
    /// 음성 녹음을위한 객체
    private var audioRecorder: AVAudioRecorder?
    
    /// 녹음 파일을 저장할 임시 URL 경로
    private var audioFileURL: URL?
    
    /// 음성인식 & 마이크 사용 권한 요청
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
    
    /// 녹음 시작
    func startRecording() {
        
        /// 녹음 설정
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        
        /// 녹음 품질 및 샘플링 설정
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        /// 임시 파일 경로에 녹음 파일 저장
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        self.audioFileURL = fileURL
        
        audioRecorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record()
        
        print("🎙️ 녹음 시작")
    }
    
    // MARK: - Evan
    /// 녹음 중지 후 텍스트로 변환 요청 - Speech
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
    
    // MARK: - Index
    /// 녹음 중지 후 텍스트로 변환 요청 - GPT
    func stopRecordingAndTranscribeGPT() {
        audioRecorder?.stop()
        print("🛑 녹음 종료")
        
        guard let url = audioFileURL else { return }
        print("URL : \(url)")

        /// 음성 -> Text
        GPTAPIService.shared.transcribeAudio(url: url)
            .flatMap { transcript in
                print("📝 단순 텍스트: \(transcript)")
                let prompt = GPTAPIService.PROMPT + transcript
                /// Text -> 요약 Text
                return GPTAPIService.shared.sendToGPTAPI(prompt)
            }
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("❌ GPT 변환 에러: \(error)")
                    self.transcribedText = "인식 실패: \(error)"
                }
            } receiveValue: { [weak self] text in
                self?.transcribedText = text
                print("📝 요약된 텍스트 (GPT): \(text)")
            }
            .store(in: &cancellables)
    }
    
}
