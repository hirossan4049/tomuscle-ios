import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class FaceSwapEngine {
  private let ctx = CIContext()
  
  // ① 顔検出（同期実行をBGで）
  func detectPrimaryFace(in image: UIImage) async -> VNFaceObservation? {
    print("detectPrimaryFaceだよー")
    
    return await withCheckedContinuation { (cont: CheckedContinuation<VNFaceObservation?, Never>) in
      DispatchQueue.global(qos: .userInitiated).async {
        print("DispatchQueueだよー")
        guard let cg = image.cgImage else { cont.resume(returning: nil); return }
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
          cgImage: cg,
          orientation: CGImagePropertyOrientation(image.imageOrientation)
        )
        print("handlerだよ", handler)
        do {
          try handler.perform([request])
          let obs = (request.results)?.first
          print("obs:", obs)
          cont.resume(returning: obs)
        } catch {
          print("errorだよー", error)
          cont.resume(returning: nil)
        }
      }
    }
  }
  
  // ② Vision座標(0-1)のface rect→ピクセル矩形へ
  private func pixelRect(from norm: CGRect, imageSize: CGSize) -> CGRect {
    CGRect(
      x: norm.origin.x * imageSize.width,
      y: (1 - norm.origin.y - norm.height) * imageSize.height, // Vision→画像座標
      width: norm.width * imageSize.width,
      height: norm.height * imageSize.height
    ).integral
  }
  
  // ③ 指定矩形サイズの楕円フェザーマスク（キャンバス全体サイズで返す）
  private func ellipticalMask(canvasSize: CGSize, rect: CGRect, feather: CGFloat) -> CIImage {
    // 楕円の内外をラジアルではなくガウスぼかしで簡便に作る方法
    // 1) rectの中だけ白、外は黒のイメージを作る → 2) ぼかし
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let renderer = UIGraphicsImageRenderer(size: canvasSize)
    let maskUIImage = renderer.image { ctx in
      UIColor.black.setFill()
      ctx.fill(CGRect(origin: .zero, size: canvasSize))
      let path = UIBezierPath(ovalIn: rect)
      UIColor.white.setFill()
      path.fill()
    }
    var mask = CIImage(image: maskUIImage)!
    if feather > 0 {
      mask = mask.clampedToExtent()
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: feather])
        .cropped(to: CGRect(origin: .zero, size: canvasSize))
    }
    // CIBlendWithMaskは輝度をアルファとして解釈するため、GrayでOK
    return mask
  }
  
  /// 顔を検出してターゲット中央に貼り付け（スケールとフェザー調整可）
  func pasteFaceCentered(source: UIImage,
                         target: UIImage,
                         scale: CGFloat = 1.0,
                         feather: CGFloat = 16) async -> UIImage? {
    guard
      let srcCI = CIImage(image: source),
      let dstCI = CIImage(image: target),
      let srcObs = await detectPrimaryFace(in: source)
    else { return nil }
    
    // 1) ソース顔のピクセル矩形を取得・切り出し
    let srcFaceRect = pixelRect(from: srcObs.boundingBox, imageSize: source.size)
    let faceCrop = srcCI.cropped(to: srcFaceRect)
    
    // 2) 貼り付け先の中央に同じ比率で配置する矩形を決定
    let pasteSize = CGSize(width: srcFaceRect.width * scale,
                           height: srcFaceRect.height * scale)
    let dstExtent = dstCI.extent
    let pasteOrigin = CGPoint(
      x: dstExtent.midX - pasteSize.width / 2,
      y: dstExtent.midY - pasteSize.height / 2
    )
    let pasteRect = CGRect(origin: pasteOrigin, size: pasteSize)
    
    // 3) 切り出し画像に拡大縮小＋平行移動
    let sx = pasteSize.width / srcFaceRect.width
    let sy = pasteSize.height / srcFaceRect.height
    let transform =
    CGAffineTransform(translationX: -srcFaceRect.minX, y: -srcFaceRect.minY) // 原点合わせ
      .scaledBy(x: sx, y: sy)
      .translatedBy(x: pasteOrigin.x, y: pasteOrigin.y)
    let movedFace = faceCrop.transformed(by: transform)
    
    // 4) 貼り付け用の楕円フェザーマスクをキャンバス全体で生成
    let mask = ellipticalMask(canvasSize: target.size, rect: pasteRect, feather: feather)
    
    // 5) マスク合成でターゲット上にオーバーレイ
    guard let blend = CIFilter(name: "CIBlendWithMask") else { return nil }
    blend.setValue(movedFace, forKey: kCIInputImageKey)
    blend.setValue(dstCI, forKey: kCIInputBackgroundImageKey)
    blend.setValue(mask, forKey: kCIInputMaskImageKey)
    
    guard
      let out = blend.outputImage,
      let cg = ctx.createCGImage(out, from: dstExtent)
    else { return nil }
    
    return UIImage(cgImage: cg, scale: target.scale, orientation: target.imageOrientation)
  }
}


extension CGImagePropertyOrientation {
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
    @unknown default:
      self = .up
    }
  }
}
