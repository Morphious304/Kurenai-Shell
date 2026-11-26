import Quickshell

// KURENAI shell entry point. Run with:  qs -c kurenai
// Phase 1: top bar on every screen. Later phases add the quick-settings panel,
// notification centre and launcher as siblings of the Variants below.
ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
}
