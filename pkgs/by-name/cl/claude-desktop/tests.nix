# The app itself cannot run under the build sandbox — buildFHSEnv needs bwrap,
# there is no display, and the payload's binaries are unpatched — so what is
# testable is the install layout.
{
  runCommand,
  claude-desktop,
}:

runCommand "claude-desktop-installed-files" { } ''
  bin=${claude-desktop}/bin/claude-desktop
  [ -x "$bin" ] || { echo "missing or non-executable $bin" >&2; exit 1; }

  # The cwd-normalizing launcher must hand off to the buildFHSEnv wrapper.
  grep -q 'exec .*/bin/\.claude-desktop-fhs' "$bin" \
    || { echo "launcher does not exec the FHS wrapper" >&2; exit 1; }
  [ -x ${claude-desktop}/bin/.claude-desktop-fhs ] \
    || { echo "missing FHS wrapper" >&2; exit 1; }

  # Inside the FHS env, the Electron flags come from the run script.
  grep -q -- '--ozone-platform-hint' ${claude-desktop.runScript} \
    || { echo "run script does not pass --ozone-platform-hint" >&2; exit 1; }

  [ -f ${claude-desktop}/share/applications/com.anthropic.Claude.desktop ] \
    || { echo "missing .desktop entry" >&2; exit 1; }
  [ -n "$(find -L ${claude-desktop}/share/icons -name '*.png' | head -n1)" ] \
    || { echo "no icons installed" >&2; exit 1; }

  [ -f ${claude-desktop.unwrapped}/lib/claude-desktop/claude-desktop ] \
    || { echo "unwrapped payload is missing the main binary" >&2; exit 1; }

  touch $out
''
