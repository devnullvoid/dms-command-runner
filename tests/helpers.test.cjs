const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const helpers = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../CommandRunnerHelpers.js'), 'utf8').replace(/^\.pragma library\s*/, ''), helpers);

function run(args, options = {}) {
    const result = spawnSync(args[0], args.slice(1), { encoding: 'utf8', timeout: 10000, ...options });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    return result;
}

test('paste copies exact stdout, including delayed, empty and failed commands', () => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'command-runner-paste-'));
    try {
        const clipboard = path.join(fixture, 'clipboard');
        fs.writeFileSync(path.join(fixture, 'wl-copy'), '#!/bin/sh\n[ "$1" = --type ] && [ "$2" = text/plain ] || exit 1\ncat > "$COMMAND_RUNNER_TEST_CLIPBOARD"\n', { mode: 0o700 });
        const env = { ...process.env, PATH: fixture + ':' + process.env.PATH, COMMAND_RUNNER_TEST_CLIPBOARD: clipboard };
        const cases = [
            ['echo hello', 'hello\n'],
            ["printf 'first\\nsecond\\n\\n'", 'first\nsecond\n\n'],
            ['printf "%s" "quotes: \' and \\" and literal \\$HOME"', 'quotes: \' and " and literal $HOME'],
            ["printf 'hello' | tr a-z A-Z; printf ' error' >&2", 'HELLO'],
            ["sleep 0.1; printf delayed", 'delayed'],
            [':', ''],
            ['false', ''],
            ["printf partial; exit 7", 'partial'],
        ];
        for (const [command, expected] of cases) {
            fs.writeFileSync(clipboard, 'old clipboard');
            run(helpers.pasteArgs(command), { env });
            assert.equal(fs.readFileSync(clipboard, 'utf8'), expected, command);
        }
    } finally {
        fs.rmSync(fixture, { recursive: true });
    }
});

test('completion bounds output and completes only the requested directory', () => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'command-runner-completion-'));
    try {
        fs.mkdirSync(path.join(fixture, 'nested'));
        fs.mkdirSync(path.join(fixture, 'nested', 'directory'));
        fs.writeFileSync(path.join(fixture, 'nested', 'document'), '');
        for (let i = 0; i < 3000; i++)
            fs.writeFileSync(path.join(fixture, `match-${i}`), '');
        const output = run(helpers.completionArgs('ls ./match-'), { cwd: fixture }).stdout;
        assert.equal(output.trimEnd().split('\n').length, 8);
        assert.ok(Buffer.byteLength(output) <= 65536);
        assert.ok(output.split('\n').filter(Boolean).every(line => line.startsWith('ls ./match-')));
        const nested = run(helpers.completionArgs('ls ./nested/d'), { cwd: fixture }).stdout;
        assert.deepEqual(new Set(nested.trimEnd().split('\n')), new Set(['ls ./nested/directory/', 'ls ./nested/document']));
        assert.equal(run(helpers.completionArgs('ls ./absent-'), { cwd: fixture }).stdout, '');
        const commands = run(helpers.completionArgs('prin'), { cwd: fixture }).stdout;
        assert.ok(commands.split('\n').includes('printf'));
        assert.ok(commands.split('\n').filter(Boolean).length <= 8);
        // Queries are passed as data; shell-looking text must never execute.
        run(helpers.completionArgs('ls ./$(touch should-not-exist)'), { cwd: fixture });
        assert.equal(fs.existsSync(path.join(fixture, 'should-not-exist')), false);
    } finally {
        fs.rmSync(fixture, { recursive: true });
    }
});

test('tilde completion supports nested paths without a recursive home cache', () => {
    // Use the real home path instead of changing HOME in a login shell.
    const fixture = fs.mkdtempSync(path.join(os.homedir(), '.command-runner-test-'));
    try {
        fs.mkdirSync(path.join(fixture, 'nested'));
        fs.writeFileSync(path.join(fixture, 'nested', 'document'), '');
        const prefix = '~/'+ path.basename(fixture) + '/nested/do';
        assert.equal(run(helpers.completionArgs('cat ' + prefix)).stdout, 'cat ' + prefix + 'cument\n');
    } finally {
        fs.rmSync(fixture, { recursive: true });
    }
});

test('parser ignores duplicate, exact-query and truncated entries', () => {
    assert.deepEqual(Array.from(helpers.parseCompletions('query\nnext\nnext\ntruncated', 'query')), ['next']);
});
