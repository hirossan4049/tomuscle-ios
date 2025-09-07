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
  @State private var imageScale: Double = 5.0 // 画像のスケール値
  @State private var showScaleControl = true // スケールコントロールの表示/非表示

  @StateObject private var apiKeyManager = APIKeyManager()
  @State private var encouragementManager: EncouragementManager?

  private let camera = CameraController()

  // 差し込む画像の名前（Assets.xcassetsに追加してください）
  private let overlayImageName = "overlay_image" // この名前を実際の画像名に変更してください

  var body: some View {
    ZStack {
      CameraPreview(session: camera.session)
        .ignoresSafeArea()

      // 検出枠に画像をオーバーレイ
      GeometryReader { geo in
        ForEach(faceRects.indices, id: \.self) { idx in
          let rect = convert(rect: faceRects[idx], in: geo.size)

          // スケールを適用した画像サイズ
          let scaledWidth = rect.width * imageScale
          let scaledHeight = rect.height * imageScale

          // 画像を表示（システムアイコンまたはカスタム画像）
          // カスタム画像を使う場合
          Image(overlayImageName)
            .resizable()
            .scaledToFit()
            .frame(width: scaledWidth, height: scaledHeight)
            .position(x: rect.midX, y: rect.midY)

          // またはシステムアイコンを使う場合（テスト用）
          // Image(systemName: "face.smiling.fill")
          //   .resizable()
          //   .scaledToFit()
          //   .foregroundColor(.yellow.opacity(0.7))
          //   .frame(width: scaledWidth, height: scaledHeight)
          //   .position(x: rect.midX, y: rect.midY)

          // 枠線も表示したい場合はコメントアウトを解除
          // RoundedRectangle(cornerRadius: 6)
          //   .stroke(Color.blue, lineWidth: 2)
          //   .frame(width: rect.width, height: rect.height)
          //   .position(x: rect.midX, y: rect.midY)
        }
      }
      .allowsHitTesting(false)

      // スケール調整コントロール
      if showScaleControl {
        VStack {
          Spacer()
          VStack(spacing: 10) {
            HStack {
              Text("画像スケール: \(String(format: "%.1fx", imageScale))")
                .foregroundColor(.white)
                .font(.caption)
                .padding(.horizontal)

              Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                  showScaleControl.toggle()
                }
              }) {
                Image(systemName: "chevron.down.circle.fill")
                  .foregroundColor(.white.opacity(0.8))
              }
            }

            HStack {
              Image(systemName: "minus.magnifyingglass")
                .foregroundColor(.white.opacity(0.7))

              Slider(value: $imageScale, in: 0.5...3.0, step: 0.1)
                .accentColor(.white)
                .frame(width: 200)

              Image(systemName: "plus.magnifyingglass")
                .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 20) {
              Button("0.5x") { withAnimation { imageScale = 0.5 } }
              Button("1.0x") { withAnimation { imageScale = 1.0 } }
              Button("1.5x") { withAnimation { imageScale = 1.5 } }
              Button("2.0x") { withAnimation { imageScale = 2.0 } }
            }
            .font(.caption)
            .foregroundColor(.white)
          }
          .padding()
          .background(Color.black.opacity(0.7))
          .cornerRadius(15)
          .padding(.bottom, 30)
        }
      } else {
        // 最小化されたボタン
        VStack {
          Spacer()
          HStack {
            Spacer()
            Button(action: {
              withAnimation(.easeInOut(duration: 0.2)) {
                showScaleControl.toggle()
              }
            }) {
              Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.bottom, 30)
          }
        }
      }

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

      // 応援機能の初期化と自動開始
      encouragementManager = EncouragementManager(apiKey: apiKeyManager.getAPIKey())
      encouragementManager?.startEncouragement()
    }
    .onDisappear {
      camera.stop()
      encouragementManager?.stopEncouragement()
    }
  }

  private func convert(rect: CGRect, in size: CGSize) -> CGRect {
    let W = size.width, H = size.height

    // 90°時計回りの回転（正規化座標）
    let rx = rect.origin.y
    let ry = 1 - rect.origin.x - rect.size.width
    let rw = rect.size.height
    let rh = rect.size.width

    // セルフィープレビューの水平ミラーを補正
    let mx = 1 - rx - rw

    return CGRect(x: mx * W, y: ry * H, width: rw * W, height: rh * H)
  }
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

    // Back camera (背面カメラ)
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .back
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

    // 軽負荷のため 30fps相当で間引き（必要に応じて調整）
    let now = CFAbsoluteTimeGetCurrent()
    if now - lastRequestTime < (1.0 / 30.0) { return }
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
    // 背面カメラの場合は .right を使用
    try? handler.perform([request])
  }
}

#Preview {
  ContentView()
}
