//
//  VisionProReceiverView.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import SwiftUI
import MultipeerConnectivity

struct VisionProReceiverView: View {
    @StateObject private var multipeerService = VisionProMultipeerService()
    @State private var receivedImage: UIImage?
    @State private var showConnectionPanel = true

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            // 受信した映像を表示
            if let image = receivedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                VStack {
                    Image(systemName: "video.slash")
                        .font(.system(size: 100))
                        .foregroundColor(.white.opacity(0.5))

                    Text("映像を待機中...")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 20)
                }
            }

            // 接続パネル
            if showConnectionPanel {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Apple Vision Pro - 受信モード")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("接続状態: \(multipeerService.connectionStatus)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))

                            Text("接続デバイス数: \(multipeerService.connectedPeers.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showConnectionPanel.toggle()
                            }
                        }) {
                            Image(systemName: "chevron.up.circle.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title2)
                        }
                    }

                    HStack(spacing: 15) {
                        Button(action: {
                            if multipeerService.isAdvertising {
                                multipeerService.stopAdvertising()
                            } else {
                                multipeerService.startAdvertising()
                            }
                        }) {
                            Text(multipeerService.isAdvertising ? "待機停止" : "待機開始")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(multipeerService.isAdvertising ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            if multipeerService.isBrowsing {
                                multipeerService.stopBrowsing()
                            } else {
                                multipeerService.startBrowsing()
                            }
                        }) {
                            Text(multipeerService.isBrowsing ? "検索停止" : "検索開始")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(multipeerService.isBrowsing ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            receivedImage = nil
                        }) {
                            Text("画面クリア")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)

                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(15)
                .padding(.top, 50)
                .padding(.horizontal, 20)
            } else {
                // 最小化されたパネル
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showConnectionPanel.toggle()
                            }
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(multipeerService.connectedPeers.isEmpty ? Color.black.opacity(0.7) : Color.green.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        .padding(.top, 50)

                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            setupMultipeerService()
        }
        .onDisappear {
            multipeerService.stopAdvertising()
            multipeerService.stopBrowsing()
        }
    }

    private func setupMultipeerService() {
        // 受信した画像を表示するコールバックを設定
        multipeerService.onImageReceived = { [weak self] image in
            DispatchQueue.main.async {
                self?.receivedImage = image
            }
        }

        // 自動的に待機を開始
        multipeerService.startAdvertising()
    }
}

// MARK: - Preview
#Preview {
    VisionProReceiverView()
}
