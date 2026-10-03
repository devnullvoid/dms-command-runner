const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Quickshell loads the component and handles overlapping completion requests', () => {
    // Quickshell confines local imports to its config root. Copy the component
    // into an isolated config with only the service stub this check needs.
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'command-runner-qml-'));
    try {
        for (const file of ['CommandRunner.qml', 'CommandRunnerHelpers.js'])
            fs.copyFileSync(path.join(__dirname, '..', file), path.join(fixture, file));
        fs.mkdirSync(path.join(fixture, 'Services'));
        fs.copyFileSync(path.join(__dirname, 'Services/qmldir'), path.join(fixture, 'Services/qmldir'));
        fs.copyFileSync(path.join(__dirname, 'Services/ToastService.qml'), path.join(fixture, 'Services/ToastService.qml'));
        fs.mkdirSync(path.join(fixture, 'Documents'));
        fs.writeFileSync(path.join(fixture, 'shell.qml'), fs.readFileSync(path.join(__dirname, 'shell.qml'), 'utf8').replace('import ".." as Plugin', 'import "." as Plugin'));
        const result = spawnSync('qs', ['-p', path.join(fixture, 'shell.qml')], {
            encoding: 'utf8', timeout: 15000,
            env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', COMMAND_RUNNER_TEST_PATH: fixture },
        });
        assert.ifError(result.error);
        assert.equal(result.status, 0, result.stdout + result.stderr);
        assert.match(result.stdout + result.stderr, /PASS: component startup/);
    } finally {
        fs.rmSync(fixture, { recursive: true });
    }
});
