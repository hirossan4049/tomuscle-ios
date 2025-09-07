//
//  ChatGPTService.swift
//  tomuscle_ios
//
//  Created by a on 9/7/25.
//

import Foundation

class ChatGPTService: ObservableObject {
  @Published var isLoading = false
  
  private let apiKey: String
  private let baseURL = "https://api.openai.com/v1/chat/completions"
  
  init(apiKey: String) {
    self.apiKey = apiKey
  }
  
  func generateEncouragement() async throws -> String {
    isLoading = true
    defer { isLoading = false }
    
    let requestBody: [String: Any] = [
      "model": "gpt-5-mini",
      "messages": [
        ["role": "user", "content": "魔法少女のように上体おこしを応援してください.一言で可愛く"],
      ],
    ]
    
    var request = URLRequest(url: URL(string: baseURL)!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    // 🔹 リクエストログ
    if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
      print("📤 Request Body:\n\(bodyString)")
    }
    print("📡 Sending request to: \(baseURL)")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // 🔹 レスポンスステータス
    if let httpResponse = response as? HTTPURLResponse {
      print("✅ HTTP Status: \(httpResponse.statusCode)")
      print("🔹 Headers: \(httpResponse.allHeaderFields)")
    }
    
    // 🔹 レスポンスボディ（文字化け対策でUTF8に変換）
    if let rawResponse = String(data: data, encoding: .utf8) {
      print("📥 Raw Response:\n\(rawResponse)")
    }
    
    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
       let choices = json["choices"] as? [[String: Any]],
       let message = choices.first?["message"] as? [String: Any],
       let content = message["content"] as? String {
      print("🎯 Parsed Content: \(content)")
      return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    throw NSError(
      domain: "ChatGPT",
      code: 0,
      userInfo: [NSLocalizedDescriptionKey: "レスポンスの取得に失敗しました"]
    )
  }
}
