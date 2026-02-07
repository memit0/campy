//
//  HomeViewModel.swift
//  campy
//
//  ViewModel for home screen
//

import SwiftUI

@Observable
@MainActor
class HomeViewModel {
    var showStartSession = false
    var showJoinSession = false
    var nearbySessions: [NearbySession] = []
    var isSearchingForSessions = false

    // Reference to managers (will be injected)
    weak var bluetoothManager: BluetoothManager?
    weak var walletManager: WalletManager?

    var balance: Int {
        walletManager?.balance ?? 0
    }

    func startHosting() {
        showStartSession = true
    }

    func joinSession() {
        showJoinSession = true
        startSearchingForSessions()
    }

    func startSearchingForSessions() {
        isSearchingForSessions = true
        bluetoothManager?.startScanning()
    }

    func stopSearchingForSessions() {
        isSearchingForSessions = false
        bluetoothManager?.stopScanning()
    }

    func connectToSession(_ session: NearbySession) {
        bluetoothManager?.connectToHost(peerId: session.hostPeerId)
    }
}
