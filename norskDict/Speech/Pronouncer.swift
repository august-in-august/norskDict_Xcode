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

    /// Installed Norwegian voices, best quality first (premium > enhanced > default), then by name.
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "nb-NO" }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
    }

    /// The user's chosen voice if it's still installed, otherwise the best installed nb-NO voice
    /// (the system's default pick is often the lowest-quality tier even when a better one is downloaded).
    static func resolveVoice(identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier) { return voice }
        return availableVoices.first ?? AVSpeechSynthesisVoice(language: "nb-NO")
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// `rate` is AVSpeechSynthesizer's 0...1 scale (`AVSpeechUtteranceDefaultSpeechRate` = 0.5);
    /// callers pass the user's Settings > speech speed preference.
    /// `voiceIdentifier` is the user's Settings > voice preference (nil = best installed voice).
    func speak(_ text: String, rate: Double = Double(AVSpeechUtteranceDefaultSpeechRate), voiceIdentifier: String? = nil) {
        guard !text.isEmpty, let voice = Self.resolveVoice(identifier: voiceIdentifier) else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Float(rate)
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
