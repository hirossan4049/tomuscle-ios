//
//  iPhoneMultipeerService.swift
//  tomuscle_ios
//
//  Created by a on 9/6/25.
//

import Foundation
import MultipeerConnectivity
import AVFoundation
import UIKit

class iPhoneMultipeerService: NSObject, ObservableObject {
    // MARK: - Properties
    private let serviceType = "tomuscle-stream"
    private let myPeerID = MCPeerID(displayName: "iPhone-\(UIDevice.current.name)")

    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    @Published var connectedPeers: [MCPeerID] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var connectionStatus: String = "未接続"

    // MARK: - Initialization
    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["type": "iphone"], serviceType: serviceType)
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
        connectionStatus = "Vision Pro検索中..."
    }

    func stopBrowsing() {
        guard isBrowsing else { return }
        browser.stopBrowsingForPeers()
        isBrowsing = false
        updateConnectionStatus()
    }

    func sendVideoFrame(_ imageData: Data) {
        guard !connectedPeers.isEmpty else { return }

        do {
            try session.send(imageData, toPeers: connectedPeers, with: .unreliable)
        } catch {
            print("映像フレーム送信エラー: \(error.localizedDescription)")
        }
    }

    func sendVideoFrameAsImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        sendVideoFrame(imageData)
    }

    private func updateConnectionStatus() {
        if connectedPeers.isEmpty {
            connectionStatus = "未接続"
        } else {
            connectionStatus = "\(connectedPeers.count)台のVision Proに送信中"
        }
    }
}

// MARK: - MCSessionDelegate
extension iPhoneMultipeerService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                print("Vision Pro接続完了: \(peerID.displayName)")

            case .connecting:
                print("Vision Pro接続中: \(peerID.displayName)")

            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                print("Vision Pro接続解除: \(peerID.displayName)")

            @unknown default:
                print("不明な接続状態")
            }
            self.updateConnectionStatus()
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // iPhone側では通常データを受信しない（送信専用）
        DispatchQueue.main.async {
            print("Vision Proからデータを受信: \(data.count) bytes from \(peerID.displayName)")
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
extension iPhoneMultipeerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Vision Proからの招待を自動的に受け入れる
        invitationHandler(true, session)
        print("Vision Proからの招待を受け入れました: \(peerID.displayName)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension iPhoneMultipeerService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Vision Proを発見した場合、自動的に招待を送信
        if let discoveryInfo = info, discoveryInfo["type"] == "visionpro" {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            print("Vision Proを発見して招待を送信: \(peerID.displayName)")
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Vision Proを見失いました: \(peerID.displayName)")
    }
}
