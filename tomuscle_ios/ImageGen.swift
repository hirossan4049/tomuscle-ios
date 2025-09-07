//
//  ImageGen.swift
//  tomuscle_ios
//
//  Created by a on 9/7/25.
//

import Foundation

struct ImageResponse: Codable {
  struct DataItem: Codable {
    let url: String?
    let b64_json: String?
  }
  let data: [DataItem]
}

func generateImage(prompt: String) async throws -> String? {
  print("🚀 画像生成開始: \(prompt)")
  
  let url = URL(string: "https://api.openai.com/v1/images/generations")!
  
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.addValue("Bearer \(APIKeyManager().getAPIKey())", forHTTPHeaderField: "Authorization")
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")
  
  let body: [String: Any] = [
    "model": "gpt-image-1",
    "prompt": "\(prompt)(透過,顔のみ)",
    "size": "1024x1024"
  ]
  request.httpBody = try JSONSerialization.data(withJSONObject: body)
  
  print("📡 API リクエスト送信中...")
  
  let (data, response) = try await URLSession.shared.data(for: request)
  
  if let httpResponse = response as? HTTPURLResponse {
    print("📊 HTTP Status Code: \(httpResponse.statusCode)")
  }
  
  print("📦 レスポンスデータサイズ: \(data.count) bytes")
  
  if let responseString = String(data: data, encoding: .utf8) {
    print("📝 レスポンス内容: \(responseString)")
  }
  
  let decoded = try JSONDecoder().decode(ImageResponse.self, from: data)
  
  if let imageUrl = decoded.data.first?.url {
    print("✅ 画像生成成功 (URL): \(imageUrl)")
    return imageUrl
  } else if let b64String = decoded.data.first?.b64_json {
    print("✅ 画像生成成功 (Base64)")
    let dataUrl = "data:image/png;base64,\(b64String)"
    return dataUrl
  } else {
    print("❌ 画像データが取得できませんでした")
    return nil
  }
}
