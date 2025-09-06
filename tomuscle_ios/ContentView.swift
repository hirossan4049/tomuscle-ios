//
//  ContentView.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import SwiftUI
import AVFoundation
import Vision

// MARK: - Content
struct ContentView: View {
  @State private var permissionDenied = false
  @State private var faceRects: [CGRect] = [] // 0..1 正規化座標（VisionのboundingBox）
  private let camera = CameraController()
  
  var body: some View {
    ZStack {
      CameraPreview(session: camera.session)
        .ignoresSafeArea()
      
      // 検出枠をオーバーレイ
      GeometryReader { geo in
        ForEach(faceRects.indices, id: \.self) { idx in
          let rect = convert(rect: faceRects[idx], in: geo.size)
          RoundedRectangle(cornerRadius: 6)
            .stroke(lineWidth: 3)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
        }
      }
      .allowsHitTesting(false)
      
      if permissionDenied {
        Color.black.opacity(0.6).ignoresSafeArea()
        VStack(spacing: 8) {
          Text("カメラへのアクセスが許可されていません")
            .font(.headline).foregroundColor(.white)
          Text("設定 > プライバシーとセキュリティ > カメラ から許可してください。")
            .font(.subheadline).multilineTextAlignment(.center)
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 24)
        }
      }
    }
    .onAppear {
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          permissionDenied = !granted
          if granted {
            camera.onFacesDetected = { rects in
              // UI更新はメインで
              self.faceRects = rects
            }
            camera.start()
          }
        }
      }
    }
    .onDisappear {
      camera.stop()
    }
  }
  
  /// Visionの正規化座標（左下原点）→ 画面座標（左上原点）に変換
  private func convert(rect: CGRect, in size: CGSize) -> CGRect {
    // Vision: origin(0,0)=左下, width/heightは0..1
    let x = rect.origin.x * size.width
    let y = (1 - rect.origin.y - rect.size.height) * size.height
    let w = rect.size.width * size.width
    let h = rect.size.height * size.height
    return CGRect(x: x, y: y, width: w, height: h)
  }
//  private func convert(rect: CGRect, in size: CGSize) -> CGRect {
//      // フロントカメラのミラーリングを考慮
//      // X座標：左右反転（1 - x - width ではなく 1 - x）
//      let x = (1 - rect.origin.x - rect.size.width) * size.width
//      
//      // Y座標：上下反転（1 - y ではなく、そのまま y を使う）
//      // Visionの左下原点(y)を、UIKitの左上原点に変換
//      let y = rect.origin.y * size.height
//      
//      let w = rect.size.width * size.width
//      let h = rect.size.height * size.height
//      
//      return CGRect(x: x, y: y, width: w, height: h)
//  }
}

// MARK: - Camera Preview (SwiftUI <-> AVCaptureVideoPreviewLayer)
struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession
  
  func makeUIView(context: Context) -> PreviewView {
    let v = PreviewView()
    v.videoPreviewLayer.session = session
    v.videoPreviewLayer.videoGravity = .resizeAspectFill
    return v
  }
  
  func updateUIView(_ uiView: PreviewView, context: Context) {}
  
  final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  }
}

// MARK: - Camera + Vision (最小限の制御。MVVMなし)
final class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "camera.queue")
  private let videoOutput = AVCaptureVideoDataOutput()
  private var device: AVCaptureDevice?
  private var lastRequestTime = CFAbsoluteTimeGetCurrent()
  var onFacesDetected: (([CGRect]) -> Void)?
  
  func start() {
    if session.inputs.isEmpty {
      setupSession()
    }
    queue.async { [weak self] in
      self?.session.startRunning()
    }
  }
  
  func stop() {
    queue.async { [weak self] in
      self?.session.stopRunning()
    }
  }
  
  private func setupSession() {
    session.beginConfiguration()
    session.sessionPreset = .high
    
    // Front camera
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .front
    )
    guard let device = discovery.devices.first,
          let input = try? AVCaptureDeviceInput(device: device),
          session.canAddInput(input) else {
      session.commitConfiguration()
      return
    }
    session.addInput(input)
    self.device = device
    
    // Output
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: queue)
    guard session.canAddOutput(videoOutput) else {
      session.commitConfiguration()
      return
    }
    session.addOutput(videoOutput)
    
    // 縦向き固定
    if let conn = videoOutput.connection(with: .video), conn.isVideoOrientationSupported {
      conn.videoOrientation = .portrait
    }
    
    session.commitConfiguration()
  }
  
  // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
  func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    
    // 軽負荷のため 15fps相当で間引き（必要に応じて調整）
    let now = CFAbsoluteTimeGetCurrent()
    if now - lastRequestTime < (1.0 / 15.0) { return }
    lastRequestTime = now
    
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    let request = VNDetectFaceRectanglesRequest { [weak self] req, _ in
      guard let self = self else { return }
      let boxes: [CGRect] = (req.results as? [VNFaceObservation])?.map { $0.boundingBox } ?? []
      DispatchQueue.main.async {
        self.onFacesDetected?(boxes)
      }
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
    // フロントカメラ映像は左右反転考慮（.leftMirrored）。背面なら .right を想定。
    try? handler.perform([request])
  }
}


#Preview {
  ContentView()
}
