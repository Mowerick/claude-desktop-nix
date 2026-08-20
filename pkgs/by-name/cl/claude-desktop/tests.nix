# The app itself cannot run under the build sandbox — buildFHSEnv needs bwrap,
# there is no display, and the payload's binaries are unpatched — so what is
# testable is the install layout. Every command below is an assertion; the
# builder runs under `set -e`, and `set -x` names the one that failed.
{
  runCommand,
  claude-desktop,
}:

runCommand "claude-desktop-installed-files" { } ''
  set -x

  # The cwd-normalizing launcher must hand off to the buildFHSEnv wrapper.
  test -x ${claude-desktop}/bin/claude-desktop
  test -x ${claude-desktop}/bin/.claude-desktop-fhs
  grep -q 'exec .*/bin/\.claude-desktop-fhs' ${claude-desktop}/bin/claude-desktop

  # Inside the FHS env, the Electron flags come from the run script.
  grep -q -- '--ozone-platform-hint' ${claude-desktop.runScript}

  test -f ${claude-desktop}/share/applications/com.anthropic.Claude.desktop
  find -L ${claude-desktop}/share/icons -name '*.png' | grep -q .

  test -f ${claude-desktop.unwrapped}/lib/claude-desktop/claude-desktop

  touch $out
''
