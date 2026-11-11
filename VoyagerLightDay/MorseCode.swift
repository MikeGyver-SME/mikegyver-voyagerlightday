import Foundation

/// Morse code for the Voyager Light-Day app.
///
/// Timing (one unit = 0.25 s, so a dit reads clearly on a phone torch
/// and on camera, a dah is about 0.75 s — the same proportions NASA
/// describes for Shine Bright, scaled to a phone flash):
///   dit = 1 unit on, dah = 3 units on,
///   gap inside a letter = 1 unit off,
///   gap between letters = 3 units off,
///   gap between words = 7 units off.
enum MorseCode {
    static let unit: TimeInterval = 0.25

    /// One step in a transmission: the lamp / tone / screen is either on
    /// or off for `duration` seconds.
    struct Step {
        let on: Bool
        let duration: TimeInterval
    }

    static let table: [Character: String] = [
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".",
        "F": "..-.", "G": "--.", "H": "....", "I": "..", "J": ".---",
        "K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---",
        "P": ".--.", "Q": "--.-", "R": ".-.", "S": "...", "T": "-",
        "U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--",
        "Z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--",
        "4": "....-", "5": ".....", "6": "-....", "7": "--...",
        "8": "---..", "9": "----.",
    ]

    /// The greeting NASA asks everyone to shine: V ...- , G --. , R .-.
    static let vgr = "VGR"

    /// Mike's message to Voyager, exactly 20 characters — the same
    /// message pre-filled in the web V-G-R flasher.
    static let defaultMessage = "CQ VOYAGER KJ5SES 73"

    static let maxMessageLength = 20

    /// Keep only characters Morse can send, upper-cased, within the limit.
    static func sanitised(_ text: String) -> String {
        let cleaned = text.uppercased().filter { table[$0] != nil || $0 == " " }
        return String(cleaned.prefix(maxMessageLength))
    }

    /// Build the on/off schedule for `text`. Letters are separated by
    /// 3 units off, words by 7 units off.
    static func steps(for text: String) -> [Step] {
        var steps: [Step] = []
        let words = text.uppercased().split(separator: " ", omittingEmptySubsequences: false)
        for (wordIndex, word) in words.enumerated() {
            if wordIndex > 0 {
                // Word gap is 7 units off. (The letter loop below only
                // adds the 3-unit gap between letters inside a word,
                // so the full 7 belongs here.)
                steps.append(Step(on: false, duration: unit * 7))
            }
            for (letterIndex, ch) in word.enumerated() {
                if letterIndex > 0 {
                    steps.append(Step(on: false, duration: unit * 3))
                }
                guard let code = table[ch] else { continue }
                for (elementIndex, element) in code.enumerated() {
                    if elementIndex > 0 {
                        steps.append(Step(on: false, duration: unit))
                    }
                    steps.append(Step(on: true, duration: element == "." ? unit : unit * 3))
                }
            }
        }
        return steps
    }

    /// Total seconds a transmission of `text` takes, at the timing above.
    static func duration(for text: String) -> TimeInterval {
        steps(for: text).reduce(0) { $0 + $1.duration }
    }

    /// The letters of `text`, in order, for the on-screen "now sending"
    /// display. Spaces become a pause marker.
    static func letters(for text: String) -> [Character] {
        text.uppercased().filter { table[$0] != nil || $0 == " " }
    }
}
