//
//  Vision.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class FaceSwapEngine {
  private let ctx = CIContext()
  
  /// ソース画像の顔をターゲット画像の中心に配置
  func swapFaceToCenter(source: UIImage, target: UIImage) async -> UIImage? {
    // ソース画像から顔を検出
    guard let srcObs = await detectPrimaryFace(in: source) else {
      print("ソース画像から顔が検出できませんでした")
      return nil
    }
    
    // Core Imageへ変換
    guard
      let srcCI = CIImage(image: source),
      let dstCI = CIImage(image: target)
    else { return nil }
    
    // ソース画像の顔領域を切り取り
    let srcFaceRect = denormalizeRect(
      srcObs.boundingBox,
      imageSize: source.size
    )
    
    // 顔部分を切り取り
    let croppedFace = srcCI.cropped(to: srcFaceRect)
    
    // ターゲット画像の中心に配置するための変換を計算
    let targetCenter = CGPoint(
      x: target.size.width / 2,
      y: target.size.height / 2
    )
    
    // 顔のサイズを調整（オプション：ターゲット画像に対して適切なサイズに）
    let scaleFactor = calculateScaleFactor(
      faceSize: srcFaceRect.size,
      targetSize: target.size
    )
    
    // 変換を適用：スケール → 中心へ移動
    var transform = CGAffineTransform.identity
    // まず顔の中心を原点に
    transform = transform.translatedBy(
      x: -srcFaceRect.midX,
      y: -srcFaceRect.midY
    )
    // スケール適用
    transform = transform.scaledBy(x: scaleFactor, y: scaleFactor)
    // ターゲットの中心へ移動
    transform = transform.translatedBy(x: targetCenter.x, y: targetCenter.y)
    
    let transformedFace = croppedFace.transformed(by: transform)
    
    // 円形マスクを作成（顔をより自然にブレンド）
    let maskRadius = min(srcFaceRect.width, srcFaceRect.height) * scaleFactor * 0.5
    let mask = createCircularMask(
      center: targetCenter,
      radius: maskRadius,
      imageSize: target.size,
      feather: 30
    )
    
    // マスクを使ってブレンド
    guard let filter = CIFilter(name: "CIBlendWithMask") else { return nil }
    filter.setValue(transformedFace, forKey: kCIInputImageKey)
    filter.setValue(dstCI, forKey: kCIInputBackgroundImageKey)
    filter.setValue(mask, forKey: kCIInputMaskImageKey)
    
    guard let outputImage = filter.outputImage,
          let cgImage = ctx.createCGImage(outputImage, from: outputImage.extent) else {
      return nil
    }
    
    return UIImage(cgImage: cgImage)
  }
  
  /// 顔の位置を合わせたい場合のメソッド（改良版）
  func swapFaceAligned(source: UIImage, target: UIImage) async -> UIImage? {
    guard
      let srcObs = await detectPrimaryFace(in: source),
      let dstObs = await detectPrimaryFace(in: target)
    else {
      print("顔検出に失敗しました")
      return nil
    }
    
    guard
      let srcCI = CIImage(image: source),
      let dstCI = CIImage(image: target)
    else { return nil }
    
    // 顔の矩形を画像座標に変換
    let srcFaceRect = denormalizeRect(srcObs.boundingBox, imageSize: source.size)
    let dstFaceRect = denormalizeRect(dstObs.boundingBox, imageSize: target.size)
    
    // ソース顔を切り取り
    let croppedFace = srcCI.cropped(to: srcFaceRect)
    
    // スケールファクターを計算（ターゲット顔のサイズに合わせる）
    let scaleX = dstFaceRect.width / srcFaceRect.width
    let scaleY = dstFaceRect.height / srcFaceRect.height
    let scale = (scaleX + scaleY) / 2  // 平均を使用
    
    // 変換：ソース顔の中心 → ターゲット顔の中心
    var transform = CGAffineTransform.identity
    transform = transform.translatedBy(x: -srcFaceRect.midX, y: -srcFaceRect.midY)
    transform = transform.scaledBy(x: scale, y: scale)
    transform = transform.translatedBy(x: dstFaceRect.midX, y: dstFaceRect.midY)
    
    let transformedFace = croppedFace.transformed(by: transform)
    
    // 楕円マスクを作成
    let mask = createEllipticalMask(
      rect: dstFaceRect,
      imageSize: target.size,
      feather: 25
    )
    
    // ブレンド
    guard let filter = CIFilter(name: "CIBlendWithMask") else { return nil }
    filter.setValue(transformedFace, forKey: kCIInputImageKey)
    filter.setValue(dstCI, forKey: kCIInputBackgroundImageKey)
    filter.setValue(mask, forKey: kCIInputMaskImageKey)
    
    guard let outputImage = filter.outputImage,
          let cgImage = ctx.createCGImage(outputImage, from: outputImage.extent) else {
      return nil
    }
    
    return UIImage(cgImage: cgImage)
  }
  
  // MARK: - Helper Methods
  
  /// Vision座標（正規化）を画像ピクセル座標に変換
  private func denormalizeRect(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
    return CGRect(
      x: normalizedRect.origin.x * imageSize.width,
      y: (1 - normalizedRect.origin.y - normalizedRect.height) * imageSize.height,
      width: normalizedRect.width * imageSize.width,
      height: normalizedRect.height * imageSize.height
    )
  }
  
  /// 適切なスケールファクターを計算
  private func calculateScaleFactor(faceSize: CGSize, targetSize: CGSize) -> CGFloat {
    // 顔がターゲット画像の約1/3〜1/2程度のサイズになるように調整
    let targetFaceWidth = targetSize.width * 0.4
    let targetFaceHeight = targetSize.height * 0.4
    
    let scaleX = targetFaceWidth / faceSize.width
    let scaleY = targetFaceHeight / faceSize.height
    
    // アスペクト比を保持するため、小さい方を使用
    return min(scaleX, scaleY)
  }
  
  /// 円形マスクを作成
  private func createCircularMask(center: CGPoint, radius: CGFloat, imageSize: CGSize, feather: CGFloat) -> CIImage {
    guard let filter = CIFilter(name: "CIRadialGradient") else {
      return CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: imageSize))
    }
    
    let innerRadius = max(0, radius - feather)
    let outerRadius = radius + feather
    
    filter.setValue(CIVector(x: center.x, y: center.y), forKey: "inputCenter")
    filter.setValue(innerRadius, forKey: "inputRadius0")
    filter.setValue(outerRadius, forKey: "inputRadius1")
    filter.setValue(CIColor.white, forKey: "inputColor0")
    filter.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 0), forKey: "inputColor1")
    
    guard let outputImage = filter.outputImage else {
      return CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: imageSize))
    }
    
    return outputImage.cropped(to: CGRect(origin: .zero, size: imageSize))
  }
  
  /// 楕円形マスクを作成
  private func createEllipticalMask(rect: CGRect, imageSize: CGSize, feather: CGFloat) -> CIImage {
    guard let filter = CIFilter(name: "CIRadialGradient") else {
      return CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: imageSize))
    }
    
    let center = CIVector(x: rect.midX, y: rect.midY)
    let radius0 = min(rect.width, rect.height) * 0.3
    let radius1 = max(rect.width, rect.height) * 0.5 + feather
    
    filter.setValue(center, forKey: "inputCenter")
    filter.setValue(radius0, forKey: "inputRadius0")
    filter.setValue(radius1, forKey: "inputRadius1")
    filter.setValue(CIColor.white, forKey: "inputColor0")
    filter.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 0), forKey: "inputColor1")
    
    guard let outputImage = filter.outputImage else {
      return CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: imageSize))
    }
    
    return outputImage.cropped(to: CGRect(origin: .zero, size: imageSize))
  }
  
  /// 顔検出（シンプル版）
  private func detectPrimaryFace(in image: UIImage) async -> VNFaceObservation? {
    return await Task.detached(priority: .userInitiated) {
      guard let cgImage = image.cgImage else { return nil }
      
      let request = VNDetectFaceRectanglesRequest()  // ランドマーク不要ならこちらが高速
      let handler = VNImageRequestHandler(
        cgImage: cgImage,
        orientation: CGImagePropertyOrientation(image.imageOrientation)
      )
      
      do {
        try handler.perform([request])
        return (request.results as? [VNFaceObservation])?.first
      } catch {
        print("顔検出エラー: \(error)")
        return nil
      }
    }.value
  }
}

// MARK: - CGImagePropertyOrientation Extension
fileprivate extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}

// MARK: - Usage Example
/*
 class ViewController: UIViewController {
 let faceSwapper = FaceSwapEngine()
 
 func performFaceSwap() {
 Task {
 guard let sourceImage = UIImage(named: "source"),
 let targetImage = UIImage(named: "target") else { return }
 
 // 方法1: 顔を画像の中心に配置
 if let result = await faceSwapper.swapFaceToCenter(source: sourceImage, target: targetImage) {
 imageView.image = result
 }
 
 // 方法2: ターゲット画像の顔位置に合わせる
 if let result = await faceSwapper.swapFaceAligned(source: sourceImage, target: targetImage) {
 imageView.image = result
 }
 }
 }
 }
 */
