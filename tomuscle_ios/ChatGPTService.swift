//
//  ChatGPTService.swift
//  tomuscle_ios
//
//  Created by a on 9/7/25.
//

import Foundation

// MARK: - ChatGPT API Models
struct ChatGPTRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatGPTResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: ChatMessage
    }
}

// MARK: - ChatGPT Service
class ChatGPTService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generateEncouragement() async throws -> String {
        let prompt = "魔法少女のように上体おこしを応援してください"

        let request = ChatGPTRequest(
            model: "gpt-3.5-turbo",
            messages: [
                ChatMessage(role: "user", content: prompt)
            ],
            maxTokens: 150,
            temperature: 0.8
        )

        guard let url = URL(string: baseURL) else {
            throw ChatGPTError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatGPTError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw ChatGPTError.httpError(httpResponse.statusCode)
            }

            let chatResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)

            guard let firstChoice = chatResponse.choices.first else {
                throw ChatGPTError.noResponse
            }

            return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch let error as ChatGPTError {
            throw error
        } catch {
            throw ChatGPTError.networkError(error)
        }
    }
}

// MARK: - Error Types
enum ChatGPTError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .httpError(let code):
            return "HTTPエラー: \(code)"
        case .noResponse:
            return "レスポンスがありません"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        }
    }
}
