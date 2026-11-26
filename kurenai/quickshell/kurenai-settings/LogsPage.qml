import QtQuick

Page {
    id: page
    title: "Logs and checks"
    kanji: "記"
    subtitle: "Read-only reports for when something does not work. Copy from the boxes with the mouse."

    Card {
        title: "Shell log"
        hint: "What the running shell has printed (errors and warnings first when something is wrong)."
        OutputBox { args: ["logs"]; maxHeight: 320; emptyText: "No shell log (the shell may not have run yet)." }
    }
    Card {
        title: "Health check"
        OutputBox { args: ["validate"]; maxHeight: 360; emptyText: "No answer from validate." }
    }
    Card {
        title: "Status"
        OutputBox { args: ["status"]; maxHeight: 300 }
    }
    Card {
        title: "Debugging in a terminal"
        hint: "Live logs need a terminal, because the shell runs in the foreground there:  kurenai-ctl debug   (Ctrl+C quits). Do not run it from here."
    }
}
