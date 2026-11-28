import Quickshell

// KURENAI lock screen: a SEPARATE Quickshell config from the main shell, on purpose:
//   * an error in the bar/panels can never stop you from locking, and the reverse,
//   * it is always running, so locking is instant (an IPC call, no start-up delay).
// Run by kurenai-lock-supervisor (restarts it if it crashes). IPC:
//   qs -c kurenai-lock ipc call lock lock      lock now
//   qs -c kurenai-lock ipc call lock status    "locked" | "unlocked"
ShellRoot {
    LockController {}
}
