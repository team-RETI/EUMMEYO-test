//
//  GPTAPIService.swift
//  EUMMEYO-test
//
//  Created by 김동현 on 4/22/25.
//

import Foundation
import Combine

enum GPTAPIServiceError: Error {
    case error(Error)
    case urlError            /// url 에러
    case networkError(Error) /// 네트워크 에러
    case dataParsingError    /// 데이터 파싱 에러
    case jsonEnodingError    /// 인코딩 에러
    case badStatusError      /// 200...299 벗어난 상태코드 에러
}

final class GPTAPIService {
    
    /// singoeton
    static let shared = GPTAPIService()
    private init() {}
    
    static let API_KEY = Bundle.main.infoDictionary?["GptAPIKey"] as! String
    
    /// 텍스트를 요약해주는 함수
    /// - Parameter prompt: 프롬포트 문자열 입력
    /// - Returns: 요약된 텍스트
    func sendToGPTAPI(_ prompt: String) -> AnyPublisher<String, GPTAPIServiceError> {
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return Fail(error: .urlError).eraseToAnyPublisher()
        }
        
        // header
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(GPTAPIService.API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": prompt]
            ]
        ]
        
        do {
            // 딕셔너리 -> json 직렬화
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            return Fail(error: GPTAPIServiceError.jsonEnodingError).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { GPTAPIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw GPTAPIServiceError.badStatusError
                }
                
                return data
            }
            .mapError {
                if let gptError = $0 as? GPTAPIServiceError {
                    return gptError
                } else {
                    return GPTAPIServiceError.error($0)
                }
            }
            .flatMap { data -> AnyPublisher<String, GPTAPIServiceError> in
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        return Just(content)
                            .setFailureType(to: GPTAPIServiceError.self)
                            .eraseToAnyPublisher()
                    } else {
                        return Fail(error: GPTAPIServiceError.dataParsingError).eraseToAnyPublisher()
                    }
                } catch {
                    return Fail(error: GPTAPIServiceError.dataParsingError).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func transcribeAudio(url: URL) -> AnyPublisher<String, GPTAPIServiceError> {
        print("키: \(Self.API_KEY)")
        guard let audioData = try? Data(contentsOf: url) else {
            return Fail(error: .dataParsingError).eraseToAnyPublisher()
        }
        
        guard let requestURL = URL(string: "https://api.openai.com/v1/audio/transcriptions") else {
            return Fail(error: .urlError).eraseToAnyPublisher()
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Self.API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // multipart body 구성
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("gpt-4o-transcribe\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.append("text\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n")
        
        request.httpBody = body
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { GPTAPIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GPTAPIServiceError.badStatusError
                }
                
                print("📡 상태코드: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    if let errorBody = String(data: data, encoding: .utf8) {
                        print("❗️에러 응답 본문: \(errorBody)")
                    }
                    throw GPTAPIServiceError.badStatusError
                }
                
                guard let text = String(data: data, encoding: .utf8) else {
                    throw GPTAPIServiceError.dataParsingError
                }
                
                return text
            }
            .mapError {
                ($0 as? GPTAPIServiceError) ?? GPTAPIServiceError.error($0)
            }
            .eraseToAnyPublisher()
    }
    
}

// MARK: - Data + Multipart Helper
extension Data {
    
    /// Swift의 Data 타입은 .append(Data)는 되지만 .append(String)은 기본적으로 지원하지 않는다
    /// multipart/form-data를 수동으로 만들고 있기 때문에 문자열을 Data로 바꿔서 붙여줘야 한다
    /// - Parameter string: multipart body
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
