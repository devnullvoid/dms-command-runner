.pragma library

function pasteArgs(command) {
    // Pass the user's shell command as data, so its pipelines/redirections
    // remain inside the inner shell and all stdout reaches wl-copy unchanged.
    return ["sh", "-c", 'sh -c "$1" | wl-copy --type text/plain', "command-runner-paste", command];
}

function completionArgs(query) {
    const script =
        'query="$1"; current="${query##* }"; prefix="${query%"$current"}"; ' +
        'if [ "$prefix" = "$query" ]; then prefix=""; fi; ' +
        'if [[ "$current" == ~* ]]; then expanded_current="${current/#\\~/$HOME}"; else expanded_current="$current"; fi; ' +
        '{ if [[ "$query" != *" "* && "$current" != */* && "$current" != ~* ]]; then ' +
        '  compgen -c -- "$current"; ' +
        'else ' +
        '  compgen -f -- "$expanded_current" | while IFS= read -r candidate; do ' +
        '    output="$candidate"; ' +
        '    if [[ "$current" == ~* ]]; then output="~${candidate#$HOME}"; fi; ' +
        '    if [ -d "$candidate" ]; then output="$output/"; fi; ' +
        '    printf \'%s%s\\n\' "$prefix" "$output"; ' +
        '  done; ' +
        'fi; } | awk \'length($0) && $0 != ENVIRON["COMMAND_RUNNER_QUERY"] && !seen[$0]++ { print; if (++count == 8) exit }\' | head -c 65536';
    // ENVIRON avoids awk interpreting backslash escapes in a -v argument.
    return ["bash", "-lc", 'export COMMAND_RUNNER_QUERY="$1"; ' + script, "command-runner-completion", query];
}

function parseCompletions(text, query) {
    const lines = (text || "").split("\n");
    const items = [];
    const seen = {};
    // Ignore a final partial line if the byte cap was reached.
    for (let i = 0; i < lines.length - 1; i++) {
        const candidate = lines[i];
        if (!candidate || candidate === query || seen[candidate])
            continue;
        seen[candidate] = true;
        items.push(candidate);
        if (items.length === 8)
            break;
    }
    return items;
}
