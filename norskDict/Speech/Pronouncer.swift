import AVFoundation
import Foundation

/// Speaks Norwegian text with Apple's built-in nb-NO voice (per the product plan: "Pronunciation
/// with Apple's built-in Norwegian voice (AVSpeechSynthesizer, nb-NO); Nynorsk uses the same
/// voice" — there's no separate Nynorsk voice, so both dictionaries share nb-NO).
@MainActor
@Observable
final class Pronouncer: NSObject {
    static let shared = Pronouncer()

    private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    /// Whether the nb-NO voice is available on this device. The speak button should hide itself
    /// when this is false (per the product plan's risk mitigation for missing/poor voices).
    static let isVoiceAvailable: Bool = AVSpeechSynthesisVoice(language: "nb-NO") != nil

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard !text.isEmpty, let voice = AVSpeechSynthesisVoice(language: "nb-NO") else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        isSpeaking = true
        synthesizer.speak(utterance)
    }
}

extension Pronouncer: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
