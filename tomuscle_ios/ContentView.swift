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
      VStack(spacing: 20) {
        Text("AI画像生成")
          .font(.largeTitle)
          .fontWeight(.bold)
          .padding(.top)
        
        VStack(alignment: .leading, spacing: 8) {
          Text("画像の説明を入力してください")
            .font(.headline)
            .foregroundColor(.primary)
          
          TextField("例：美少女", text: $prompt, axis: .vertical)
            .textFieldStyle(.plain)
            .frame(minHeight: 64, alignment: .topLeading)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .onSubmit {
              UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
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
        
        if let image = generatedImage {
          ScrollView {
            VStack {
              Text("生成された画像")
                .font(.headline)
                .padding(.top)
              
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 400)
                .cornerRadius(10)
                .shadow(radius: 5)
              
              VStack(spacing: 12) {
                if let imageURL = generatedImageURL {
                  Button(action: {
                    UIPasteboard.general.string = imageURL
                  }) {
                    HStack {
                      Image(systemName: "doc.on.clipboard")
                      Text("データをコピー")
                    }
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                  }
                }
                
                Button(action: {
                  showCamera = true
                }) {
                  HStack {
                    Image(systemName: "camera")
                    Text("AR体験を開始")
                  }
                  .foregroundColor(.white)
                  .frame(maxWidth: .infinity)
                  .frame(height: 50)
                  .background(Color.green)
                  .cornerRadius(10)
                }
                .padding(.top, 8)
              }
            }
          }
          .padding(.horizontal)
        }
        
        Spacer()
      }
      .navigationBarHidden(true)
    }
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
