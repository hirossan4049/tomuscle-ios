//
//  ContentView.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
  @State private var sourceItem: PhotosPickerItem?
  @State private var targetItem: PhotosPickerItem?
  @State private var sourceImage: UIImage?
  @State private var targetImage: UIImage?
  @State private var result: UIImage?
  
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        PhotosPicker("入れ替え元を選択", selection: $sourceItem, matching: .images)
        PhotosPicker("入れ替え先を選択", selection: $targetItem, matching: .images)
      }
      .onChange(of: sourceItem) { _ in load(source: true) }
      .onChange(of: targetItem) { _ in load(source: false) }
      
      if let result { Image(uiImage: result).resizable().scaledToFit() }
      else if let targetImage { Image(uiImage: targetImage).resizable().scaledToFit() }
      
      Button("Face Swap 実行") {
        Task { await runFaceSwap() }
      }
      .disabled(sourceImage == nil || targetImage == nil)
    }
    .padding()
  }
  
  private func load(source: Bool) {
    Task {
      do {
        if source, let data = try await sourceItem?.loadTransferable(type: Data.self) {
          sourceImage = UIImage(data: data)
        } else if !source, let data = try await targetItem?.loadTransferable(type: Data.self) {
          targetImage = UIImage(data: data)
        }
      } catch { print(error) }
    }
  }
  
  private func runFaceSwap() async {
    guard let src = sourceImage, let dst = targetImage else { return }
    let engine = FaceSwapEngine()
    print("runFaceSwap")
    await engine.detectPrimaryFace(in: sourceImage!)
    print("Done")
//    if let swapped = await engine.swapFace(source: src, target: dst) {
//      result = swapped
//    }
  }
}


#Preview {
  ContentView()
}
