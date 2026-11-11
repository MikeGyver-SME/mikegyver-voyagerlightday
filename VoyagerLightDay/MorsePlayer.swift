import AVFoundation
import SwiftUI
import UserNotifications

/// Plays Morse out of the phone three ways at once, in sync:
/// the camera torch, a 620 Hz tone through the speaker, and the
/// full-screen flash in ContentView (driven by `flashOn`).
///
/// The torch and the tone are the real signal — the screen flash is
/// the visible backup when the torch is pointed at the sky, and the
/// only signal in the simulator, which has no torch.
@MainActor
final class MorsePlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var flashOn = false
    @Published var currentLetter: Character? = nil
    @Published var statusText = ""

    private var playTask: Task<Void, Never>?
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    static let toneFrequency = 620.0

    var isTorchAvailable: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch == true
    }

    // MARK: - Public

    /// Play V-G-R, pause a second, then the custom message (if any).
    /// Calling this while a transmission is running restarts it.
    func playVGRThenMessage(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        let full = trimmed.isEmpty ? MorseCode.vgr : "\(MorseCode.vgr) \(trimmed)"
        play(full, label: trimmed.isEmpty ? "Sending V-G-R" : "Sending V-G-R + your message")
    }

    func stop() {
        playTask?.cancel()
        playTask = nil
        setOutput(on: false)
        currentLetter = nil
        isPlaying = false
        statusText = ""
        stopToneEngine()
    }

    // MARK: - Playback

    private func play(_ text: String, label: String) {
        stop()
        isPlaying = true
        statusText = label
        playTask = Task {
            startToneEngine()
            var previousWasLetter = false
            var first = true
            for ch in text {
                if Task.isCancelled { break }
                if ch == " " {
                    currentLetter = " "
                    await hold(on: false, MorseCode.unit * 7)
                    previousWasLetter = false
                    first = false
                    continue
                }
                guard let code = MorseCode.table[ch] else { continue }
                if !first && previousWasLetter {
                    await hold(on: false, MorseCode.unit * 3)
                }
                currentLetter = ch
                for (index, element) in code.enumerated() {
                    if Task.isCancelled { break }
                    if index > 0 {
                        await hold(on: false, MorseCode.unit)
                    }
                    await hold(on: true, element == "." ? MorseCode.unit : MorseCode.unit * 3)
                }
                previousWasLetter = true
                first = false
            }
            setOutput(on: false)
            currentLetter = nil
            isPlaying = false
            statusText = "Done — 73, Voyager 1"
            stopToneEngine()
        }
    }

    /// One on/off step: set torch + tone + screen flash, then wait.
    private func hold(on: Bool, _ duration: TimeInterval) async {
        setOutput(on: on)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    private func setOutput(on: Bool) {
        flashOn = on
        setTorch(on)
        playerNode?.volume = on ? 0.9 : 0.0
    }

    // MARK: - Torch

    private func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // Simulator, or the torch is busy — the screen flash and
            // the tone still carry the signal.
        }
    }

    // MARK: - Tone (620 Hz sine, looped buffer, volume-gated)

    private func startToneEngine() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Tone may fail on a silent / restricted device; torch + screen still run.
        }
        if engine == nil {
            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            node.scheduleBuffer(sineBuffer(frequency: Self.toneFrequency, format: format),
                                at: nil, options: .loops)
            node.volume = 0.0
            self.engine = engine
            self.playerNode = node
        }
        do {
            try engine?.start()
            playerNode?.play()
        } catch {
            // Tone unavailable; torch + screen still run.
        }
    }

    private func stopToneEngine() {
        playerNode?.volume = 0.0
        playerNode?.stop()
        engine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func sineBuffer(frequency: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate / 2) // 0.5 s loop
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            channel[i] = Float(sin(2.0 * .pi * frequency * t) * 0.5)
        }
        return buffer
    }
}

/// The two reminders for the crossing: T-5 minutes and T-0.
enum VoyagerNotifications {
    static func requestAndSchedule(target: Date) async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
        } catch {
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: ["voyager-t-minus-5", "voyager-t-zero"])
        let calendar = Calendar.current
        let reminders: [(id: String, date: Date, title: String, body: String)] = [
            ("voyager-t-minus-5", target.addingTimeInterval(-5 * 60),
             "Voyager 1 is 5 minutes from one light-day",
             "Get outside — at T-0 this phone flashes V-G-R in Morse."),
            ("voyager-t-zero", target,
             "Voyager 1 is one light-day away — right now",
             "V-G-R is flashing from your phone. 73, Voyager 1."),
        ]
        for item in reminders {
            guard item.date > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date),
                repeats: false)
            // Xcode 26 / iOS 26 SDK: add(_:) is async throws, not the
            // old fire-and-forget call. A failed schedule is non-fatal —
            // the in-app T-0 flash still works without the notification.
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}
