//
//  APIKeyManager.swift
//  tomuscle_ios
//
//  Created by a on 9/7/25.
//

import Foundation

// MARK: - API Key Manager
class APIKeyManager: ObservableObject {
    // ここにAPIキーをハードコードしてください
    static let apiKey = "YOUR_API_KEY_HERE"

    @Published var isAPIKeyValid: Bool = true

    init() {
        // APIキーが設定されているかチェック
        isAPIKeyValid = !Self.apiKey.isEmpty && Self.apiKey != "YOUR_API_KEY_HERE"
    }

    func getAPIKey() -> String {
        return Self.apiKey
    }
}
