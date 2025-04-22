//
//  ContentView.swift
//  EUMMEYO-test
//
//  Created by 김동현 on 4/22/25.
//

import SwiftUI


struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isRecording = false
    @State var isStart = false
    var body: some View {
        VStack(spacing: 30) {
            Text("🎧 음성 인식 예제")
                .font(.title)
                .bold()
            
            Text(speechRecognizer.transcribedText)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            
            Button(action: {
                if isRecording {
                    speechRecognizer.stopRecordingAndTranscribe()
                } else {
                    speechRecognizer.startRecording()
                }
                isRecording.toggle()
            }) {
                Text(isRecording ? "녹음 종료 및 텍스트 변환" : "녹음 시작")
                    .padding()
                    .foregroundColor(.white)
                    .background(isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .onAppear {
            speechRecognizer.requestPermissions()
        }
    }
}

#Preview {
    ContentView()
}
