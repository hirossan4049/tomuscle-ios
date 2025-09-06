//
//  VideoStreamCapture.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI

class VideoStreamCapture: ObservableObject {
    private var multipeerService: iPhoneMultipeerService?
    private var cameraController: CameraController?
    private var isStreaming = false
    private var streamingTimer: Timer?

    @Published var streamingStatus = "ストリーミング停止中"

    func setMultipeerService(_ service: iPhoneMultipeerService) {
        self.multipeerService = service
    }

    func setCameraController(_ controller: CameraController) {
        self.cameraController = controller
    }

    func startStreaming() {
        guard let multipeerService = multipeerService else {
            streamingStatus = "MultipeerServiceが設定されていません"
            return
        }

        guard !multipeerService.connectedPeers.isEmpty else {
            streamingStatus = "接続されたデバイスがありません"
            return
        }

        isStreaming = true
        streamingStatus = "ストリーミング中..."

        // 30FPSでストリーミング
        streamingTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.captureAndSendFrame()
        }
    }

    func stopStreaming() {
        isStreaming = false
        streamingTimer?.invalidate()
        streamingTimer = nil
        streamingStatus = "ストリーミング停止中"
    }

    private func captureAndSendFrame() {
        guard let cameraController = cameraController,
              let multipeerService = multipeerService,
              !multipeerService.connectedPeers.isEmpty else { return }

        // カメラフレームをキャプチャして送信
        if let frameImage = cameraController.captureCurrentFrameForStreaming() {
            multipeerService.sendVideoFrameAsImage(frameImage)
        }
    }

    func captureAndSendView(_ view: UIView) {
        guard isStreaming, let multipeerService = multipeerService else { return }

        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { context in
            view.layer.render(in: context.cgContext)
        }

        multipeerService.sendVideoFrameAsImage(image)
    }

    func captureAndSendSwiftUIView<Content: View>(_ content: Content, size: CGSize) {
        guard isStreaming, let multipeerService = multipeerService else { return }

        let controller = UIHostingController(rootView: content)
        controller.view.frame = CGRect(origin: .zero, size: size)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            controller.view.layer.render(in: context.cgContext)
        }

        multipeerService.sendVideoFrameAsImage(image)
    }
}

// MARK: - Camera Frame Capture Extension
extension CameraController {
    private static var streamCapture: VideoStreamCapture?

    func setStreamCapture(_ capture: VideoStreamCapture) {
        CameraController.streamCapture = capture
    }

    func captureCurrentFrameForStreaming() -> UIImage? {
        // 現在のカメラフレームをUIImageとして取得
        guard let currentPixelBuffer = getCurrentPixelBuffer() else { return nil }

        let ciImage = CIImage(cvPixelBuffer: currentPixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private var currentPixelBuffer: CVPixelBuffer?

    private func getCurrentPixelBuffer() -> CVPixelBuffer? {
        return currentPixelBuffer
    }

    // AVCaptureVideoDataOutputSampleBufferDelegateメソッドを拡張して現在のフレームを保存
    func updateCaptureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {

        // 現在のフレームを保存
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.currentPixelBuffer = pixelBuffer
        }

        // 既存の顔検出処理
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
        try? handler.perform([request])
    }
}
