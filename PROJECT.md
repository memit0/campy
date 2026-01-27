# Campy - Phone Detox Challenge App

## Finalized Technical Specification

**Version**: 1.0
**Last Updated**: January 2026
**Platform**: iOS 18.2+
**Language**: Swift 5.9+ / SwiftUI

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision](#2-product-vision)
3. [User Experience Flow](#3-user-experience-flow)
4. [Feature Specifications](#4-feature-specifications)
5. [Technical Architecture](#5-technical-architecture)
6. [Data Models](#6-data-models)
7. [Service Layer](#7-service-layer)
8. [User Interface Specifications](#8-user-interface-specifications)
9. [Bluetooth Communication Protocol](#9-bluetooth-communication-protocol)
10. [In-App Purchases](#10-in-app-purchases)
11. [Data Persistence & Sync](#11-data-persistence--sync)
12. [Security & Anti-Cheat](#12-security--anti-cheat)
13. [Error Handling](#13-error-handling)
14. [Testing Strategy](#14-testing-strategy)
15. [Build & Configuration](#15-build--configuration)
16. [Asset Specifications](#16-asset-specifications)
17. [Localization](#17-localization)
18. [Analytics Events](#18-analytics-events)
19. [Known Limitations](#19-known-limitations)
20. [Future Roadmap](#20-future-roadmap)

---

## 1. Executive Summary

### What is Campy?

Campy is a social iOS app that gamifies staying off your phone. Users challenge friends in-person via Bluetooth to see who can resist checking their phone the longest. The first person to leave the app loses their bet to the winners.

### Key Differentiators

| Feature | Campy | Competitors |
|---------|-------|-------------|
| No internet required | Bluetooth P2P | Server-based |
| Real stakes | In-app currency bets | No stakes |
| Instant detection | App backgrounding | Timer-based |
| No login | Device-based identity | Account required |
| Privacy-first | No data collection | Cloud tracking |

### Success Metrics (v1)

- User completes onboarding: 80%+
- Sessions started per active user: 2+/week
- Session completion rate: 60%+
- Coin purchase conversion: 5%+

---

## 2. Product Vision

### Core Philosophy

> "Put the phone down and pick up the moment."

Campy exists because our phones dominate social situations. We believe:
- Being present with friends is more valuable than scrolling
- Gamification drives behavior change
- Stakes create accountability
- Simplicity enables adoption

### Target Users

**Primary**: Friend groups (18-35) dining out, at parties, or hanging out who want to minimize phone use together.

**Use Cases**:
- Dinner parties: "Phones in the middle, first to grab pays the bill"
- Study groups: "No phones for 25 minutes"
- Date nights: "Let's be present together"
- Family gatherings: "Kids vs. adults challenge"

---

## 3. User Experience Flow

### First-Time User Journey

```
┌─────────────────────────────────────────────────────────────────────┐
│                           FIRST LAUNCH                               │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  ONBOARDING (5 screens)                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │  Page 1 │→ │  Page 2 │→ │  Page 3 │→ │  Page 4 │→ │  Page 5 │  │
│  │ Welcome │  │ Notifi- │  │ Create  │  │  Rules  │  │  Start  │  │
│  │         │  │ cations │  │Challenge│  │         │  │         │  │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ "Get Started"
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  HOME SCREEN                                                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  [Balance: 100b]                                   [Settings] │  │
│  │                                                               │  │
│  │                      "Hi!"                                    │  │
│  │         "Time to cherish this moment with friends"            │  │
│  │                                                               │  │
│  │                   [Campy Mascot]                              │  │
│  │                                                               │  │
│  │                    ┌─────────┐                                │  │
│  │                    │  START  │                                │  │
│  │                    └─────────┘                                │  │
│  │                                                               │  │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │  │
│  │  [    Home    ]                              [    Wallet    ] │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Complete Session Flow

```
                    USER A (HOST)                         USER B (JOINER)
                         │                                      │
                         │ Taps "Start"                         │
                         ▼                                      │
              ┌──────────────────────┐                         │
              │  Start Session Sheet │                         │
              │  - Select time       │                         │
              │  - Select bet        │                         │
              │  - Tap "GO"          │                         │
              └──────────┬───────────┘                         │
                         │                                      │
                         ▼                                      │
              ┌──────────────────────┐                         │
              │  Waiting for Players │                         │
              │  (Bluetooth advert.) │◄────────────────────────┤ Sees session
              └──────────┬───────────┘                         │
                         │                                      │
                         │◄─────────────────────────────────────┤ Taps "Join"
                         │              Player B joins          │
                         │                                      │
                         ▼                                      ▼
              ┌──────────────────────┐              ┌──────────────────────┐
              │  Player B joined!    │              │  Joined session!     │
              │  [Start Game]        │              │  Waiting for host... │
              └──────────┬───────────┘              └──────────┬───────────┘
                         │                                      │
                         │ Host taps "Start Game"               │
                         │                                      │
                         ▼                                      ▼
              ┌──────────────────────┐              ┌──────────────────────┐
              │     COUNTDOWN        │              │     COUNTDOWN        │
              │      3... 2... 1...  │              │      3... 2... 1...  │
              └──────────┬───────────┘              └──────────┬───────────┘
                         │                                      │
                         ▼                                      ▼
              ┌──────────────────────┐              ┌──────────────────────┐
              │   ACTIVE GAME        │              │   ACTIVE GAME        │
              │                      │              │                      │
              │      15:00           │              │      15:00           │
              │       20b            │              │       20b            │
              │                      │              │                      │
              │   👤 Emma  👤 Sam    │              │   👤 Emma  👤 Sam    │
              │                      │              │                      │
              │  "Put your phone     │              │  "Put your phone     │
              │       down"          │              │       down"          │
              └──────────┬───────────┘              └──────────┬───────────┘
                         │                                      │
                         │                              User B leaves app!
                         │                                      │
                         ▼                                      ▼
              ┌──────────────────────┐              ┌──────────────────────┐
              │     🏆 YOU WON!      │              │     ❌ YOU LOST      │
              │                      │              │                      │
              │  Winnings added      │              │  Better luck         │
              │  to wallet: +40b     │              │  next time!          │
              │                      │              │                      │
              │      [Done]          │              │      [Done]          │
              └──────────────────────┘              └──────────────────────┘
```

---

## 4. Feature Specifications

### 4.1 Identity System

**Requirement**: Device-based identity with no login required.

| Property | Implementation |
|----------|----------------|
| User ID | `UUID` generated on first launch |
| Display Name | User-entered, stored in `UserDefaults` |
| Avatar | Color index (0-7), randomly assigned |
| Persistence | Local (`UserDefaults`) + iCloud (`CloudKit`) |

**Behavior**:
- First launch: Generate UUID, assign random avatar color
- User can change display name in Settings
- Avatar color cannot be changed (v1)
- Data syncs silently to iCloud (no prompts)

### 4.2 Wallet System

**Requirement**: In-app currency for betting with no real-money withdrawal.

| Property | Value |
|----------|-------|
| Currency name | "Campy Coins" or "b" (shorthand) |
| Display format | `X,XXXb` (e.g., "3,284b") |
| Welcome bonus | 100 coins on first launch |
| Minimum bet | 5 coins |
| Maximum bet | 25 coins |

**Transaction Types**:

| Type | Direction | Example |
|------|-----------|---------|
| `bonus` | + | Welcome bonus (+100b) |
| `purchase` | + | Bought coins (+500b) |
| `sessionLoss` | - | Lost challenge (-20b) |
| `sessionWin` | + | Won challenge (+40b) |
| `refund` | + | Disconnection refund (+20b) |

**Withdrawal**: Disabled in v1. Show "Coming Soon" alert when tapped.

### 4.3 Challenge Sessions

**Requirement**: Peer-to-peer sessions via Bluetooth with configurable duration and bet.

**Configuration Options**:

| Parameter | Options | Default |
|-----------|---------|---------|
| Duration | 5, 10, 15, 20, 25 minutes | 15 min |
| Bet Amount | 5, 10, 15, 20, 25 coins | 15 coins |

**Participant Limits**:

| Limit | Value | Reason |
|-------|-------|--------|
| Minimum | 2 players | Game requires opponent |
| Maximum | ~7-8 players | Bluetooth connection limit |

**Session States**:

```
┌──────────┐     ┌───────────┐     ┌─────────┐     ┌───────┐
│ waiting  │ ──▶ │ countdown │ ──▶ │ active  │ ──▶ │ ended │
└──────────┘     └───────────┘     └─────────┘     └───────┘
      │                                                 ▲
      │                                                 │
      └──────────────────────────────────────────────▶─┘
                        (cancelled)
```

### 4.4 Game Rules

**Loss Conditions** (instant, no grace period):

1. **App Backgrounding**: User presses home, switches apps, or receives call
2. **App Termination**: User swipe-kills the app
3. **Device Sleep**: Screen locks while app is open (if detected)
4. **Bluetooth Disconnect**: Connection lost for 3+ seconds

**Win Conditions**:

1. **Opponent Loss**: Another player triggers a loss condition
2. **Timer Completion**: All players survive until timer reaches 0:00

**Payout Calculation**:

```
Total Pot = Number of Players × Bet Amount
Winnings per Winner = Total Pot ÷ Number of Winners

Example (3 players, 20b bet, 1 loser):
- Total Pot = 3 × 20 = 60b
- Loser forfeits: 20b
- Winners (2): 60b ÷ 2 = 30b each
- Net gain per winner: 30b - 20b = +10b
```

### 4.5 Airplane Mode Requirement

**Requirement**: All players must have airplane mode enabled before game starts.

**Rationale**: Prevents cheating via:
- Incoming calls interrupting the app
- Push notifications causing distraction
- Background data affecting app state

**Detection Method**:
```swift
import Network

let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    let isAirplaneModeOff = path.status == .satisfied
    // Block game start if isAirplaneModeOff == true
}
```

**UX Flow**:
1. User taps "GO" to start session
2. System checks airplane mode
3. If OFF: Show alert "Please enable airplane mode to start"
4. If ON: Proceed with session creation

---

## 5. Technical Architecture

### 5.1 Project Structure

```
campy/
├── campyApp.swift                 # App entry point
├── Info.plist                     # App configuration
├── campy.entitlements             # iCloud/Bluetooth entitlements
│
├── Core/
│   ├── Constants/
│   │   └── DesignTokens.swift     # Colors, fonts, spacing
│   ├── Extensions/
│   │   └── Color+Theme.swift      # Hex color support
│   └── Utilities/
│       └── SoundManager.swift     # Audio + haptics
│
├── Models/
│   ├── User.swift                 # User + SessionParticipant
│   ├── Session.swift              # Session + NearbySession
│   ├── Transaction.swift          # Wallet transactions
│   └── CoinPackage.swift          # IAP products
│
├── Services/
│   ├── Bluetooth/
│   │   └── BluetoothManager.swift # Core Bluetooth wrapper
│   ├── GameManager.swift          # Game state machine
│   ├── WalletManager.swift        # Balance + transactions
│   ├── StoreKitManager.swift      # In-app purchases
│   ├── CloudKitManager.swift      # iCloud sync
│   └── AppLifecycleManager.swift  # Loss detection
│
├── ViewModels/
│   ├── OnboardingViewModel.swift
│   ├── HomeViewModel.swift
│   ├── SessionViewModel.swift
│   └── WalletViewModel.swift
│
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingContainerView.swift
│   ├── Main/
│   │   └── MainTabView.swift
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Session/
│   │   └── StartSessionView.swift
│   ├── ActiveGame/
│   │   └── ActiveSessionView.swift
│   ├── Wallet/
│   │   └── WalletView.swift
│   └── Components/
│       ├── PillButton.swift
│       ├── CircularButton.swift
│       ├── BottomSheet.swift
│       ├── CustomTabBar.swift
│       ├── UserAvatar.swift
│       ├── BalanceView.swift
│       ├── TransactionRow.swift
│       ├── HorizontalPicker.swift
│       └── SettingsView.swift
│
└── Assets.xcassets/
    ├── AppIcon.appiconset/
    ├── onboarding-1.imageset/
    ├── onboarding-2.imageset/
    ├── onboarding-3.imageset/
    ├── onboarding-4.imageset/
    ├── onboarding-5.imageset/
    ├── campy-mascot.imageset/
    ├── coin-mascot.imageset/
    └── trees-background.imageset/
```

### 5.2 Dependency Graph

```
                        ┌─────────────────┐
                        │    campyApp     │
                        └────────┬────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                    │
            ▼                    ▼                    ▼
    ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
    │  GameManager  │   │ WalletManager │   │BluetoothManager│
    └───────┬───────┘   └───────┬───────┘   └───────────────┘
            │                   │                    ▲
            │                   │                    │
            └───────────┬───────┴───────────────────┘
                        │
                        ▼
               ┌───────────────┐
               │   CloudKit    │
               │   Manager     │
               └───────────────┘

Dependencies:
- GameManager → BluetoothManager (session communication)
- GameManager → WalletManager (bet deduction/winnings)
- GameManager → AppLifecycleManager (loss detection)
- WalletManager → CloudKitManager (sync)
- StoreKitManager → WalletManager (credit coins after purchase)
```

### 5.3 State Management

**Pattern**: SwiftUI `@Observable` macro (iOS 17+)

**Environment Injection**:
```swift
@main
struct CampyApp: App {
    @State private var walletManager = WalletManager()
    @State private var gameManager = GameManager()
    @State private var bluetoothManager = BluetoothManager()
    @State private var storeKitManager = StoreKitManager()
    @State private var cloudKitManager = CloudKitManager()
    @State private var appLifecycleManager = AppLifecycleManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(walletManager)
                .environment(gameManager)
                .environment(bluetoothManager)
                .environment(storeKitManager)
                .environment(cloudKitManager)
                .environment(appLifecycleManager)
        }
    }
}
```

**View Consumption**:
```swift
struct HomeView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(GameManager.self) private var gameManager

    var body: some View {
        Text("Balance: \(walletManager.balance)b")
    }
}
```

---

## 6. Data Models

### 6.1 User

```swift
struct User: Identifiable, Codable {
    let id: UUID
    var displayName: String
    var avatarColorIndex: Int      // 0-7 maps to CampyColors.avatarColors
    var balance: Int
    var createdAt: Date
    var updatedAt: Date
}
```

**UserDefaults Keys**:
```swift
enum UserDefaultsKeys {
    static let userId = "userId"
    static let displayName = "displayName"
    static let avatarColorIndex = "avatarColorIndex"
    static let userBalance = "userBalance"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
```

### 6.2 SessionParticipant

```swift
struct SessionParticipant: Identifiable, Codable {
    let id: UUID
    let peerId: String              // Bluetooth peer identifier
    var displayName: String
    var avatarColorIndex: Int
    var isHost: Bool
    var hasLost: Bool = false
    var lostAt: Date?
}
```

### 6.3 Session

```swift
struct Session: Identifiable, Codable {
    let id: UUID
    let hostId: UUID                // SessionParticipant.id of host
    var participants: [SessionParticipant]
    var durationMinutes: Int        // 5, 10, 15, 20, or 25
    var betAmount: Int              // 5, 10, 15, 20, or 25
    var state: SessionState
    var startedAt: Date?
    var endedAt: Date?
    var loserId: UUID?              // First participant to lose
    var createdAt: Date

    // Computed properties
    var totalPot: Int { participants.count * betAmount }
    var activeParticipants: [SessionParticipant] { participants.filter { !$0.hasLost } }
    var loser: SessionParticipant? { participants.first { $0.hasLost } }
    var winners: [SessionParticipant] { participants.filter { !$0.hasLost } }
    var isCompleted: Bool { state == .ended || state == .cancelled }

    // Methods
    mutating func markParticipantAsLost(participantId: UUID)
    mutating func start()
    mutating func end()
}

enum SessionState: String, Codable {
    case waiting    // Host created, advertising via Bluetooth
    case countdown  // All ready, 3-2-1 countdown
    case active     // Timer running, monitoring for losses
    case ended      // Game complete
    case cancelled  // Host cancelled before start
}
```

### 6.4 NearbySession

```swift
struct NearbySession: Identifiable {
    let id: UUID
    let hostName: String
    let hostPeerId: String
    let durationMinutes: Int
    let betAmount: Int
    let participantCount: Int
    var signalStrength: Int         // RSSI for proximity sorting

    var formattedBet: String { "\(betAmount)b" }
    var formattedDuration: String { "\(durationMinutes) min" }
}
```

### 6.5 Transaction

```swift
struct Transaction: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amount: Int                 // Positive = credit, negative = debit
    let description: String
    let timestamp: Date

    var isCredit: Bool { amount > 0 }
    var formattedAmount: String {
        isCredit ? "+\(amount)b" : "\(amount)b"
    }
}

enum TransactionType: String, Codable {
    case purchase       // Bought coins via IAP
    case sessionWin     // Won a challenge
    case sessionLoss    // Lost a challenge
    case refund         // Disconnection/error refund
    case bonus          // Welcome bonus or promo
}
```

### 6.6 CoinPackage

```swift
struct CoinPackage: Identifiable {
    let id: String                  // StoreKit product ID
    let coins: Int
    var product: Product?           // StoreKit Product (nil until loaded)

    var displayPrice: String {
        product?.displayPrice ?? "..."
    }
}
```

---

## 7. Service Layer

### 7.1 GameManager

**Purpose**: Central state machine coordinating game flow.

**State Diagram**:
```
                    ┌─────────────────────────┐
                    │                         │
                    ▼                         │
┌──────┐    createSession()    ┌─────────┐   │
│ idle │──────────────────────▶│ waiting │   │
└──────┘                       └────┬────┘   │
    ▲                               │        │
    │                               │        │
    │ leaveSession()                │ allPlayersReady()
    │                               ▼        │
    │                         ┌───────────┐  │
    │                         │ countdown │  │
    │                         │ (3-2-1)   │  │
    │                         └─────┬─────┘  │
    │                               │        │
    │                               │ countdownComplete()
    │                               ▼        │
    │                         ┌─────────┐    │
    │◀────────────────────────│ playing │    │
    │    endGame()            └────┬────┘    │
    │                              │         │
    │        loss detected OR      │         │
    │        timer completes       │         │
    │                              ▼         │
    │                         ┌─────────────┐│
    └─────────────────────────│ended(winner)│┘
              dismiss()       └─────────────┘
```

**Public Interface**:
```swift
@Observable
class GameManager {
    // State
    private(set) var state: GameState = .idle
    private(set) var currentSession: Session?
    private(set) var remainingSeconds: Int = 0

    // Computed
    var formattedTimeRemaining: String
    var participants: [SessionParticipant]
    var betAmount: Int

    // Session lifecycle
    func createSession(duration: Int, betAmount: Int) -> Session?
    func joinSession(_ session: Session, as participant: SessionParticipant)
    func leaveSession()

    // Game control
    func startCountdown()
    func startGame()
    func reportLoss()
    func handleParticipantLoss(participantId: UUID)
}
```

### 7.2 BluetoothManager

**Purpose**: Core Bluetooth wrapper for peer-to-peer communication.

**Architecture**:
- **Host**: `CBPeripheralManager` (advertises session as GATT server)
- **Joiner**: `CBCentralManager` (scans and connects as GATT client)

**Public Interface**:
```swift
@Observable
class BluetoothManager: NSObject {
    // State
    private(set) var isScanning: Bool = false
    private(set) var isAdvertising: Bool = false
    private(set) var nearbySessions: [NearbySession] = []
    var localPeerId: String { /* device UUID */ }

    // Callbacks (set by GameManager)
    var onParticipantJoined: ((SessionParticipant) -> Void)?
    var onParticipantLeft: ((UUID) -> Void)?
    var onGameStarted: (() -> Void)?
    var onGameEnded: ((UUID?) -> Void)?
    var onSessionReceived: ((Session) -> Void)?
    var onNearbySessionsUpdated: (([NearbySession]) -> Void)?

    // Host methods
    func startAdvertising(session: Session)
    func stopAdvertising()
    func broadcastGameStart()
    func broadcastGameEnd(loserId: UUID?)

    // Joiner methods
    func startScanning()
    func stopScanning()
    func connect(to session: NearbySession)
    func disconnect()

    // Common
    func reportLoss(participantId: UUID)
}
```

### 7.3 WalletManager

**Purpose**: Manages coin balance and transaction history.

**Public Interface**:
```swift
@Observable
class WalletManager {
    // State
    private(set) var balance: Int = 0
    private(set) var transactions: [Transaction] = []

    // Dependencies
    var cloudKitManager: CloudKitManager?

    // Methods
    func hasEnoughBalance(for amount: Int) -> Bool
    func addCoins(amount: Int, description: String, type: TransactionType)
    func addWinnings(amount: Int)
    func deductBet(amount: Int)
    func refund(amount: Int, reason: String)

    // Persistence
    func loadFromStorage()
    func saveToStorage()
    func syncToCloud()

    // Debug
    func loadDemoData()
}
```

### 7.4 StoreKitManager

**Purpose**: StoreKit 2 integration for in-app purchases.

**Public Interface**:
```swift
@Observable
class StoreKitManager {
    // State
    private(set) var products: [Product] = []
    private(set) var isLoading: Bool = false
    private(set) var purchaseError: String?

    // Methods
    func loadProducts() async
    func purchase(_ product: Product) async throws -> Bool
    func restorePurchases() async
}
```

### 7.5 CloudKitManager

**Purpose**: Silent iCloud sync for data backup.

**Public Interface**:
```swift
@Observable
class CloudKitManager {
    // State
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date?

    // Methods
    func initialize()
    func syncUserData(_ user: User)
    func syncTransactions(_ transactions: [Transaction])
    func fetchUserData() async -> User?
    func fetchTransactions() async -> [Transaction]
}
```

### 7.6 AppLifecycleManager

**Purpose**: Monitors app lifecycle for loss detection.

**Public Interface**:
```swift
@Observable
class AppLifecycleManager {
    // State
    private(set) var isMonitoring: Bool = false

    // Callback
    var onAppBackgrounded: (() -> Void)?

    // Methods
    func startMonitoring()
    func stopMonitoring()
    func handleScenePhaseChange(_ phase: ScenePhase)
}
```

**Integration**:
```swift
// In main app or root view
@Environment(\.scenePhase) var scenePhase

.onChange(of: scenePhase) { oldPhase, newPhase in
    appLifecycleManager.handleScenePhaseChange(newPhase)
}
```

---

## 8. User Interface Specifications

### 8.1 Design System

**Colors** (`DesignTokens.swift`):

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `background` | `#1C2D41` | 28, 45, 65 | App background |
| `cardBackground` | `#243B53` | 36, 59, 83 | Cards, rows |
| `sheetBackground` | `#2A4562` | 42, 69, 98 | Bottom sheets |
| `accent` | `#3B82C4` | 59, 130, 196 | Primary buttons |
| `accentLight` | `#5BA3D9` | 91, 163, 217 | Highlights |
| `accentDark` | `#2D6AA0` | 45, 106, 160 | Pressed states |
| `currency` | `#F5A623` | 245, 166, 35 | Coin amounts |
| `textPrimary` | `#FFFFFF` | 255, 255, 255 | Main text |
| `textSecondary` | `#A0B3C6` | 160, 179, 198 | Muted text |
| `textMuted` | `#6B8299` | 107, 130, 153 | Disabled text |
| `success` | `#4CAF50` | 76, 175, 80 | Win state |
| `error` | `#F44336` | 244, 67, 54 | Loss state |

**Avatar Colors** (8 options):
```swift
[
    "#E91E63", // Pink
    "#9C27B0", // Purple
    "#3F51B5", // Indigo
    "#4CAF50", // Green
    "#FF9800", // Orange
    "#00BCD4", // Cyan
    "#F44336", // Red
    "#FFEB3B"  // Yellow
]
```

**Typography**:

| Style | Size | Weight | Design | Usage |
|-------|------|--------|--------|-------|
| `timer` | 72pt | Bold | Rounded | Countdown display |
| `largeTitle` | 34pt | Bold | Rounded | Onboarding headers |
| `header` | 24pt | Bold | Rounded | Section titles |
| `subheader` | 20pt | Semibold | Rounded | Subsections |
| `body` | 16pt | Regular | Rounded | Body text |
| `caption` | 14pt | Regular | Rounded | Small text |
| `button` | 18pt | Semibold | Rounded | Button labels |
| `balance` | 48pt | Bold | Rounded | Wallet balance |

**Spacing**:

| Token | Value |
|-------|-------|
| `xs` | 4pt |
| `sm` | 8pt |
| `md` | 16pt |
| `lg` | 24pt |
| `xl` | 32pt |
| `xxl` | 48pt |
| `xxxl` | 64pt |

**Corner Radius**:

| Token | Value | Usage |
|-------|-------|-------|
| `small` | 8pt | Small elements |
| `medium` | 12pt | Medium cards |
| `large` | 16pt | Large cards |
| `xlarge` | 24pt | Extra large |
| `pill` | 25pt | Pill buttons |
| `sheet` | 32pt | Bottom sheets |
| `circular` | 999pt | Round buttons |

### 8.2 Screen Specifications

#### Onboarding (5 pages)

**Page 1 - Welcome**:
- Image: `onboarding-1` (55% height)
- Header: "Put the phone down and pick up the moment."
- Subtext: "Some memories are better lived than scrolled."
- Button: "Next"

**Page 2 - Notifications**:
- Image: `onboarding-2` (50% height)
- Header: "Your friends are right here. Put the phone down and don't miss this moment."
- Subtext: "Allow notifications to let us remind you."
- Buttons: "Allow" (primary), "Later" (outline)

**Page 3 - Create Challenge**:
- Image: `onboarding-3` (55% height)
- Header: "Create a challenge with friends"
- Subtext: "Connect with nearby friends and start a phone-free challenge together."
- Button: "Next"

**Page 4 - Rules**:
- Image: `onboarding-4` (55% height)
- Header: "Phones stay down. First phone pays."
- Subtext: "The first person to leave the app loses and pays the others."
- Button: "Next"

**Page 5 - Start**:
- Image: `onboarding-5` (55% height)
- Header: "Stay present together"
- Subtext: "Make memories that matter. Put the phones away and enjoy the moment."
- Button: "Get Started"

#### Home Screen

```
┌────────────────────────────────────────┐
│ 24pt padding                           │
├────────────────────────────────────────┤
│ [Balance: Xb]                    [⚙️]  │
│                                        │
│                                        │
│               "Hi!"                    │
│  "Time to cherish this moment with     │
│            friends"                    │
│                                        │
│                                        │
│         [campy-mascot image]           │
│         (max width: 280pt)             │
│                                        │
│                                        │
│           ┌──────────────┐             │
│           │    START     │             │
│           │   (140×140)  │             │
│           └──────────────┘             │
│                                        │
│ 64pt spacing                           │
├────────────────────────────────────────┤
│        [  Home  ] [  Wallet  ]         │
│              Tab Bar (80pt)            │
└────────────────────────────────────────┘
```

#### Start Session Sheet

```
┌────────────────────────────────────────┐
│              [Handle]                  │
│                                        │
│       How long can you last?           │
│                                        │
│    ◀ [5] [10] [15] [20] [25] ▶        │
│                min                     │
│                                        │
│     How much are you betting?          │
│                                        │
│    ◀ [5] [10] [15] [20] [25] ▶        │
│                 b                      │
│                                        │
│           ┌──────────────┐             │
│           │      GO      │             │
│           └──────────────┘             │
│                                        │
└────────────────────────────────────────┘
```

**Picker Behavior**:
- Horizontal scroll with snap-to-item
- Selected item: larger font (28pt bold), full opacity
- Unselected items: smaller font (24pt medium), 50% opacity

#### Active Session Screen

```
┌────────────────────────────────────────┐
│       [trees-background image]         │
│       (full bleed, slight dark overlay)│
├────────────────────────────────────────┤
│ [Balance: Xb]        Users: 👤 👤 👤  │
│                                        │
│                                        │
│              15:00                     │
│           (72pt timer)                 │
│                                        │
│          Minutes left                  │
│                                        │
│                                        │
│            20 🪙 On the line           │
│                                        │
│                                        │
└────────────────────────────────────────┘
```

#### Game Ended Overlay

**Won**:
- Background: Black 70% opacity
- Icon: Green circle (120×120) with trophy
- Title: "You Won!" (34pt bold)
- Subtitle: "Congratulations! Your winnings have been added to your wallet."
- Button: "Done"
- Sound: Victory chime
- Haptic: Success

**Lost**:
- Background: Black 70% opacity
- Icon: Red circle (120×120) with X
- Title: "You Lost" (34pt bold)
- Subtitle: "Better luck next time. Stay present!"
- Button: "Done"
- Sound: Loss sound
- Haptic: Error

#### Wallet Screen

```
┌────────────────────────────────────────┐
│ [Balance: Xb]                    [⚙️]  │
│                                        │
│           [coin-mascot image]          │
│              (120×120)                 │
│                                        │
│             3,284b                     │
│          (48pt balance)                │
│                                        │
│   [Add Funds]         [Withdraw]       │
│                      (disabled)        │
│                                        │
├────────────────────────────────────────┤
│        Transaction History             │
│                                        │
│  + Won challenge              +45b     │
│    Today at 2:30 PM                    │
│                                        │
│  - Challenge bet              -20b     │
│    Today at 2:15 PM                    │
│                                        │
│  + Purchased coins           +500b     │
│    Yesterday                           │
│                                        │
├────────────────────────────────────────┤
│        [  Home  ] [  Wallet  ]         │
└────────────────────────────────────────┘
```

#### Add Funds Sheet

```
┌────────────────────────────────────────┐
│              [Handle]                  │
│                                        │
│  ┌────────┐ ┌────────┐ ┌────────┐     │
│  │  🪙    │ │  🪙    │ │  🪙    │     │
│  │  100   │ │  500   │ │  1000  │     │
│  │ $3.99  │ │ $5.99  │ │ $7.99  │     │
│  └────────┘ └────────┘ └────────┘     │
│                                        │
│  ┌────────┐ ┌────────┐ ┌────────┐     │
│  │  🪙    │ │  🪙    │ │  🪙    │     │
│  │  1500  │ │  2000  │ │  2500  │     │
│  │$12.99  │ │$15.99  │ │$20.99  │     │
│  └────────┘ └────────┘ └────────┘     │
│                                        │
│  ┌────────────────────────────────┐   │
│  │        Pay                     │   │
│  └────────────────────────────────┘   │
│                                        │
└────────────────────────────────────────┘
```

### 8.3 Components

#### PillButton

Three variants:
- `primary`: Solid accent background, white text
- `secondary`: Card background, white text
- `outline`: Transparent with accent border

```swift
PillButton(primary: "Start") { /* action */ }
PillButton(secondary: "Cancel") { /* action */ }
PillButton(outline: "Later") { /* action */ }
```

#### CircularButton

Large circular button for main actions (Start, Go).

- Size: 140×140pt
- Outer ring: 180×180pt, accent color, 60% opacity
- Pulsing animation: Scale 1.0 → 1.1 → 1.0

```swift
CircularButton(title: "Start") { /* action */ }
```

#### BalanceView

Two styles:
- `compact`: Small inline display for headers
- `expanded`: Large display for wallet screen

```swift
BalanceView(balance: 3284, style: .compact)
BalanceView(balance: 3284, style: .expanded)
```

#### UserAvatar

Circular avatar with initial and background color.

```swift
UserAvatar(name: "Emma", colorIndex: 0, size: 32)
```

---

## 9. Bluetooth Communication Protocol

### 9.1 Service Definition

| Property | Value |
|----------|-------|
| Service UUID | `CAMPY0001-0000-0000-0000-000000000001` |
| Session Char | `CAMPY0001-0000-0000-0000-000000000002` |
| Control Char | `CAMPY0001-0000-0000-0000-000000000003` |
| Heartbeat Char | `CAMPY0001-0000-0000-0000-000000000004` |

### 9.2 Characteristic Properties

| Characteristic | Properties | Description |
|----------------|------------|-------------|
| Session | Read, Notify | Session info (JSON encoded) |
| Control | Write, Notify | Join/leave/loss events |
| Heartbeat | Notify | Keep-alive pings |

### 9.3 Message Protocol

```swift
enum BluetoothMessage: Codable {
    case sessionInfo(Session)           // Host → All: Current session state
    case playerJoined(SessionParticipant) // Joiner → Host: Join request
    case playerLeft(UUID)               // Any → Host: Participant left
    case gameStart                      // Host → All: Game begins
    case gameEnd(loserId: UUID?)        // Host → All: Game over
    case heartbeat                      // Host ↔ All: Keep-alive
    case loss(UUID)                     // Loser → Host: I lost
}
```

### 9.4 Connection Flow

```
TIME    HOST                                JOINER
────────────────────────────────────────────────────
  0     startAdvertising(session)
        ↓ Advertising...
  1                                         startScanning()
                                            ↓ Scanning...
  2                                         didDiscover(host)
                                            connect(host)
  3     didConnect(joiner)
        ← Connected ─────────────────────── Connected →
  4                                         discoverServices()
                                            discoverCharacteristics()
  5                                         read(sessionChar)
        ← Read request ────────────────────
        sessionInfo(session) ──────────────→
  6                                         write(controlChar, playerJoined)
        ← Join request ────────────────────
  7     onParticipantJoined(participant)
        notify(sessionChar, updatedSession)─→
        ↓ Waiting for start...              ↓ Waiting...
```

### 9.5 Heartbeat Protocol

- **Interval**: 1 second
- **Timeout**: 3 seconds (3 missed heartbeats)
- **On timeout**: Treat as loss, broadcast `playerLeft`

### 9.6 Data Encoding

All messages JSON-encoded via `Codable`:

```swift
let encoder = JSONEncoder()
let data = try encoder.encode(BluetoothMessage.gameStart)
// Send `data` via Bluetooth characteristic
```

---

## 10. In-App Purchases

### 10.1 Product Configuration

| Product ID | Type | Coins | Price (USD) |
|------------|------|-------|-------------|
| `com.campy.coins.100` | Consumable | 100 | $3.99 |
| `com.campy.coins.500` | Consumable | 500 | $5.99 |
| `com.campy.coins.1000` | Consumable | 1000 | $7.99 |
| `com.campy.coins.1500` | Consumable | 1500 | $12.99 |
| `com.campy.coins.2000` | Consumable | 2000 | $15.99 |
| `com.campy.coins.2500` | Consumable | 2500 | $20.99 |

### 10.2 Purchase Flow

```swift
func purchase(_ product: Product) async throws -> Bool {
    let result = try await product.purchase()

    switch result {
    case .success(let verification):
        let transaction = try checkVerified(verification)

        // Credit coins to wallet
        let coins = coinsForProduct(product.id)
        walletManager.addCoins(
            amount: coins,
            description: "Purchased \(coins) coins",
            type: .purchase
        )

        // Finish transaction
        await transaction.finish()
        return true

    case .pending:
        // Transaction pending (e.g., parental approval)
        return false

    case .userCancelled:
        return false

    @unknown default:
        return false
    }
}
```

### 10.3 App Store Connect Setup

1. Create App in App Store Connect
2. Add In-App Purchases (Consumables) with product IDs above
3. Set pricing for each tier
4. Submit for review

---

## 11. Data Persistence & Sync

### 11.1 Local Storage (UserDefaults)

**Keys**:
```swift
userId: String (UUID)
displayName: String
avatarColorIndex: Int
userBalance: Int
hasCompletedOnboarding: Bool
transactions: Data (JSON-encoded [Transaction])
```

### 11.2 CloudKit Schema

**Container**: `iCloud.com.[team-id].campy`

**User Record**:
```
RecordType: CampyUser
Fields:
  - deviceId: String (indexed)
  - displayName: String
  - avatarColorIndex: Int64
  - balance: Int64
  - createdAt: Date
  - modifiedAt: Date
```

**Transaction Record**:
```
RecordType: CampyTransaction
Fields:
  - transactionId: String (indexed)
  - deviceId: String (indexed, for fetching user's transactions)
  - type: String
  - amount: Int64
  - description: String
  - timestamp: Date
```

### 11.3 Sync Strategy

**On app launch**:
1. Load local data from UserDefaults
2. Fetch cloud data from CloudKit
3. Merge: Use higher balance (prevents loss)
4. Save merged data locally

**On balance change**:
1. Save to UserDefaults immediately
2. Queue CloudKit sync (debounced 5s)

**Conflict resolution**:
- Balance: Higher value wins
- Transactions: Union of local + cloud (dedupe by ID)

---

## 12. Security & Anti-Cheat

### 12.1 Loss Detection

**Primary method**: ScenePhase monitoring

```swift
@Environment(\.scenePhase) var scenePhase

.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .inactive || newPhase == .background {
        if gameManager.state == .playing {
            gameManager.reportLoss()
        }
    }
}
```

**Secondary method**: Bluetooth heartbeat
- If host doesn't receive heartbeat for 3 seconds, participant marked as lost

### 12.2 Airplane Mode Enforcement

Checked before game start via `NWPathMonitor`:

```swift
let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    self.isAirplaneModeOn = path.status != .satisfied
}
monitor.start(queue: DispatchQueue.global())
```

### 12.3 Balance Integrity

- Balance stored locally + cloud
- On sync conflict, higher balance wins (prevents unfair loss)
- Transaction history provides audit trail
- All balance changes create transaction records

---

## 13. Error Handling

### 13.1 Bluetooth Errors

| Error | User Message | Recovery |
|-------|--------------|----------|
| Bluetooth Off | "Enable Bluetooth to play" | Show Settings link |
| No Devices Found | "No challenges nearby" | Suggest creating own |
| Connection Lost | "Connection lost" | Auto-retry 3x, then end game |
| Heartbeat Timeout | (Silent) | Mark participant as lost |

### 13.2 Purchase Errors

| Error | User Message | Recovery |
|-------|--------------|----------|
| Network Error | "Check your connection" | Retry button |
| Purchase Cancelled | (Silent) | Dismiss sheet |
| Purchase Failed | "Purchase failed. Try again." | Retry button |
| Not Authorized | "Purchases not allowed" | Inform user |

### 13.3 CloudKit Errors

| Error | Handling |
|-------|----------|
| No Account | Silent (use local only) |
| Network Error | Queue for retry |
| Quota Exceeded | Log, continue local |
| Unknown | Log, continue local |

---

## 14. Testing Strategy

### 14.1 Unit Tests

| Test Suite | Coverage |
|------------|----------|
| `GameManagerTests` | State transitions, timer, payouts |
| `WalletManagerTests` | Balance ops, transactions |
| `SessionTests` | Model methods, computed props |
| `TransactionTests` | Formatting, types |

### 14.2 UI Tests

| Test | Steps |
|------|-------|
| Onboarding completion | Swipe through 5 pages, tap Get Started |
| Start session | Tap Start → Select time/bet → Tap Go |
| Win scenario | Start game → Wait for opponent loss |
| Loss scenario | Start game → Background app |
| Purchase flow | Wallet → Add Funds → Select package → Pay |

### 14.3 Integration Tests

| Test | Method |
|------|--------|
| StoreKit | StoreKit Testing configuration |
| CloudKit | CloudKit development environment |
| Bluetooth | Physical device testing (2+ iPhones) |

### 14.4 Device Testing Matrix

| Device | iOS Version | Test |
|--------|-------------|------|
| iPhone 15 Pro | iOS 18.2 | Full test suite |
| iPhone 14 | iOS 18.2 | Full test suite |
| iPhone SE 3 | iOS 18.2 | Layout + performance |
| iPhone 12 mini | iOS 18.2 | Small screen layout |

---

## 15. Build & Configuration

### 15.1 Info.plist

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Campy uses Bluetooth to connect with nearby friends for phone detox challenges.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Campy uses Bluetooth to host and join phone detox challenges with friends.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### 15.2 Entitlements

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.$(DEVELOPMENT_TEAM).campy</string>
</array>

<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

### 15.3 Xcode Capabilities

Enable in Signing & Capabilities:
- [x] Background Modes
  - [x] Uses Bluetooth LE accessories
  - [x] Acts as Bluetooth LE accessory
- [x] iCloud
  - [x] CloudKit
- [x] In-App Purchase
- [x] Push Notifications (for future use)

### 15.4 Build Settings

| Setting | Value |
|---------|-------|
| iOS Deployment Target | 18.2 |
| Swift Version | 5.9 |
| Build Active Architecture Only (Debug) | Yes |
| Build Active Architecture Only (Release) | No |

---

## 16. Asset Specifications

### 16.1 Required Assets

| Asset | Format | Sizes | Description |
|-------|--------|-------|-------------|
| `AppIcon` | PNG | 1024×1024 | App icon |
| `onboarding-1` | PNG | @1x, @2x, @3x | Campfire circle scene |
| `onboarding-2` | PNG | @1x, @2x, @3x | Phone on campfire |
| `onboarding-3` | PNG | @1x, @2x, @3x | Campy close-up |
| `onboarding-4` | PNG | @1x, @2x, @3x | Standing people |
| `onboarding-5` | PNG | @1x, @2x, @3x | Landscape scene |
| `campy-mascot` | PNG | @1x, @2x, @3x | Tent + campfire (transparent) |
| `coin-mascot` | PNG | @1x, @2x, @3x | Coin character (transparent) |
| `trees-background` | PNG | @1x, @2x, @3x | Forest scene for active game |

### 16.2 Sound Assets

| Sound | File | Duration | Trigger |
|-------|------|----------|---------|
| Victory | `victory.mp3` | ~2s | Game won |
| Loss | `loss.mp3` | ~1s | Game lost |
| Countdown | `beep.mp3` | ~0.3s | Each countdown number |
| Join | `join.mp3` | ~0.5s | Player joined session |

---

## 17. Localization

### 17.1 Supported Languages (v1)

- English (US) - Base

### 17.2 Localization Keys

```swift
// Onboarding
"onboarding.page1.title" = "Put the phone down and pick up the moment."
"onboarding.page1.subtitle" = "Some memories are better lived than scrolled."
// ... etc

// Home
"home.greeting" = "Hi!"
"home.subtitle" = "Time to cherish this moment with friends"
"home.start" = "Start"

// Session
"session.time.question" = "How long can you last?"
"session.bet.question" = "How much are you betting?"
"session.go" = "Go"

// Game
"game.timeleft" = "Minutes left"
"game.ontheline" = "On the line"
"game.won.title" = "You Won!"
"game.won.subtitle" = "Congratulations! Your winnings have been added to your wallet."
"game.lost.title" = "You Lost"
"game.lost.subtitle" = "Better luck next time. Stay present!"

// Wallet
"wallet.balance" = "Your Balance"
"wallet.addfunds" = "Add Funds"
"wallet.withdraw" = "Withdraw"
"wallet.history" = "Transaction History"
```

---

## 18. Analytics Events

### 18.1 Event Definitions (Future)

| Event | Parameters | Trigger |
|-------|------------|---------|
| `onboarding_started` | - | First onboarding page shown |
| `onboarding_completed` | - | "Get Started" tapped |
| `session_created` | duration, bet_amount | Host creates session |
| `session_joined` | duration, bet_amount | Player joins session |
| `game_started` | player_count, duration, total_pot | Game begins |
| `game_ended` | outcome (win/loss), duration_played | Game ends |
| `purchase_started` | product_id, coins | User initiates purchase |
| `purchase_completed` | product_id, coins, price | Purchase successful |
| `purchase_failed` | product_id, error | Purchase failed |

---

## 19. Known Limitations

### 19.1 Technical Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Bluetooth range ~10m | Players must be nearby | By design (social app) |
| Max ~8 Bluetooth connections | Limited player count | Document in UI |
| iOS only | No Android users | Future roadmap |
| Airplane mode required | No notifications during game | Core feature, not bug |

### 19.2 v1 Scope Limitations

| Feature | Status | Notes |
|---------|--------|-------|
| Withdrawals | Disabled | "Coming Soon" alert |
| Custom avatars | Not available | Use color only |
| Game history | Not persisted | Future feature |
| Statistics | Not tracked | Future feature |
| Friends list | Not available | Future feature |

---

## 20. Future Roadmap

### v1.1 - Polish & Insights
- [ ] Settings screen (name change, avatar, sound toggle)
- [ ] Game history (past sessions)
- [ ] Statistics (games played, win rate, total winnings)
- [ ] Improved error handling

### v1.2 - Social
- [ ] Friends list
- [ ] Invite via share sheet
- [ ] Rematch with same players

### v2.0 - Monetization
- [ ] Real money withdrawals (regulatory dependent)
- [ ] Premium subscription (ad-free, exclusive avatars)
- [ ] Achievements & badges

### v2.1 - Expansion
- [ ] Android version
- [ ] Leaderboards
- [ ] Tournaments

---

## Contributing

### Code Style

- SwiftUI + Swift 5.9+
- `@Observable` for state management
- Prefer composition over inheritance
- Keep views < 200 lines
- Extract reusable components

### Commit Convention

```
feat: Add new feature
fix: Fix bug
refactor: Code refactoring
docs: Documentation
test: Add/update tests
chore: Maintenance
```

### PR Process

1. Branch from `main`
2. Implement with tests
3. Ensure build passes
4. Submit PR with description
5. Request review
6. Squash merge

---

*Document maintained by the Campy development team.*
