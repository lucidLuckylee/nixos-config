# Named workspace order shared by Sway keybindings and the Quickshell bar.
# Glyph comments identify the otherwise unreadable workspace names.
# `assigns` lists Sway criteria whose windows always open on that workspace,
# so they neither land on the current one nor steal focus from it.
# `urgent = false` stops those windows from ever marking themselves urgent.
{
  named = [
    { key = "space"; name = ""; assigns = [ { app_id = "^firefox$"; } ]; }  # seti-firefox  U+E658
    { key = "t";     name = ""; }                                      # fa-send-o     U+F1D9 — Telegram
    # Browsers driven by coding agents (Playwright's bundled Chromium, native
    # or under XWayland) stay out of the way on their own workspace.
    { key = "p";     name = ""; assigns = [ { app_id = "^chromium"; } { class = "^[Cc]hromium"; } ]; urgent = false; }  # fa-code U+F121 — Agent
  ];
}
