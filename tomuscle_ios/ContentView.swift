//
//  ContentView.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import SwiftUI
import Foundation

struct ContentView: View {
  @State private var prompt: String = ""
  @State private var generatedImageURL: String?
  @State private var generatedImage: UIImage?
  @State private var isGenerating = false
  @State private var errorMessage: String?
  @State private var showCamera = false
  @StateObject private var apiKeyManager = APIKeyManager()
  
  var body: some View {
    NavigationView {
      if let image = generatedImage {
        // 画像生成後のメインビュー
        VStack(spacing: 0) {
          // ヘッダー
          VStack(spacing: 12) {
            Text("生成された画像")
              .font(.title2)
              .fontWeight(.bold)
            
            // コンパクトなテキスト入力
            ZStack(alignment: .topLeading) {
              if prompt.isEmpty {
                Text("新しい画像を生成...")
                  .foregroundColor(.gray)
                  .padding(8)
              }
              
              TextEditor(text: $prompt)
                .frame(height: 44)
                .padding(4)
                .background(Color.clear)
                .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)) { _ in
                  if prompt.contains("\n") {
                    prompt = prompt.replacingOccurrences(of: "\n", with: "")
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                  }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
            )
            
            // 生成ボタン（コンパクト）
            HStack(spacing: 12) {
              Button(action: generateImageAction) {
                HStack {
                  if isGenerating {
                    ProgressView()
                      .scaleEffect(0.7)
                      .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  }
                  Text(isGenerating ? "生成中..." : "再生成")
                    .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(prompt.isEmpty || isGenerating ? Color.gray : Color.blue)
                .cornerRadius(8)
              }
              .disabled(prompt.isEmpty || isGenerating)
              
              Button(action: {
                generatedImage = UIImage(named: "overlay_image")
                generatedImageURL = "sample"
                print("🖼️ サンプル画像を設定")
              }) {
                HStack {
                  Image(systemName: "photo")
                  Text("サンプル")
                }
                .foregroundColor(.orange)
                .frame(height: 40)
                .padding(.horizontal, 16)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
              }
            }
          }
          .padding()
          .background(Color(.systemBackground))
          
          // メイン画像エリア
          ScrollView {
            VStack(spacing: 16) {
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
              
              // アクションボタン群
              VStack(spacing: 12) {
                Button(action: {
                  showCamera = true
                }) {
                  HStack {
                    Image(systemName: "camera.fill")
                    Text("AR体験を開始")
                      .fontWeight(.semibold)
                  }
                  .foregroundColor(.white)
                  .frame(maxWidth: .infinity)
                  .frame(height: 56)
                  .background(
                    LinearGradient(
                      gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                      startPoint: .leading,
                      endPoint: .trailing
                    )
                  )
                  .cornerRadius(12)
                  .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                if let imageURL = generatedImageURL {
                  Button(action: {
                    UIPasteboard.general.string = imageURL
                  }) {
                    HStack {
                      Image(systemName: "doc.on.clipboard")
                      Text("データをコピー")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                  }
                }
                
                Button(action: {
                  // 新しい画像生成画面に戻る
                  generatedImage = nil
                  generatedImageURL = nil
                  prompt = ""
                }) {
                  HStack {
                    Image(systemName: "plus.circle")
                    Text("新しい画像を作成")
                  }
                  .foregroundColor(.secondary)
                  .frame(maxWidth: .infinity)
                  .frame(height: 44)
                  .background(Color(.systemGray6))
                  .cornerRadius(10)
                }
              }
            }
            .padding()
          }
          
          if let errorMessage = errorMessage {
            Text(errorMessage)
              .foregroundColor(.red)
              .padding()
              .background(Color.red.opacity(0.1))
          }
        }
      } else {
        // 初期の画像生成画面
        VStack(spacing: 20) {
          Text("AI画像生成")
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding(.top)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("画像の説明を入力してください")
              .font(.headline)
              .foregroundColor(.primary)
            
            ZStack(alignment: .topLeading) {
              if prompt.isEmpty {
                Text("例：美少女")
                  .foregroundColor(.gray)
                  .padding(8)
              }
              
              TextEditor(text: $prompt)
                .frame(minHeight: 64)
                .padding(4)
                .background(Color.clear)
                .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)) { _ in
                  if prompt.contains("\n") {
                    prompt = prompt.replacingOccurrences(of: "\n", with: "")
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                  }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
            )
          }
          .padding(.horizontal)
          
          VStack(spacing: 12) {
            Text("または、サンプル画像を使用")
              .font(.subheadline)
              .foregroundColor(.secondary)
            
            Button(action: {
              generatedImage = UIImage(named: "overlay_image")
              generatedImageURL = "sample"
              print("🖼️ サンプル画像を設定")
            }) {
              HStack {
                Image(systemName: "photo")
                Text("サンプル画像を使用")
              }
              .foregroundColor(.orange)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .background(Color.orange.opacity(0.1))
              .cornerRadius(8)
            }
          }
          .padding(.horizontal)
          
          Button(action: generateImageAction) {
            HStack {
              if isGenerating {
                ProgressView()
                  .scaleEffect(0.8)
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
              }
              Text(isGenerating ? "生成中..." : "画像を生成")
                .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(prompt.isEmpty || isGenerating ? Color.gray : Color.blue)
            .cornerRadius(10)
          }
          .disabled(prompt.isEmpty || isGenerating)
          .padding(.horizontal)
          
          if let errorMessage = errorMessage {
            Text(errorMessage)
              .foregroundColor(.red)
              .padding(.horizontal)
          }
          
          Spacer()
        }
      }
    }
    .navigationBarHidden(true)
    .fullScreenCover(isPresented: $showCamera) {
      CameraView(selectedImage: generatedImage, isPresented: $showCamera)
    }
  }
  
  private func generateImageAction() {
    Task {
      await generateImage()
    }
  }
  
  @MainActor
  private func generateImage() async {
    print("🎯 UI: 画像生成開始")
    isGenerating = true
    errorMessage = nil
    generatedImageURL = nil
    generatedImage = nil
    
    do {
      print("🔄 UI: generateImage関数を呼び出し中...")
      let imageURL = try await tomuscle_ios.generateImage(prompt: prompt)
      print("🎉 UI: 画像生成完了 - URL: \(imageURL ?? "nil")")
      generatedImageURL = imageURL
      
      if let imageURL = imageURL, imageURL.hasPrefix("data:image/png;base64,") {
        let base64String = String(imageURL.dropFirst("data:image/png;base64,".count))
        if let imageData = Data(base64Encoded: base64String) {
          generatedImage = UIImage(data: imageData)
          print("🖼️ UI: Base64画像をUIImageに変換成功")
        } else {
          print("❌ UI: Base64デコードに失敗")
        }
      }
    } catch {
      print("💥 UI: エラー発生 - \(error)")
      errorMessage = "画像生成に失敗しました: \(error.localizedDescription)"
    }
    
    isGenerating = false
    print("✨ UI: 画像生成処理終了")
  }
}

#Preview {
  ContentView()
}
