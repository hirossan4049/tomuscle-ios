//
//  VisionProMultipeerService.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import Foundation
import MultipeerConnectivity
import UIKit

class VisionProMultipeerService: NSObject, ObservableObject {
    // MARK: - Properties
    private let serviceType = "tomuscle-stream"
    private let myPeerID = MCPeerID(displayName: "VisionPro-\(UIDevice.current.name)")

    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    @Published var connectedPeers: [MCPeerID] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var connectionStatus: String = "未接続"

    // 受信データ処理用のコールバック
    var onImageReceived: ((UIImage) -> Void)?

    // MARK: - Initialization
    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["type": "visionpro"], serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)

        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    deinit {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
    }

    // MARK: - Public Methods
    func startAdvertising() {
        guard !isAdvertising else { return }
        advertiser.startAdvertisingPeer()
        isAdvertising = true
        connectionStatus = "Vision Pro待機中..."
    }

    func stopAdvertising() {
        guard isAdvertising else { return }
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
        updateConnectionStatus()
    }

    func startBrowsing() {
        guard !isBrowsing else { return }
        browser.startBrowsingForPeers()
        isBrowsing = true
        connectionStatus = "iPhone検索中..."
    }

    func stopBrowsing() {
        guard isBrowsing else { return }
        browser.stopBrowsingForPeers()
        isBrowsing = false
        updateConnectionStatus()
    }

    private func updateConnectionStatus() {
        if connectedPeers.isEmpty {
            connectionStatus = "未接続"
        } else {
            connectionStatus = "\(connectedPeers.count)台のiPhoneから受信中"
        }
    }
}

// MARK: - MCSessionDelegate
extension VisionProMultipeerService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                print("iPhone接続完了: \(peerID.displayName)")

            case .connecting:
                print("iPhone接続中: \(peerID.displayName)")

            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                print("iPhone接続解除: \(peerID.displayName)")

            @unknown default:
                print("不明な接続状態")
            }
            self.updateConnectionStatus()
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Vision Pro専用の受信処理
        DispatchQueue.main.async {
            print("映像データを受信: \(data.count) bytes from iPhone: \(peerID.displayName)")

            // 受信したデータをUIImageに変換
            if let image = UIImage(data: data) {
                self.onImageReceived?(image)
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // ストリーム受信（今回は使用しない）
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // リソース受信開始（今回は使用しない）
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // リソース受信完了（今回は使用しない）
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension VisionProMultipeerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // iPhoneからの招待を自動的に受け入れる
        invitationHandler(true, session)
        print("iPhoneからの招待を受け入れました: \(peerID.displayName)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension VisionProMultipeerService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // iPhoneを発見した場合、自動的に招待を送信
        // Vision Proは通常受信側なので、iPhoneからの接続を待つ
        print("iPhoneを発見: \(peerID.displayName)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("iPhoneを見失いました: \(peerID.displayName)")
    }
}
