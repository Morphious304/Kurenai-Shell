pragma Singleton
import QtQuick
import Quickshell

// What the on-screen display shows right now. ONE overlay, ONE state: a new event replaces the
// previous one and restarts the timer, so repeated key presses never stack overlays.
//
// It does not keep its own copy of any value: volume/mic come straight from Audio, brightness from
// System, media from Media, so the OSD can never disagree with the bar or quick settings.
//
// Triggers (all automatic):
//   volume / mute / mic mute   <- Audio changes (also when changed by your wpctl keybinds)
//   media play/pause, track    <- Media changes (also when changed by playerctl keybinds)
//   brightness                 <- System.brightnessChangedExternally (udev backlight events: Fn keys,
//                                 brightnessctl, auto-dim). The IPC call `osd brightness` still works as a
//                                 fallback for machines without udevadm (see `kurenai-ctl media-binds`).
Singleton {
    id: root

    property string kind: ""            // volume | mic | brightness | media
    property string icon: ""
    property real level: -1             // 0..1, or -1 = no bar (text only)
    property bool muted: false
    property string title: ""
    property string detail: ""

    readonly property bool shown: hideTimer.running
    Timer { id: hideTimer; interval: Config.osdTimeout }

    // ---- quiet periods --------------------------------------------------------
    readonly property real loadedAt: Date.now()
    property real suppressUntil: 0
    function quiet(ms) { suppressUntil = Math.max(suppressUntil, Date.now() + ms); }
    // PipeWire/MPRIS settle right after start-up; a panel being open already shows the value.
    function canShow() { return Date.now() > loadedAt + 2500 && Date.now() > suppressUntil && !UiState.anyOpen; }

    function show(k, ic, lvl, isMuted, ttl, det) {
        kind = k; icon = ic; level = lvl; muted = isMuted; title = ttl; detail = det;
        hideTimer.restart();
    }

    // ---- volume / microphone ----------------------------------------------------------
    function showVolume() {
        if (!Config.osdVolume || !canShow() || !Audio.hasSink) return;
        const pct = Math.round(Audio.volume * 100);
        const ic = Audio.muted || Audio.volume <= 0 ? Theme.icons.volOff : Audio.volume < 0.5 ? Theme.icons.volDown : Theme.icons.volUp;
        show("volume", ic, Audio.volume, Audio.muted, "Volume", Audio.muted ? "Muted" : pct + "%");
    }
    function showMic() {
        if (!Config.osdMic || !canShow() || !Audio.hasSource) return;
        show("mic", Audio.micMuted ? Theme.icons.micOff : Theme.icons.mic, -1, Audio.micMuted,
             "Microphone", Audio.micMuted ? "Muted" : "On");
    }
    Connections {
        target: Audio
        function onVolumeChanged() { root.showVolume(); }
        function onMutedChanged()  { root.showVolume(); }
        function onMicMutedChanged() { root.showMic(); }
        // switching the default device changes "the volume" without the user turning it
        function onSinkChanged()   { root.quiet(900); }
        function onSourceChanged() { root.quiet(900); }
    }

    // ---- brightness: asked for by the keybind through IPC, shown once the fresh value is read ----
    property bool brightnessWanted: false
    function requestBrightness() {
        if (!Config.osdBrightness) return;
        brightnessWanted = true;
        System.refreshBrightness();
    }
    Connections {
        target: System
        function onBrightnessChangedExternally() {
            if (!Config.osdBrightness || !root.canShow()) return;
            root.show("brightness", Theme.icons.sun, System.brightness, false, "Brightness", Math.round(System.brightness * 100) + "%");
        }
        function onBrightnessRead() {
            if (!root.brightnessWanted) return;
            root.brightnessWanted = false;
            if (!root.canShow()) return;
            root.show("brightness", Theme.icons.sun, System.brightness, false, "Brightness", Math.round(System.brightness * 100) + "%");
        }
    }

    // ---- media ------------------------------------------------------------------------------------
    Connections {
        target: Media
        function onPlayingChanged() {
            if (!Config.osdMediaPlayPause || !Media.has || !root.canShow()) return;
            root.show("media", Media.playing ? Theme.icons.play : Theme.icons.pause, -1, false,
                      Media.playing ? "Playing" : "Paused", Media.title);
        }
        function onTitleChanged() {
            if (!Config.osdMediaTrack || !Media.has || Media.title === "" || !root.canShow()) return;
            root.show("media", Theme.icons.music, -1, false, Media.title, Media.artist);
        }
    }
}
