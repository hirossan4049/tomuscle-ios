import AVFoundation

@MainActor
class TextToSpeechService: ObservableObject {
  private let synthesizer = AVSpeechSynthesizer()
  
  func speak(text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
    synthesizer.speak(utterance)
  }
}

// 一旦
func startEncouragementTimer() async {
  Task {
    let ttsService = await TextToSpeechService()
    while !Task.isCancelled {
      do {
        let service = ChatGPTService(apiKey: APIKeyManager().getAPIKey())
        let comment = try await service.generateEncouragement()
        await ttsService.speak(text: comment)
        
        try await Task.sleep(nanoseconds: 10_000_000_000)
      } catch {
        print("エラーが発生しました: \(error)")
        try? await Task.sleep(nanoseconds: 10_000_000_000)
      }
    }
  }
}
