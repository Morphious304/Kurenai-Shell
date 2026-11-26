pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The ONE audio state. The bar indicators and the quick-settings panel both read from here,
// so the volume, mute state and default devices can never disagree.
// Everything is reactive (PipeWire signals): no polling, no shell commands.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink        // current output
    readonly property var source: Pipewire.defaultAudioSource    // current input

    // PipeWire nodes only expose live volume/mute while tracked.
    PwObjectTracker { objects: [root.sink, root.source].filter(o => !!o) }

    readonly property bool hasSink: !!sink && !!sink.audio
    readonly property real volume: hasSink ? sink.audio.volume : 0
    readonly property bool muted: hasSink ? sink.audio.muted : true

    readonly property bool hasSource: !!source && !!source.audio
    readonly property real micVolume: hasSource ? source.audio.volume : 0
    readonly property bool micMuted: hasSource ? source.audio.muted : true

    function setVolume(v)    { if (hasSink)   sink.audio.volume   = Math.max(0, Math.min(1, v)); }
    function setMicVolume(v) { if (hasSource) source.audio.volume = Math.max(0, Math.min(1, v)); }
    function toggleMute()    { if (hasSink)   sink.audio.muted    = !sink.audio.muted; }
    function toggleMicMute() { if (hasSource) source.audio.muted  = !source.audio.muted; }

    // Hardware devices only (isStream = an application's own stream, not a device).
    function devices(wantSinks) {
        const out = [];
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n.audio && !n.isStream && n.isSink === wantSinks) out.push(n);
        }
        out.sort((a, b) => label(a).localeCompare(label(b)));
        return out;
    }
    readonly property var sinks: devices(true)
    readonly property var sources: devices(false)

    function label(node) { return node.description || node.nickname || node.name; }

    function isDefaultSink(node)   { return !!sink && !!node && node.id === sink.id; }
    function isDefaultSource(node) { return !!source && !!node && node.id === source.id; }

    // Changes the default device. Pipewire.preferredDefaultAudioSink/Source are writable.
    function setDefaultSink(node)   { Pipewire.preferredDefaultAudioSink = node; }
    function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node; }
}
