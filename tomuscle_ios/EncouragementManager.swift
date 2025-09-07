////
////  EncouragementManager.swift
////  tomuscle_ios
////
////  Created by a on 9/7/25.
////
//
//import Foundation
//import Combine
//
//// MARK: - Encouragement Manager
//class EncouragementManager: ObservableObject {
//  @Published var isActive = false
//  @Published var lastEncouragementText = ""
//  @Published var nextEncouragementTime: Date?
//  @Published var errorMessage: String?
//  
//  private var timer: Timer?
//  private let chatGPTService: ChatGPTService
//  private let ttsService: TextToSpeechService
//  
//  // ランダムタイマーの設定（秒）
//  private let minInterval: TimeInterval = 1 // 最小30秒
//  private let maxInterval: TimeInterval = 18 // 最大3分
//  
//  init(apiKey: String) {
//    self.chatGPTService = ChatGPTService(apiKey: apiKey)
//    self.ttsService = TextToSpeechService()
//  }
//  
//  // MARK: - Public Methods
//  func startEncouragement() {
//    guard !isActive else { return }
//    
//    isActive = true
//    errorMessage = nil
//    scheduleNextEncouragement()
//    
//    print("応援機能を開始しました")
//  }
//  
//  func stopEncouragement() {
//    guard isActive else { return }
//    
//    isActive = false
//    timer?.invalidate()
//    timer = nil
//    nextEncouragementTime = nil
//    ttsService.stopSpeaking()
//    
//    print("応援機能を停止しました")
//  }
//  
//  func triggerManualEncouragement() {
//    Task {
//      await generateAndSpeakEncouragement()
//    }
//  }
//  
//  // MARK: - Private Methods
//  private func scheduleNextEncouragement() {
//    timer?.invalidate()
//    
//    let randomInterval = TimeInterval.random(in: minInterval...maxInterval)
//    nextEncouragementTime = Date().addingTimeInterval(randomInterval)
//    
//    timer = Timer.scheduledTimer(withTimeInterval: randomInterval, repeats: false) { [weak self] _ in
//      Task {
//        await self?.generateAndSpeakEncouragement()
//      }
//    }
//    
//    print("次の応援まで \(Int(randomInterval)) 秒")
//  }
//  
//  private func generateAndSpeakEncouragement() async {
//    do {
//      let encouragementText = try await chatGPTService.generateEncouragement()
//      
//      await MainActor.run {
//        self.lastEncouragementText = encouragementText
//        self.errorMessage = nil
//        self.ttsService.speak(text: encouragementText)
//        
//        // 次の応援をスケジュール（アクティブな場合のみ）
//        if self.isActive {
//          self.scheduleNextEncouragement()
//        }
//      }
//      
//      print("応援メッセージ: \(encouragementText)")
//      
//    } catch {
//      await MainActor.run {
//        self.errorMessage = error.localizedDescription
//        
//        // エラーが発生した場合も次の応援をスケジュール（アクティブな場合のみ）
//        if self.isActive {
//          // エラー時は少し短い間隔で再試行
//          DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
//            if self.isActive {
//              self.scheduleNextEncouragement()
//            }
//          }
//        }
//      }
//      
//      print("応援メッセージの生成に失敗: \(error)")
//    }
//  }
//  
//  // MARK: - Utility Methods
//  func getTimeUntilNextEncouragement() -> String {
//    guard let nextTime = nextEncouragementTime else {
//      return "未設定"
//    }
//    
//    let timeInterval = nextTime.timeIntervalSinceNow
//    if timeInterval <= 0 {
//      return "まもなく"
//    }
//    
//    let minutes = Int(timeInterval) / 60
//    let seconds = Int(timeInterval) % 60
//    
//    if minutes > 0 {
//      return "\(minutes)分\(seconds)秒"
//    } else {
//      return "\(seconds)秒"
//    }
//  }
//  
//  deinit {
//    timer?.invalidate()
//  }
//}
