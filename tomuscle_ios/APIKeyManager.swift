//
//  APIKeyManager.swift
//  tomuscle_ios
//
//  Created by a on 9/7/25.
//

import Foundation

// MARK: - API Key Manager
class APIKeyManager: ObservableObject {
  func getAPIKey() -> String {
    guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
          let dict = NSDictionary(contentsOfFile: path),
          let apiKey = dict["ChatGPTAPIKey"] as? String else {
      return ""
    }
    return apiKey
  }
}
