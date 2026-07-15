import SwiftUI
import Subsonic
import CoreText

struct BombBubble: Identifiable {
    let id = UUID()
    var position: CGPoint
    var direction: CGVector
    var angle: CGFloat
    var speed: CGFloat
    var creationTime: Double
}

struct TimerBubble: Identifiable {
    let id = UUID()
    var position: CGPoint
    var direction: CGVector
    var angle: CGFloat
    var speed: CGFloat
    var creationTime: Double
}

struct Coin: Identifiable {
    let id = UUID()
    var position: CGPoint
    var direction: CGVector
    var angle: CGFloat
    var speed: CGFloat
    var creationTime: Double
}

struct GameScreenView: View {
    var onBack: () -> Void

    @State private var timerBubbles: [TimerBubble] = []
    @State private var coins: [Coin] = []
    @State private var coinCount = 0
    @State private var lastCoinSpawnTime: Double = 0.0
    @State private var slowUntil: Double = 0
    @State private var bombBubbles: [BombBubble] = []
    @State private var lastBombSpawnTime: Double = 0.0
    @State private var gameOpacity: Double = 0.0
    @State private var blackFadeOpacity: Double = 0.0
    @State private var bubblePosition: CGPoint = .zero
    @State private var bubbleDragFingerOffset: CGSize? = nil
    @State private var hasPositionedBubble = false
    @State private var isGameStarted = false
    @State private var sineOffset: CGFloat = 0.0
    @State private var showGameText = true
    @State private var titleY: CGFloat = 0.0
    @State private var sineTime: Double = 0.0
    @State private var spikes: [Spike] = []
    @State private var gameTime: Double = 0.0
    @State private var lastSpikeSpawnTime: Double = 0.0
    @State private var isPaused = false
    @State private var bgVolumeLevel: CGFloat = 0.7
    @State private var fxVolumeLevel: CGFloat = 0.7
    @State private var waveOffset: CGFloat = 0.0
    @State private var isShowingFullHelp = false
    @State private var isShowingSettings = false
    @State private var isGameOver = false

    @ObservedObject var bgMusic: SubsonicPlayer
    @ObservedObject var fxMusic: SubsonicPlayer
    @ObservedObject var coinMusic: SubsonicPlayer
    @ObservedObject var waterMusic: SubsonicPlayer

