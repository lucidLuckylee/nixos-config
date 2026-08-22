# The named workspaces, in the order they should appear on the bar.
#
# Sway keeps two kinds of workspace: numbered ones, which it orders by their
# number, and named ones, which it keeps in the order they were first opened.
# That second rule is why this list exists — without it the bar shows Telegram
# before Firefox on one login and after it on the next, depending on which was
# opened first, and the numbered workspaces are not first at all: a named
# workspace has no number, and "no number" sorts ahead of 1.
#
# Read by two places, which is the point of the file:
#   ./linux.nix       — binds Mod+<key> and Mod+Shift+<key> for each
#   ./quickshell.nix  — hands the order to the bar (../home/quickshell/Workspaces.qml)
#
# The names are Nerd Font glyphs, so they are one character each and unreadable
# in a diff. The comments are what they are:
{
  named = [
    { key = "space"; name = ""; }  # seti-firefox  U+E658
    { key = "t";     name = ""; }  # fa-send-o     U+F1D9 — Telegram
  ];
}
