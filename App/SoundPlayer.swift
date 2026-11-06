import AVFoundation
import BreakBarCore

/// Plays the three bundled sounds. Volume 0 means "off". Files are made by scripts/make-sounds.py.
@MainActor
final class SoundPlayer {
    private let windup = SoundPlayer.load("windup")
    private let ding = SoundPlayer.load("ding")
    private let ticking: AVAudioPlayer? = {
        let p = SoundPlayer.load("tick")
        p?.numberOfLoops = -1               // loop forever; stopped explicitly
        return p
    }()

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    /// Keeps volumes in step with the settings (also while the ticking is running).
    func apply(_ s: TimerSettings) {
        windup?.volume = Float(s.windupVolume)
        ding?.volume = Float(s.dingVolume)
        ticking?.volume = Float(s.tickingVolume)
        if s.tickingVolume == 0 { ticking?.pause() }
    }

    func play(_ effect: TimerEffect, settings s: TimerSettings) {
        apply(s)
        switch effect {
        case .playWindup: if s.windupVolume > 0 { restart(windup) }
        case .playDing: if s.dingVolume > 0 { restart(ding) }
        case .startTicking: if s.tickingVolume > 0 { ticking?.play() }
        case .stopTicking: ticking?.stop(); ticking?.currentTime = 0
        default: break
        }
    }

    /// For the "test" feel when moving a volume slider.
    func preview(_ sound: PreviewSound, settings s: TimerSettings) {
        apply(s)
        switch sound {
        case .windup: restart(windup)
        case .ding: restart(ding)
        case .ticking: restart(ticking, stopAfter: 2)
        }
    }

    enum PreviewSound { case windup, ding, ticking }

    private func restart(_ p: AVAudioPlayer?, stopAfter: TimeInterval? = nil) {
        guard let p else { return }
        p.currentTime = 0
        p.play()
        if let stopAfter {
            DispatchQueue.main.asyncAfter(deadline: .now() + stopAfter) { p.stop() }
        }
    }
}