    private let frameStep = 0.016
    private let fadeOutDuration = 0.35
    private let maxSpikes = 50
    private let sineTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            gameContent(in: geometry.size, safeAreaInsets: geometry.safeAreaInsets)
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func gameContent(in playfieldSize: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            backgroundImage(in: playfieldSize, safeAreaInsets: safeAreaInsets)

            if showGameText {
                Image("gametxt1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(playfieldSize.width * 0.82, 340))
                    .position(x: playfieldSize.width / 2, y: playfieldSize.height * 0.28 + titleY)
                    .opacity(gameOpacity)
            }

            if !isGameOver && !isPaused {
                activeGameObjects(in: playfieldSize)
            }

            if isGameStarted && !isPaused && !isGameOver {
                hud(in: playfieldSize, safeAreaInsets: safeAreaInsets)
            }

            if isShowingFullHelp {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(999)

                HelpWindow(showHelp: $isShowingFullHelp, fxMusic: fxMusic)
                    .zIndex(1000)
            } else if isShowingSettings {
                SettingsView(showSettings: $isShowingSettings, bgMusic: bgMusic, fxMusic: fxMusic, coinMusic: coinMusic, waterMusic: waterMusic)
                    .zIndex(1000)
            }

            if isGameOver {
                gameOverOverlay(in: playfieldSize)
            }

            topBar(in: playfieldSize, safeAreaInsets: safeAreaInsets)

            if isPaused && !isShowingFullHelp {
                pauseOverlay(in: playfieldSize)
            }

            Color.black.opacity(blackFadeOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(2000)
        }
        .coordinateSpace(name: "gameArea")
        .onAppear {
            prepareForPlayfield(playfieldSize)
            registerFont(withName: "BigParty4Blue")
            syncVolumeLevelsFromPlayers()
            blackFadeOpacity = 0.0

            withAnimation(.easeInOut(duration: 1.0)) {
                gameOpacity = 1.0
            }
        }
        .onChange(of: playfieldSize) { _, newSize in
            prepareForPlayfield(newSize)
        }
        .onReceive(timer) { _ in
            updateGame(in: playfieldSize)
        }
        .onReceive(sineTimer) { _ in
            updateAnimationAndCollisions(in: playfieldSize)
        }
    }

    @ViewBuilder
    private func activeGameObjects(in playfieldSize: CGSize) -> some View {
        ForEach(spikes) { spike in
            Image("spikeball1")
                .resizable()
                .frame(width: spikeDiameter(in: playfieldSize), height: spikeDiameter(in: playfieldSize))
                .position(spike.position)
        }

        ForEach(coins) { coin in
            coinView(size: coinDiameter(in: playfieldSize))
                .position(coin.position)
        }

        ZStack {
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: bubbleDiameter(in: playfieldSize), height: bubbleDiameter(in: playfieldSize))

            if bubbleDragFingerOffset != nil {
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                    .frame(width: bubbleDiameter(in: playfieldSize), height: bubbleDiameter(in: playfieldSize))
                    .shadow(color: .white.opacity(0.4), radius: 6)
            }

            Image("bubbl")
                .resizable()
                .frame(width: bubbleDiameter(in: playfieldSize), height: bubbleDiameter(in: playfieldSize))
        }
            .contentShape(Circle())
            .gesture(
                DragGesture(coordinateSpace: .named("gameArea"))
                    .onChanged { value in
                        guard !isGameOver else { return }
                        startGameIfNeeded()

                        if bubbleDragFingerOffset == nil {
                            bubbleDragFingerOffset = CGSize(
                                width: bubblePosition.x - value.location.x,
                                height: -fingerControlLift(in: playfieldSize)
                            )
                        }

                        let fingerOffset = bubbleDragFingerOffset ?? .zero
                        let proposedPosition = CGPoint(
                            x: value.location.x + fingerOffset.width,
                            y: value.location.y + fingerOffset.height
                        )
                        bubblePosition = constrainedPoint(
                            proposedPosition,
                            in: playfieldSize,
                            radius: bubbleDiameter(in: playfieldSize) / 2
                        )
                    }
                    .onEnded { _ in
                        bubbleDragFingerOffset = nil
                    }
            )
            .onTapGesture {
                startGameIfNeeded()
            }
            .position(currentBubbleCenter(in: playfieldSize))

        ForEach(bombBubbles) { bomb in
            Image("bombBubbl")
                .resizable()
                .frame(width: bombBubbleDiameter(in: playfieldSize), height: bombBubbleDiameter(in: playfieldSize))
                .position(bomb.position)
        }

        ForEach(timerBubbles) { bubble in
            Image("TimeBubbl")
                .resizable()
                .frame(width: bubbleDiameter(in: playfieldSize), height: bubbleDiameter(in: playfieldSize))
                .position(bubble.position)
        }
    }

    private func hud(in playfieldSize: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        VStack(spacing: 4) {
            Text("Time: \(String(format: "%.1f", gameTime))s")
                .font(.custom("Menlo", size: min(max(playfieldSize.width * 0.06, 20), 28)))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.65), radius: 2, x: 1, y: 1)

