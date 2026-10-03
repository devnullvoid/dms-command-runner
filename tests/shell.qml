import QtQuick
import Quickshell
import ".." as Plugin

ShellRoot {
    id: testRoot
    property int stage: -1
    property string query: ""
    property var displayedItems: []

    QtObject {
        id: settingsStub
        property var savedHistory: []
        signal requestLauncherUpdate(string pluginId)
        function loadPluginData(pluginId, key, fallback) { return fallback; }
        function savePluginData(pluginId, key, value) {
            if (key === "history")
                savedHistory = value.slice();
        }
        // Match the real launcher's notification contract: only this signal
        // refreshes displayed results after an asynchronous completion.
        onRequestLauncherUpdate: pluginId => {
            if (pluginId !== "commandRunner")
                testRoot.fail("Wrong plugin ID in launcher update");
            testRoot.displayedItems = runner.getItems(testRoot.query);
            testRoot.checkResults();
        }
    }

    Plugin.CommandRunner {
        id: runner
        pluginService: settingsStub
    }

    Component.onCompleted: {
        if (runner.completionProcess.running)
            fail("Completion scanned at startup");
        if (runner.getPasteArgs({action: "background:echo hello"}) !== null)
            fail("Background action unexpectedly offers paste");
        if (runner.getPasteArgs({action: "run:echo hello"}).length !== 5)
            fail("Run action does not provide paste wrapper");
        runner.getPasteArgs({action: "run:echo hello"});
        if (runner.commandHistory.length !== 1 || runner.commandHistory[0] !== "echo hello"
                || settingsStub.savedHistory[0] !== "echo hello")
            fail("Shift+Enter did not persist/deduplicate command history");
        stage = 0;
        search("ech");
        search("prin");
    }

    function search(value) {
        query = value;
        displayedItems = runner.getItems(value);
    }

    function checkResults() {
        if (stage === 0 && runner.completionQuery === "prin") {
            if (!displayedItems.some(item => item.action === "run:printf"))
                return fail("Latest query did not display printf without another keystroke");
            stage = 1;
            Qt.callLater(() => search("ls"));
        } else if (stage === 1 && runner.completionQuery === "ls") {
            if (!displayedItems.some(item => item.icon === "material:tab" && item.action.startsWith("run:ls")))
                return fail("Exact ls query did not display command suggestions");
            stage = 2;
            Qt.callLater(() => search("yazi " + Quickshell.env("COMMAND_RUNNER_TEST_PATH") + "/D"));
        } else if (stage === 2 && runner.completionQuery === query) {
            if (!displayedItems.some(item => item.action === "run:yazi " + Quickshell.env("COMMAND_RUNNER_TEST_PATH") + "/Documents/"))
                return fail("Path suggestions needed an extra keystroke");
            stage = 3;
            Qt.callLater(() => {
                search("ech");
                search("");
                finishTimer.start();
            });
        }
    }

    Timer {
        id: finishTimer
        interval: 750
        onTriggered: {
            if (runner.completionQuery !== "" || runner.completionItems.length || runner.completionProcess.running)
                testRoot.fail("Cleared query received stale suggestions or left a process running");
            console.log("PASS: component startup, paste history, launcher refresh, command/path completion and query clearing");
            Qt.exit(0);
        }
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: testRoot.fail("Completion test timed out");
    }

    function fail(message) {
        console.error("FAIL: " + message);
        Qt.callLater(() => Qt.exit(1));
    }
}
