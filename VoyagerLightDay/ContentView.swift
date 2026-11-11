import SwiftUI
import UserNotifications

/// Voyager Light-Day countdown.
///
/// Voyager 1 becomes the first human-made object one light-day from
/// Earth on Wed, Nov 18, 2026 at 4:16:07 AM CST (10:16:07 UTC),
/// 16.1 billion miles out. At T-0 this app flashes V-G-R in Morse
/// from the torch, the speaker (620 Hz), and the screen, all in sync.
struct ContentView: View {
    /// The crossing, as a fixed UTC instant — never a local-time guess.
    static let targetDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 18
        components.hour = 10
        components.minute = 16
        components.second = 7
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    @StateObject private var player = MorsePlayer()
    @State private var now = Date()
    @State private var firedAtT0 = false
    @State private var ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @AppStorage("voyagerMessage") private var message = MorseCode.defaultMessage
    @AppStorage("voyagerStayAwake") private var stayAwake = true
    @AppStorage("voyagerAutoFlash") private var autoFlashAtT0 = true
    @AppStorage("voyagerReminders") private var remindersOn = true

    private var remaining: TimeInterval { Self.targetDate.timeIntervalSince(now) }
    private var crossed: Bool { remaining <= 0 }

    private var days: Int { max(0, Int(remaining) / 86_400) }
    private var hours: Int { max(0, (Int(remaining) % 86_400) / 3_600) }
    private var minutes: Int { max(0, (Int(remaining) % 3_600) / 60) }
    private var seconds: Int { max(0, Int(remaining) % 60) }

    private var fullSendText: String {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? MorseCode.vgr : "\(MorseCode.vgr) \(trimmed)"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    countdownBoxes
                    targetLine
                    flashPanel
                    playButtons
                    messageSection
                    togglesSection
                    linksSection
                    Text("MikeGyver Studio · Sharing is Caring")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }

            // The screen flash: full-screen white while an element is on.
            if player.flashOn {
                Color.white.ignoresSafeArea()
            }
            // The letter being sent: steady for the whole letter, changing
            // only when the next letter starts. The white flash pulses
            // behind it per dit/dah; between flashes the letter shows
            // white on black, so it never blinks out mid-letter.
            if let letter = player.currentLetter, letter != " " {
                Text(String(letter))
                    .font(.system(size: 160, weight: .black, design: .rounded))
                    .foregroundStyle(player.flashOn ? .black : .white)
            }
        }
        .foregroundStyle(.white)
        .onReceive(ticker) { tick in
            now = tick
            checkT0()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = stayAwake
            checkT0()
            if remindersOn {
                Task { await VoyagerNotifications.requestAndSchedule(target: Self.targetDate) }
            }
        }
        .onChange(of: stayAwake) { _, value in
            UIApplication.shared.isIdleTimerDisabled = value
        }
        .onChange(of: remindersOn) { _, value in
            if value {
                Task { await VoyagerNotifications.requestAndSchedule(target: Self.targetDate) }
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: ["voyager-t-minus-5", "voyager-t-zero"])
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("🛰️")
                .font(.system(size: 44))
            Text("Voyager Light-Day")
                .font(.system(size: 32, weight: .black, design: .rounded))
            Text("Voyager 1 · one light-day away")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var countdownBoxes: some View {
        HStack(spacing: 10) {
            timeBox(value: days, label: "days")
            timeBox(value: hours, label: "hours")
            timeBox(value: minutes, label: "min")
            timeBox(value: seconds, label: "sec")
        }
    }

    private func timeBox(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .black, design: .monospaced))
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var targetLine: some View {
        VStack(spacing: 4) {
            Text(crossed ? "Crossed — Voyager 1 is one light-day away" : "Crossing in \(days) days, \(hours) h \(minutes) m")
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("Wed, Nov 18, 2026 · 4:16:07 AM CST (10:16:07 UTC)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            Text("16.1 billion miles out · light takes a full day to reach it")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var flashPanel: some View {
        VStack(spacing: 8) {
            Text("V  ···−      G  −−·      R  ·−·")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
            if player.isPlaying {
                Text(player.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
                if let letter = player.currentLetter {
                    Text("Sending: \(String(letter))")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
            } else if !player.statusText.isEmpty {
                Text(player.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                Text(crossed ? "T-0 has passed — tap Play to shine it again."
                             : "At T-0 this phone flashes V-G-R by itself.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            if !player.isTorchAvailable {
                Text("No torch on this device (simulator) — screen flash + tone only.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var playButtons: some View {
        VStack(spacing: 10) {
            Button {
                player.playVGRThenMessage(message)
            } label: {
                Label("Play V-G-R Now", systemImage: "flashlight.on.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
            .disabled(player.isPlaying)

            if player.isPlaying {
                Button("Stop") { player.stop() }
                    .buttonStyle(.bordered)
                    .tint(.red)
            } else {
                Button {
                    player.testTone()
                } label: {
                    Label("Test Tone (1 sec)", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.yellow)
            }
            if !player.toneStatus.isEmpty {
                Text(player.toneStatus)
                    .font(.footnote)
                    .foregroundStyle(player.toneStatus.contains("error") ? .red : .white.opacity(0.65))
            }
            Text("Full send (V-G-R + message): about \(Int(MorseCode.duration(for: fullSendText).rounded())) seconds")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your message to Voyager — after V-G-R")
                .font(.headline)
            TextField("CQ VOYAGER KJ5SES 73", text: $message)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: message) { _, newValue in
                    let clean = MorseCode.sanitised(newValue)
                    if clean != newValue { message = clean }
                }
                .disabled(player.isPlaying)
            HStack {
                Text("\(message.count)/\(MorseCode.maxMessageLength) characters")
                    .font(.footnote)
                    .foregroundStyle(message.count >= MorseCode.maxMessageLength ? .red : .white.opacity(0.7))
                Spacer()
                Button("Use mine: CQ VOYAGER KJ5SES 73") {
                    message = MorseCode.defaultMessage
                }
                .font(.footnote)
                .disabled(player.isPlaying)
            }
            Text("Letters, numbers and spaces only — anything Morse can't send is dropped as you type. Leave it blank to send just V-G-R.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var togglesSection: some View {
        VStack(spacing: 12) {
            Toggle("Flash V-G-R automatically at T-0", isOn: $autoFlashAtT0)
            Toggle("Stay awake overnight (keeps the screen on)", isOn: $stayAwake)
            Toggle("Remind me at T-5 minutes and at T-0", isOn: $remindersOn)
        }
        .tint(.yellow)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More")
                .font(.headline)
            Link("MikeGyver countdown page", destination: URL(string: "https://mikegyver-studio.si/voyager-one-light-day/")!)
            Link("NASA — Shine Bright for Voyager's Light-Day", destination: URL(string: "https://science.nasa.gov/mission/voyager/voyager-1/shine-bright-for-voyagers-light-day/")!)
            Link("NASA — What is a light-day?", destination: URL(string: "https://science.nasa.gov/mission/voyager/voyager-1/voyager-1-what-is-a-light-day/")!)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - T-0

    /// Fire once, when the clock crosses T-0 while the app is open —
    /// or on launch, if T-0 passed less than an hour ago.
    private func checkT0() {
        guard autoFlashAtT0, !firedAtT0, !player.isPlaying else { return }
        if now >= Self.targetDate && now < Self.targetDate.addingTimeInterval(3_600) {
            firedAtT0 = true
            player.playVGRThenMessage(message)
        }
    }
}