            Text("Coins: \(coinCount)")
                .font(.custom("Menlo", size: min(max(playfieldSize.width * 0.045, 16), 32)))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.65), radius: 2, x: 1, y: 1)

            Spacer()
        }
        .padding(.top, safeAreaInsets.top + 80)
        .frame(width: playfieldSize.width, height: playfieldSize.height)
        .zIndex(20)
    }

    private func topBar(in playfieldSize: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        VStack {
            HStack {
                Spacer()

                if isGameStarted && !isGameOver {
                    Button(action: {
                        isPaused.toggle()
                    }) {
                        Image("Pause")
                            .resizable()
                            .frame(width: topButtonSize(in: playfieldSize), height: topButtonSize(in: playfieldSize))
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .zIndex(10)
                }
            }
            .padding(.horizontal, max(34, playfieldSize.width * 0.09))
            .padding(.top, safeAreaInsets.top + 72)

            Spacer()
        }
        .frame(width: playfieldSize.width, height: playfieldSize.height)
        .zIndex(300)
    }

    private func gameOverOverlay(in playfieldSize: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: max(18, playfieldSize.height * 0.035)) {
                Image("gameOvertxt")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(playfieldSize.width * 0.82, 330))
                    .offset(
                        x: sin(CGFloat(sineTime * 1.1)) * 5,
                        y: sin(CGFloat(sineTime * 1.4)) * 6
                    )

                imageButton("gotomenu1", width: min(playfieldSize.width * 0.76, 300)) {
                    fadeOutToMenu()
                }
                .offset(
                    x: sin(CGFloat(sineTime * 1.0 + 0.9)) * 4,
                    y: sin(CGFloat(sineTime * 1.25 + 0.4)) * 4
                )

                imageButton("gotorestart1", width: min(playfieldSize.width * 0.76, 300)) {
                    restartGame(in: playfieldSize)
                }
                .offset(
                    x: sin(CGFloat(sineTime * 1.0 + 1.8)) * 4,
                    y: sin(CGFloat(sineTime * 1.25 + 1.1)) * 4
                )
            }
            .padding(.horizontal, 24)
        }
        .zIndex(1000)
    }

    private func pauseOverlay(in playfieldSize: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: max(18, playfieldSize.height * 0.025)) {
                Spacer(minLength: playfieldSize.height * 0.12)

                imageButton("gotomenu1", width: min(playfieldSize.width * 0.78, 310)) {
                    fadeOutToMenu()
                }

                volumeControl(
                    titleImage: "musicvol",
                    titleWidth: min(playfieldSize.width * 0.82, 340),
                    level: $bgVolumeLevel,
                    playfieldSize: playfieldSize
                ) { level in
                    bgMusic.volume = level
                    
                }

                volumeControl(
                    titleImage: "fxvol",
                    titleWidth: min(playfieldSize.width * 0.62, 260),
                    level: $fxVolumeLevel,
                    playfieldSize: playfieldSize
                ) { level in
                    fxMusic.volume = level
                }

                imageButton("help3", width: min(playfieldSize.width * 0.78, 310)) {
                    withAnimation {
                        isShowingFullHelp = true
                    }
                }

                Spacer(minLength: playfieldSize.height * 0.08)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            syncVolumeLevelsFromPlayers()
        }
        .onReceive(timer) { _ in
            waveOffset += 1
        }
        .zIndex(250)
    }

    private func volumeControl(
        titleImage: String,
        titleWidth: CGFloat,
        level: Binding<CGFloat>,
        playfieldSize: CGSize,
        onChange: @escaping (CGFloat) -> Void
    ) -> some View {
        let trackWidth = min(max(playfieldSize.width - 48, 260), 390)
        let trackHeight = min(max(playfieldSize.height * 0.072, 58), 78)
        let knobSize = min(max(playfieldSize.width * 0.13, 46), 60)
        let visualInset = trackWidth * 0.13
        let minKnobCenterX = visualInset
        let maxKnobCenterX = trackWidth - visualInset
        let trackTravel = max(maxKnobCenterX - minKnobCenterX, 1)
        let knobOffsetX = minKnobCenterX + trackTravel * level.wrappedValue - knobSize / 2

        return VStack(spacing: 12) {
            Image(titleImage)
                .resizable()
                .scaledToFit()
                .frame(width: titleWidth)
                .offset(y: CGFloat(sin(waveOffset * 0.05) * 2))

            ZStack(alignment: .leading) {
                Image("volume1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: trackWidth, height: trackHeight)

                Image("play2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: knobSize)
                    .offset(x: knobOffsetX)
            }
            .frame(width: trackWidth, height: max(trackHeight, knobSize))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedCenterX = min(max(value.location.x, minKnobCenterX), maxKnobCenterX)
                        let newLevel = (clampedCenterX - minKnobCenterX) / trackTravel
                        level.wrappedValue = newLevel
                        onChange(newLevel)
                    }
            )
        }
    }

    private func imageButton(_ imageName: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: width)
        }
        .buttonStyle(.plain)
    }

    private func coinView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .yellow, .orange],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)

            Text("$")
                .font(.system(size: size * 0.55, weight: .black, design: .rounded))
                .foregroundColor(.brown)
        }
        .frame(width: size, height: size)
        .shadow(color: .yellow.opacity(0.5), radius: 5)
    }

    private func backgroundImage(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let width = size.width + safeAreaInsets.leading + safeAreaInsets.trailing + 80
        let height = size.height + safeAreaInsets.top + safeAreaInsets.bottom + 80

        return Image("sea")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .position(x: size.width / 2, y: size.height / 2)
            .clipped()
            .ignoresSafeArea()
    }

    private func fadeOutToMenu() {
        withAnimation(.easeInOut(duration: fadeOutDuration)) {
            blackFadeOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
            onBack()
        }
    }

    private func restartGame(in playfieldSize: CGSize) {
        bubblePosition = defaultBubblePosition(in: playfieldSize)
        hasPositionedBubble = true
        blackFadeOpacity = 0.0
        bubbleDragFingerOffset = nil
        isGameStarted = false
        showGameText = true
        sineTime = 0.0
        sineOffset = 0.0
        spikes.removeAll()
        bombBubbles.removeAll()
        timerBubbles.removeAll()
        coins.removeAll()
        coinCount = 0
        lastCoinSpawnTime = 0.0
        lastBombSpawnTime = 0.0
        slowUntil = 0
        gameTime = 0.0
        lastSpikeSpawnTime = 0.0
        isPaused = false
        isGameOver = false
    }

    private func registerFont(withName name: String) {
        guard let fontURL = Bundle.main.url(forResource: name, withExtension: "ttf") else {
            return
        }

        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }

    private func prepareForPlayfield(_ playfieldSize: CGSize) {
        guard playfieldSize.width > 0 && playfieldSize.height > 0 else { return }

        if !hasPositionedBubble || (!isGameStarted && !isGameOver) {
            bubblePosition = defaultBubblePosition(in: playfieldSize)
            hasPositionedBubble = true
        } else {
            bubblePosition = constrainedPoint(
                bubblePosition,
                in: playfieldSize,
                radius: bubbleDiameter(in: playfieldSize) / 2
            )
        }
    }

    private func startGameIfNeeded() {
        guard !isGameStarted else { return }
        isGameStarted = true
        showGameText = false
    }

    private func updateGame(in playfieldSize: CGSize) {
        guard isGameStarted && !isPaused && !isGameOver else { return }
        guard playfieldSize.width > 0 && playfieldSize.height > 0 else { return }

        gameTime += frameStep
        bubblePosition = constrainedPoint(
            bubblePosition,
            in: playfieldSize,
            radius: bubbleDiameter(in: playfieldSize) / 2
        )

        spawnBombBubbleIfNeeded(in: playfieldSize)
        updateBombBubbles(in: playfieldSize)
        spawnTimerBubbleIfNeeded(in: playfieldSize)
        updateTimerBubbles(in: playfieldSize)
        collectTimerBubbles(in: playfieldSize)
        spawnCoinIfNeeded(in: playfieldSize)
        updateCoins(in: playfieldSize)
        collectCoins(in: playfieldSize)
        spawnSpikeIfNeeded(in: playfieldSize)
        updateSpikes(in: playfieldSize)
    }

    private func updateAnimationAndCollisions(in playfieldSize: CGSize) {
        sineTime += frameStep
        titleY = sin(sineTime * 1.4) * 4
        sineOffset = sin(CGFloat(sineTime * 1.4)) * 4

        guard !isGameOver && isGameStarted && !isPaused else { return }
        handleCollisions(in: playfieldSize)
    }

    private func spawnBombBubbleIfNeeded(in playfieldSize: CGSize) {
        guard bombBubbles.isEmpty else { return }
        guard gameTime > 8 else { return }

        let dangerScore = bombDangerScore(in: playfieldSize)
        let cooldown = dangerScore >= 0.75 ? 7.0 : 14.0
        guard gameTime - lastBombSpawnTime > cooldown else { return }

        let spawnRollLimit: Int
        if dangerScore >= 0.9 {
            spawnRollLimit = 70
        } else if dangerScore >= 0.75 {
            spawnRollLimit = 160
        } else if dangerScore >= 0.55 {
            spawnRollLimit = 420
        } else {
            spawnRollLimit = 900
        }

        guard Int.random(in: 0..<spawnRollLimit) == 0 else { return }

        let start = randomEdgeStart(in: playfieldSize, padding: offscreenSpawnPadding(for: bombBubbleDiameter(in: playfieldSize)))
        let direction = normalized(start.direction)
        let angle = atan2(direction.dy, direction.dx)
        let speed = max(playfieldSize.width, playfieldSize.height) * 0.095

        lastBombSpawnTime = gameTime
        bombBubbles.append(
            BombBubble(
                position: start.position,
                direction: direction,
                angle: angle,
                speed: max(speed, 70),
                creationTime: gameTime
            )
        )
    }

    private func updateBombBubbles(in playfieldSize: CGSize) {
        for i in bombBubbles.indices {
            var bomb = bombBubbles[i]
            let timeSinceCreation = gameTime - bomb.creationTime
            let wave = sin(timeSinceCreation * 3 + bomb.angle) * 12

            bomb.position.x += bomb.direction.dx * bomb.speed * frameStep
            bomb.position.y += bomb.direction.dy * bomb.speed * frameStep
            bomb.position.x += CGFloat(-bomb.direction.dy) * wave * 0.05
            bomb.position.y += CGFloat(bomb.direction.dx) * wave * 0.05

            bombBubbles[i] = bomb
        }

        removeOffscreenBombBubbles(in: playfieldSize)
    }

    private func bombDangerScore(in playfieldSize: CGSize) -> Double {
        guard !spikes.isEmpty else { return 0 }

        let bubbleCenter = currentBubbleCenter(in: playfieldSize)
        let nearestDistance = spikes
            .map { Double(hypot($0.position.x - bubbleCenter.x, $0.position.y - bubbleCenter.y)) }
            .min() ?? .greatestFiniteMagnitude
        let closeDangerRadius = Double(max(playfieldSize.width, playfieldSize.height) * 0.18)
        let proximityScore = max(0, min(1, 1 - nearestDistance / closeDangerRadius))
        let countScore = min(1, Double(spikes.count) / 24.0)
        let timePressure = min(1, gameTime / 45.0)

        return max(proximityScore, countScore * 0.85 + timePressure * 0.15)
    }

    private func spawnTimerBubbleIfNeeded(in playfieldSize: CGSize) {
        guard timerBubbles.count < 2 else { return }
        guard gameTime.truncatingRemainder(dividingBy: 2) < frameStep else { return }

        let start = randomEdgeStart(in: playfieldSize, padding: offscreenSpawnPadding(for: bubbleDiameter(in: playfieldSize)))
        let direction = normalized(start.direction)
        let angle = atan2(direction.dy, direction.dx)
        let speed = max(max(playfieldSize.width, playfieldSize.height) * 0.095, 70)

        timerBubbles.append(
            TimerBubble(
                position: start.position,
                direction: direction,
                angle: angle,
                speed: speed,
                creationTime: gameTime
            )
        )
    }

    private func updateTimerBubbles(in playfieldSize: CGSize) {
        for i in timerBubbles.indices {
            var bubble = timerBubbles[i]
            let timeSinceCreation = gameTime - bubble.creationTime
            let wave = sin(timeSinceCreation * 3 + bubble.angle) * 12

            bubble.position.x += bubble.direction.dx * bubble.speed * frameStep
            bubble.position.y += bubble.direction.dy * bubble.speed * frameStep
            bubble.position.x += CGFloat(-bubble.direction.dy) * wave * 0.05
            bubble.position.y += CGFloat(bubble.direction.dx) * wave * 0.05

            timerBubbles[i] = bubble
        }

        timerBubbles.removeAll { isOffscreen($0.position, in: playfieldSize, padding: bubbleDiameter(in: playfieldSize) * 2) }
    }

    private func collectTimerBubbles(in playfieldSize: CGSize) {
        let bubbleCenter = currentBubbleCenter(in: playfieldSize)
        let collectionDistance = bubbleDiameter(in: playfieldSize)

        for (index, bubble) in timerBubbles.enumerated().reversed() {
            let distance = hypot(bubble.position.x - bubbleCenter.x, bubble.position.y - bubbleCenter.y)
            if distance < collectionDistance {
                slowUntil = gameTime + 5
                timerBubbles.remove(at: index)
                fxMusic.play()
            }
        }
    }

    private func spawnCoinIfNeeded(in playfieldSize: CGSize) {
        let spawnInterval = 1.15
        guard coins.count < 5 && gameTime - lastCoinSpawnTime > spawnInterval else { return }
        lastCoinSpawnTime = gameTime

        let start = randomEdgeStart(in: playfieldSize, padding: offscreenSpawnPadding(for: coinDiameter(in: playfieldSize)))
        let direction = normalized(start.direction)
        let angle = atan2(direction.dy, direction.dx)
        let speed = max(max(playfieldSize.width, playfieldSize.height) * 0.075, 55)

        coins.append(
            Coin(
                position: start.position,
                direction: direction,
                angle: angle,
                speed: speed,
                creationTime: gameTime
            )
        )
    }

    private func updateCoins(in playfieldSize: CGSize) {
        for i in coins.indices {
            var coin = coins[i]
            let timeSinceCreation = gameTime - coin.creationTime
            let wave = sin(timeSinceCreation * 2.2 + coin.angle) * 8

            coin.position.x += coin.direction.dx * coin.speed * frameStep
            coin.position.y += coin.direction.dy * coin.speed * frameStep
            coin.position.x += CGFloat(-coin.direction.dy) * wave * 0.04
            coin.position.y += CGFloat(coin.direction.dx) * wave * 0.04

            coins[i] = coin
        }

        coins.removeAll { isOffscreen($0.position, in: playfieldSize, padding: coinDiameter(in: playfieldSize) * 2) }
    }

    private func collectCoins(in playfieldSize: CGSize) {
        let bubbleCenter = currentBubbleCenter(in: playfieldSize)
        let collectionDistance = (bubbleDiameter(in: playfieldSize) + coinDiameter(in: playfieldSize)) * 0.5

        for (index, coin) in coins.enumerated().reversed() {
            let distance = hypot(coin.position.x - bubbleCenter.x, coin.position.y - bubbleCenter.y)
            if distance < collectionDistance {
                coinCount += 1
                coins.remove(at: index)
                coinMusic.play()
            }
        }
    }

    private func spawnSpikeIfNeeded(in playfieldSize: CGSize) {
        let maxSpawnInterval = 0.5
        let minSpawnInterval = 0.02
        let spawnInterval = max(maxSpawnInterval - gameTime * 0.02, minSpawnInterval)

        guard gameTime - lastSpikeSpawnTime > spawnInterval && spikes.count < maxSpikes else { return }
        lastSpikeSpawnTime = gameTime

        let start = randomEdgeStart(in: playfieldSize, padding: offscreenSpawnPadding(for: spikeDiameter(in: playfieldSize)))
        let direction = normalized(start.direction)
        let angle = atan2(direction.dy, direction.dx)
        let baseSpeed: CGFloat = max(playfieldSize.width, playfieldSize.height) * 0.07
        let maxSpeed: CGFloat = max(playfieldSize.width, playfieldSize.height) * 0.7
        let difficultyScale = min(1.0, CGFloat(gameTime / 60))
        let speed = CGFloat.random(in: baseSpeed...(baseSpeed + (maxSpeed - baseSpeed) * difficultyScale))

        spikes.append(
            Spike(
                position: start.position,
                direction: direction,
                angle: angle,
                speed: speed,
                creationTime: gameTime
            )
        )
    }

    private func updateSpikes(in playfieldSize: CGSize) {
        let isSlowed = gameTime < slowUntil
        let spikeSpeedMultiplier: CGFloat = isSlowed ? 0.4 : 1.0

        for i in spikes.indices {
            var spike = spikes[i]
            let timeSinceCreation = gameTime - spike.creationTime
            let wave = sin(timeSinceCreation * 3 + spike.angle) * 12

            spike.position.x += spike.direction.dx * spike.speed * frameStep * spikeSpeedMultiplier
            spike.position.y += spike.direction.dy * spike.speed * frameStep * spikeSpeedMultiplier
            spike.position.x += CGFloat(-spike.direction.dy) * wave * 0.05
            spike.position.y += CGFloat(spike.direction.dx) * wave * 0.05


            spikes[i] = spike
        }

        spikes.removeAll { isOffscreen($0.position, in: playfieldSize, padding: spikeDiameter(in: playfieldSize) * 2) }
    }

    private func handleCollisions(in playfieldSize: CGSize) {
        let bubbleRadius = bubbleDiameter(in: playfieldSize) / 2
        let bubbleCenter = currentBubbleCenter(in: playfieldSize)

        let bombRadius = bombBubbleDiameter(in: playfieldSize) / 2
        for (index, bomb) in bombBubbles.enumerated().reversed() {
            let distance = hypot(bomb.position.x - bubbleCenter.x, bomb.position.y - bubbleCenter.y)
            if distance < bubbleRadius + bombRadius {
                detonateBombBubble()
                bombBubbles.remove(at: index)
            }
        }

        let spikeRadius = spikeDiameter(in: playfieldSize) / 2
        for spike in spikes {
            let distance = hypot(spike.position.x - bubbleCenter.x, spike.position.y - bubbleCenter.y)
            if distance < bubbleRadius + spikeRadius {
                fxMusic.play()
                isGameOver = true
                isGameStarted = false
                break
            }
        }
    }

    private func detonateBombBubble() {
        // Capture spike positions here later when adding pixel explosion frame animation.
        spikes.removeAll()
        fxMusic.play()
    }

    private func removeOffscreenBombBubbles(in playfieldSize: CGSize) {
        bombBubbles.removeAll { isOffscreen($0.position, in: playfieldSize, padding: bombBubbleDiameter(in: playfieldSize) * 2) }
    }

    private func currentBubbleCenter(in playfieldSize: CGSize) -> CGPoint {
        let proposed = CGPoint(
            x: bubblePosition.x,
            y: bubblePosition.y + (isGameStarted ? 0 : sineOffset)
        )

        return constrainedPoint(proposed, in: playfieldSize, radius: bubbleDiameter(in: playfieldSize) / 2)
    }

    private func defaultBubblePosition(in playfieldSize: CGSize) -> CGPoint {
        CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height * 0.72)
    }

    private func constrainedPoint(_ point: CGPoint, in playfieldSize: CGSize, radius: CGFloat) -> CGPoint {
        let edgePadding = bubbleEdgePadding(in: playfieldSize)
        let minX = radius + edgePadding
        let maxX = max(minX, playfieldSize.width - radius - edgePadding)
        let minY = radius + edgePadding
        let maxY = max(minY, playfieldSize.height - radius - edgePadding)

        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    private func offscreenSpawnPadding(for diameter: CGFloat) -> CGFloat {
        diameter * 2
    }

    private func randomEdgeStart(in playfieldSize: CGSize, padding: CGFloat) -> (position: CGPoint, direction: CGVector) {
        let width = max(playfieldSize.width, 1)
        let height = max(playfieldSize.height, 1)
        let edge = Int.random(in: 0..<8)

        switch edge {
        case 0:
            return (CGPoint(x: -padding, y: CGFloat.random(in: 0...height)), CGVector(dx: 1, dy: CGFloat.random(in: -0.5...0.5)))
        case 1:
            return (CGPoint(x: width + padding, y: CGFloat.random(in: 0...height)), CGVector(dx: -1, dy: CGFloat.random(in: -0.5...0.5)))
        case 2:
            return (CGPoint(x: CGFloat.random(in: 0...width), y: -padding), CGVector(dx: CGFloat.random(in: -0.5...0.5), dy: 1))
        case 3:
            return (CGPoint(x: CGFloat.random(in: 0...width), y: height + padding), CGVector(dx: CGFloat.random(in: -0.5...0.5), dy: -1))
        case 4:
            return (CGPoint(x: -padding, y: -padding), CGVector(dx: 1, dy: 1))
        case 5:
            return (CGPoint(x: width + padding, y: -padding), CGVector(dx: -1, dy: 1))
        case 6:
            return (CGPoint(x: -padding, y: height + padding), CGVector(dx: 1, dy: -1))
        default:
            return (CGPoint(x: width + padding, y: height + padding), CGVector(dx: -1, dy: -1))
        }
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let magnitude = max(sqrt(vector.dx * vector.dx + vector.dy * vector.dy), .leastNonzeroMagnitude)
        return CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)
    }

    private func isOffscreen(_ point: CGPoint, in playfieldSize: CGSize, padding: CGFloat) -> Bool {
        point.x < -padding || point.x > playfieldSize.width + padding || point.y < -padding || point.y > playfieldSize.height + padding
    }

    private func bubbleEdgePadding(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.width * 0.035, 12), 18)
    }

    private func fingerControlLift(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.height * 0.09, 70), 90)
    }

    private func bubbleTouchDiameter(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.width * 0.18, 68), 84)
    }

    private func bubbleDiameter(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.width * 0.105, 36), 46)
    }

    private func coinDiameter(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.width * 0.09, 32), 42)
    }

    private func spikeDiameter(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.width * 0.13, 44), 56)
    }

    private func bombBubbleDiameter(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.width * 0.105, 36), 46)
    }

    private func topButtonSize(in playfieldSize: CGSize) -> CGFloat {
        min(max(playfieldSize.width * 0.1, 36), 46)
    }

    private func syncVolumeLevelsFromPlayers() {
        bgVolumeLevel = min(max(bgMusic.volume, 0), 1)
        fxVolumeLevel = min(max(fxMusic.volume, 0), 1)
    }
}
