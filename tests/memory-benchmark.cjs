// Optional reproducible comparison against a pre-fix commit.
// Uses a synthetic tree and isolated Quickshell configs; never scans real HOME.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, execFileSync } = require('node:child_process');

const repo = path.join(__dirname, '..');
const baseline = process.argv[2] || '5c2cab4';
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'command-runner-memory-'));

async function measure(name, component, original) {
    const config = path.join(fixture, name);
    fs.mkdirSync(config);
    fs.cpSync(path.join(__dirname, 'Services'), path.join(config, 'Services'), { recursive: true });
    fs.writeFileSync(path.join(config, 'CommandRunner.qml'), component);
    fs.copyFileSync(path.join(repo, 'CommandRunnerHelpers.js'), path.join(config, 'CommandRunnerHelpers.js'));
    const query = 'ls ' + path.join(fixture, 'tree', 'branch-00', 'item-');
    fs.writeFileSync(path.join(config, 'shell.qml'), `
import QtQuick
import Quickshell
import "." as Plugin
ShellRoot {
    Plugin.CommandRunner {
        id: runner
        pluginService: QtObject {
            function loadPluginData(pluginId, key, fallback) { return fallback; }
            function savePluginData(pluginId, key, value) {}
        }
    }
    Component.onCompleted: ${original ? '{}' : `runner.getItems(${JSON.stringify(query)})`}
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (${original ? '!runner.homePathCacheProcess.running && runner.homePathCache.length > 0' : 'runner.completionQuery.length > 0 && !runner.completionProcess.running'}) {
                console.log("BENCH_READY entries=" + ${original ? 'runner.homePathCache.length' : 'runner.completionItems.length'});
                stop();
            }
        }
    }
}
`);
    return new Promise((resolve, reject) => {
        const child = spawn('qs', ['-p', path.join(config, 'shell.qml')], {
            env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', COMMAND_RUNNER_BENCH_ROOT: path.join(fixture, 'tree') },
            stdio: ['ignore', 'pipe', 'pipe'],
        });
        let output = '';
        let measured = null;
        const deadline = setTimeout(() => child.kill('SIGTERM'), 20000);
        const consume = chunk => {
            output += chunk;
            const match = output.match(/BENCH_READY entries=(\d+)/);
            if (!match || measured)
                return;
            const status = fs.readFileSync(`/proc/${child.pid}/status`, 'utf8');
            measured = { name, entries: Number(match[1]), rssKiB: Number(status.match(/VmRSS:\s+(\d+)/)[1]) };
            child.kill('SIGTERM');
        };
        child.stdout.on('data', consume);
        child.stderr.on('data', consume);
        child.on('error', reject);
        child.on('exit', () => {
            clearTimeout(deadline);
            if (measured)
                resolve(measured);
            else
                reject(new Error(output));
        });
    });
}

(async () => {
    try {
        const tree = path.join(fixture, 'tree');
        fs.mkdirSync(tree);
        const seed = path.join(fixture, 'seed');
        fs.writeFileSync(seed, '');
        for (let branch = 0; branch < 10; branch++) {
            const directory = path.join(tree, 'branch-' + String(branch).padStart(2, '0'));
            fs.mkdirSync(directory);
            for (let i = 0; i < 5000; i++)
                fs.linkSync(seed, path.join(directory, 'item-' + String(i).padStart(5, '0') + '-' + 'x'.repeat(100)));
        }
        const oldSource = execFileSync('git', ['show', baseline + ':CommandRunner.qml'], { cwd: repo, encoding: 'utf8' });
        assert.match(oldSource, /homePathCacheProcess/, 'Choose a baseline commit with the old home-path cache.');
        const before = await measure('before', oldSource.replaceAll('$HOME', '$COMMAND_RUNNER_BENCH_ROOT'), true);
        const after = await measure('after', fs.readFileSync(path.join(repo, 'CommandRunner.qml'), 'utf8'), false);
        console.log(JSON.stringify({ syntheticFiles: 50000, before, after, savedKiB: before.rssKiB - after.rssKiB }, null, 2));
    } finally {
        fs.rmSync(fixture, { recursive: true });
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
