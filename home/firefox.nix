{ ... }:

# Firefox, themed to match the rest of the session.
#
# Firefox has no notion of a colour scheme it can be handed, so this works in
# two layers: preferences push it onto its built-in dark theme (which fixes
# menus, the sidebar and every internal about: page), and a userChrome sheet
# then repaints the toolbar, tab strip and address bar in the actual palette.
# Content pages are left alone apart from the blank-page background — recolouring
# the web itself is a reader-mode job, not a theme.
#
# ── Why the profile path is spelled out ─────────────────────────────
# This machine already had a hand-made profile at x6xn4xbs.default carrying
# ~1.3 GB of history, logins and extensions. home-manager defaults a profile's
# directory to its attribute name, so calling this profile anything else would
# have generated a profiles.ini pointing at a brand-new empty directory and
# quietly left the real one orphaned on disk. Naming id/path/name to match what
# was already there means the generated profiles.ini is identical to the
# original and Firefox opens the same profile it always did.
#
# The first rebuild still needs the pre-existing ~/.mozilla/firefox/profiles.ini
# moved aside, because home-manager will not clobber a file it does not own.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  accent = theme.accent;
  dotGap = theme.dotGap;

in {
  programs.firefox = {
    enable = true;

    # Pinned rather than left to default. home-manager is midway through moving
    # this from ~/.mozilla/firefox to $XDG_CONFIG_HOME/mozilla/firefox, and
    # which one you get is keyed off home.stateVersion. The real profile is at
    # the legacy path, so bumping stateVersion to 26.05 later would otherwise
    # silently repoint Firefox at an empty directory. Stating it outright means
    # that bump stays a no-op here.
    configPath = ".mozilla/firefox";

    profiles.default = {
      id = 0;
      name = "default";
      path = "x6xn4xbs.default";
      isDefault = true;

      settings = {
        # Resolve the "System" theme to dark. This is what turns the menus,
        # context menus, sidebar and about: pages dark; userChrome below only
        # reaches the main window's chrome.
        "ui.systemUsesDarkTheme" = 1;
        "browser.theme.toolbar-theme" = 0;   # 0 = dark
        "browser.theme.content-theme" = 0;

        # Paint the gap between navigations in the background colour instead of
        # white. Without this every page load flashes white before it draws,
        # which is very visible against a scheme this dark.
        "browser.display.background_color" = colors.background;

        # Do not let a site's own prefers-color-scheme land on light.
        "layout.css.prefers-color-scheme.content-override" = 0;

        # ── The new tab page ──────────────────────────────────────────
        # about:newtab is a *privileged* page: it renders from
        # resource://activity-stream, and Firefox refuses to apply
        # userContent.css to it. That is why styling it from CSS did nothing and
        # new tabs stayed on Firefox's default #1c1b22 grey instead of the
        # background Ghostty uses.
        #
        # Since the page cannot be restyled, it is switched off. New tabs then
        # land on about:blank, which is not privileged and takes its colour from
        # browser.display.background_color above — the same value the terminal
        # is painted in.
        "browser.newtabpage.enabled" = false;
        "browser.startup.homepage" = "about:blank";
        "browser.startup.page" = 1;

        # Still worth setting: these govern the activity-stream page that the
        # Home button and any restored session tabs can still reach.
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;

        # ── Mechanical ────────────────────────────────────────────────
        # Compact density and no cosmetic animation. These are the supported
        # prefs for "make the chrome tighter and stop it easing about"; doing
        # the same thing from CSS means fighting Firefox's own transitions on
        # every release, so set them here and let userChrome handle only the
        # geometry Firefox does not expose as a pref.
        "browser.uidensity" = 1;              # 0 normal, 1 compact, 2 touch
        "browser.compactmode.show" = true;    # unhide the setting in the UI
        "toolkit.cosmeticAnimations.enabled" = false;
        "browser.tabs.hoverPreview.enabled" = false;
        "browser.urlbar.accessibility.tabToSearch.announceResults" = false;

        # Open the portal's file chooser rather than Firefox's own GTK one, so
        # uploading a file here shows the same dialog Telegram shows. 1 = always;
        # the default of 2 ("auto") only uses the portal inside a sandbox, which
        # this is not, so it would otherwise never trigger.
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };

      # ── Chrome ────────────────────────────────────────────────────
      # Firefox exposes its chrome colours as --lwt-* / --toolbar-* custom
      # properties, the same ones a lightweight theme would set. Overriding
      # those rather than restyling individual widgets is what keeps this from
      # breaking on every Firefox release: the variables are a stable contract,
      # the internal DOM structure is not.
      #
      # The look is deliberately hard-edged: every corner radius is zeroed,
      # separators are 1px hairlines rather than gaps, and the address bar is
      # marked with a flat bracket instead of a soft halo. Firefox ships a
      # rounded, animated chrome that reads as consumer software; squaring it
      # off is what makes it sit next to a tiling WM and a terminal.
      userChrome = ''
        :root {
          /* The vivid set from ./colors.nix rather than the restrained one the
             window manager uses — see the note there. --nx-bg is deliberately
             identical to Ghostty's `background`, so a browser and a terminal
             tiled side by side read as one surface. */
          --nx-bg:      ${colors.background};
          --nx-surface: ${accent.panel};
          --nx-dim:     ${accent.line};
          --nx-fg:      ${accent.textBright};
          --nx-muted:   ${accent.textDim};
          --nx-neon:    ${accent.primary};
          --nx-blue:    ${accent.secondary};
          --nx-hot:     ${accent.hot};

          --nx-raster:  ${accent.rasterOnBg};

          --lwt-accent-color: var(--nx-bg) !important;
          --lwt-text-color: var(--nx-fg) !important;

          --toolbar-bgcolor: var(--nx-bg) !important;
          --toolbar-color: var(--nx-fg) !important;
          /* Firefox 153 spells these *-focus, not *-focus-*. The older
             --toolbar-field-focus-background-color spelling that used to be
             here is not a name anything reads, which is what let the default
             grey through on click. */
          --toolbar-field-background-color: var(--nx-surface) !important;
          --toolbar-field-color: var(--nx-fg) !important;
          --toolbar-field-border-color: var(--nx-dim) !important;

          --tab-selected-bgcolor: var(--nx-surface) !important;
          --tab-selected-textcolor: var(--nx-fg) !important;
          --lwt-tabs-border-color: var(--nx-dim) !important;
          --chrome-content-separator-color: var(--nx-dim) !important;

          --arrowpanel-background: var(--nx-surface) !important;
          --arrowpanel-color: var(--nx-fg) !important;
          --arrowpanel-border-color: var(--nx-dim) !important;

          --sidebar-background-color: var(--nx-bg) !important;
          --sidebar-text-color: var(--nx-fg) !important;

          /* Square off every radius Firefox routes through a variable. Doing
             it here catches most widgets in one go; the handful that hardcode
             their own radius are overridden individually below. */
          --border-radius-small: 0 !important;
          --border-radius-medium: 0 !important;
          --border-radius-large: 0 !important;
          --toolbarbutton-border-radius: 0 !important;
          --tab-border-radius: 0 !important;
          --arrowpanel-border-radius: 0 !important;
          --panel-border-radius: 0 !important;
        }

        /* The stragglers that set a radius directly rather than via a var.
           The address bar is deliberately absent from this list — its shape is
           left stock along with the rest of its geometry. */
        #searchbar,
        .tab-background,
        .toolbarbutton-1 > .toolbarbutton-icon,
        .toolbarbutton-1 > .toolbarbutton-badge-stack,
        #TabsToolbar toolbarbutton > .toolbarbutton-icon,
        .identity-box-button,
        menupopup,
        panel {
          border-radius: 0 !important;
        }

        /* Terminal typeface for the chrome. This is the single biggest lever
           on "mechanical" — the tab titles and URL stop looking like a phone
           app the moment they are set in the same font as the shell. Matches
           the Alacritty family in ./shared.nix. */
        #navigator-toolbox,
        #urlbar,
        .tabbrowser-tab .tab-label,
        .urlbarView-row {
          font-family: "DejaVu Sans Mono", monospace !important;
          font-size: 11px !important;
          letter-spacing: 0.01em;
        }

        /* ── The chrome as a screen surface ──────────────────────────
           The whole toolbox is painted as the same surface the terminal is:
           background #06121A carrying an 8px dot raster at the same pitch. The
           dot colour is precomputed (accent.rasterOnBg) to the exact value
           Ghostty's translucent dot resolves to, so a browser and a terminal
           tiled next to each other are the same screen rather than two things
           that merely agree on a hue.

           Transparency is not done here. Sway already composites every window
           at 0.9 (the `opacity` window rule in ./linux.nix), which is the same
           pass the terminal gets — so the wallpaper shows through the browser
           exactly as far as it shows through the shell. Adding CSS alpha on top
           would double it and only affect the chrome, not the page. */
        #navigator-toolbox {
          background-color: var(--nx-bg) !important;
          background-image: radial-gradient(
            var(--nx-raster) 1px, transparent 1px) !important;
          background-size: ${toString dotGap}px ${toString dotGap}px !important;
          color: var(--nx-fg) !important;
          border-bottom: 1px solid var(--nx-dim) !important;
        }

        /* Toolbars inside the box must not paint over that raster. */
        #TabsToolbar,
        #nav-bar,
        #PersonalToolbar,
        #titlebar {
          background: transparent !important;
        }

        /* Tabs read as cells in a strip: hairline dividers, no gaps, no
           rounding. The selected one is a flat fill with a neon rule beneath
           it — the one lit element on an otherwise unlit panel. */
        .tabbrowser-tab {
          margin-inline: 0 !important;
          border-inline-end: 1px solid var(--nx-dim) !important;
        }
        .tabbrowser-tab .tab-label {
          color: var(--nx-muted) !important;
        }
        .tabbrowser-tab[selected] .tab-label {
          color: var(--nx-neon) !important;
        }
        .tabbrowser-tab[selected] .tab-background {
          background-color: var(--nx-surface) !important;
          border-bottom: 2px solid var(--nx-neon) !important;
        }
        .tabbrowser-tab:not([selected]):hover .tab-background {
          background-color: var(--nx-surface) !important;
        }

        /* ── Address bar ─────────────────────────────────────────────
           Colours only, geometry untouched.

           These are classes, not ids. Firefox 153 rebuilt the address bar to
           share its styles with the search bar and moved the internals from
           #urlbar-background / #urlbar-input / #urlbar-input-container to
           .urlbar-background / .urlbar-input / .urlbar-input-container. The
           ids are simply gone — 0 occurrences in browser.xhtml — so every rule
           written against them silently matched nothing, which is why the bar
           kept its default grey on focus no matter what was set here.
           #urlbar itself does still exist. */
        .urlbar-background,
        #searchbar {
          background-color: var(--nx-surface) !important;
          border: 1px solid var(--nx-dim) !important;
        }
        /* Focused must look identical to unfocused apart from the border.
           Firefox's own rule is

             .urlbar:is([focused], [open]) > .urlbar-background {
               background-color: var(--urlbar-background-background-color-focused);
             }

           and that variable resolves to --toolbar-field-background-color-focus.
           Note the word order: the earlier attempt here set
           --toolbar-field-focus-background-color, which is not a name Firefox
           reads, so the default grey came through untouched. Both the variable
           and the element are pinned below rather than relying on either
           alone. */
        :root {
          --toolbar-field-background-color-focus: ${accent.panel} !important;
          --toolbar-field-border-color-focus: ${accent.primary} !important;
          --urlbar-background-background-color-focused: ${accent.panel} !important;
        }
        .urlbar:is([focused], [open]) > .urlbar-background,
        #urlbar[focused] > .urlbar-background,
        #urlbar[open] > .urlbar-background {
          background-color: var(--nx-surface) !important;
          border-color: var(--nx-neon) !important;
        }

        /* The suggestions panel that drops out of the focused bar. */
        .urlbarView,
        .urlbarView-body-inner,
        .urlbarView-results {
          background-color: var(--nx-surface) !important;
          border-color: var(--nx-dim) !important;
        }
        .urlbar-input,
        #urlbar .urlbar-input-box,
        #searchbar .searchbar-textbox {
          color: var(--nx-fg) !important;
        }

        /* The address bar's geometry is deliberately left alone. An earlier
           revision here fought Firefox's focus-expansion ("megabar") and only
           made it worse — the field ended up spanning the window. Firefox
           moves this machinery between releases and it is not worth chasing;
           the stock dimensions and behaviour are fine. Only its colours are
           set, further down. */

        /* The dropdown of history/search suggestions under the address bar. */
        .urlbarView-row[selected] > .urlbarView-row-inner,
        .urlbarView-row:hover > .urlbarView-row-inner {
          background-color: var(--nx-dim) !important;
        }
        .urlbarView-title strong,
        .urlbarView-url {
          color: var(--nx-neon) !important;
        }

        /* Findbar sits at the bottom and defaults to the light toolbar colour. */
        findbar {
          background-color: var(--nx-bg) !important;
          color: var(--nx-fg) !important;
          border-top: 1px solid var(--nx-dim) !important;
        }

        /* ── Icons, in red ───────────────────────────────────────────
           Firefox draws its toolbar icons as monochrome SVG masks that inherit
           `fill` from the toolbar text colour, so a single fill rule moves
           back/forward/reload, the menu and every extension button at once.

           Red because it is the one hue that stays a distinct class of element
           against this much cyan, and it is the opposite side of the wheel
           from the neon — the pairing the wallpaper uses.

           accent.hot is tuned for this dark background, where it reaches
           5.4:1. (It was briefly swapped for a deeper red while the bar was
           light — on light cyan the neon collapsed to 2.5:1. Back on dark, the
           neon is the right one again.) */
        #navigator-toolbox toolbarbutton .toolbarbutton-icon,
        #navigator-toolbox .urlbar-icon,
        #identity-icon,
        #tracking-protection-icon,
        #page-action-buttons image {
          fill: var(--nx-hot) !important;
          color: var(--nx-hot) !important;
          -moz-context-properties: fill, fill-opacity !important;
          fill-opacity: 0.9 !important;
        }
        #navigator-toolbox toolbarbutton:hover .toolbarbutton-icon {
          fill-opacity: 1 !important;
        }

        /* Hover: a wash of the neon, flat and square. */
        #navigator-toolbox toolbarbutton:hover {
          background-color: color-mix(in srgb, var(--nx-neon) 14%, transparent) !important;
        }

        .urlbar-input::selection,
        #searchbar .searchbar-textbox::selection {
          background-color: var(--nx-neon) !important;
          color: var(--nx-bg) !important;
        }

        /* Bookmarks toolbar rides on the rastered surface. */
        #PlacesToolbarItems > .bookmark-item {
          color: var(--nx-muted) !important;
        }
        #PlacesToolbarItems > .bookmark-item:hover {
          background-color: color-mix(in srgb, var(--nx-neon) 14%, transparent) !important;
          color: var(--nx-fg) !important;
        }

        /* Links and in-chrome accents (menu checkmarks, focus rings). */
        :root {
          --focus-outline-color: var(--nx-neon) !important;
          --link-color: var(--nx-blue) !important;
          accent-color: var(--nx-neon) !important;
        }
      '';

      # ── Content ───────────────────────────────────────────────────
      # Firefox's own blank pages get the full background treatment, because
      # the default white is jarring against a scheme this dark. Real sites
      # keep their own colours and are only given the raster overlay below —
      # recolouring the web itself is a reader-mode job, not a theme.
      userContent = ''
        @-moz-document url("about:blank"),
                       url("about:newtab"),
                       url("about:home"),
                       url("about:privatebrowsing") {
          :root, body {
            background-color: ${colors.background} !important;
            color: ${colors.foreground} !important;
          }
        }

        @-moz-document url-prefix("about:") {
          :root {
            scrollbar-color: ${accent.dim} ${colors.background};
          }
        }

        /* ── Web pages, best effort ──────────────────────────────────
           No overlay and no extension. Overlays cannot tell background from
           content — that is what put dots on video — and the extension wanted
           manual setup that could not live in the flake. What is left is the
           honest CSS-only version, which works on some sites and not others,
           and never breaks the ones it misses.

           Only `html` is repainted. It is the one element guaranteed to sit
           behind everything, so repainting it is always safe: where a site
           paints its own background this is simply covered up and nothing
           changes, and where it does not, the page picks up the theme.

           Forcing `body` and the usual wrappers transparent as well would
           catch many more sites — measured earlier, YouTube needs at least
           seven such selectors — but it is deliberately not done. A site that
           still renders dark-text-on-white would end up with dark text on
           cyan, which is unreadable. Half the sites looking right is a much
           better trade than a handful becoming unusable.

           The three properties below are safe on every site regardless, and
           carry the palette further than the background alone manages. */
        @-moz-document url-prefix("http://"), url-prefix("https://") {
          html {
            background-color: ${accent.panel} !important;
          }
          :root {
            scrollbar-color: ${accent.line} ${accent.panel};
            accent-color: ${accent.primary};
          }
          ::selection {
            background-color: ${accent.primary};
            color: ${colors.background};
          }

          /* ── The raster, as a background rather than a layer ───────
             This is the third attempt and the first correct one. The previous
             two painted a fixed overlay on top of the page, which is why the
             dots landed on video, then on buttons: an overlay is in front of
             everything by definition, and CSS gives no way to cut holes in it.

             Making the raster a *background* inverts the relationship. Every
             element that paints its own background — a button, an image, a
             video, a focused search field — is drawn over its parent's
             background as a matter of normal painting order, so it covers the
             dots without being asked to. Nothing needs listing or excluding;
             "in front of the raster" is simply what content already is.

             The three supporting properties:

             background-attachment: fixed anchors the grid to the viewport
             rather than to each element, so html and body do not produce two
             grids at different offsets — they line up as one.

             background-blend-mode: lighten blends the dots against the
             element's *own* background colour, taking the per-channel maximum.
             On a dark page (github.com is rgb(13,17,23)) the dots come
             through; on a light one white stays white and they vanish, which
             is the right answer for a site that never went dark.

             Only html and body are touched. Those two reliably carry a real
             background colour, which the blend needs; going further down into
             wrappers risks clobbering sprite and hero background-images, for
             very little gain. Where a site paints an opaque wrapper over body
             — YouTube's ytd-app — no dots appear, which is the acceptable
             failure. */
          html, body {
            background-image: radial-gradient(
              ${accent.rasterDot} 1px, transparent 1px) !important;
            background-size: ${toString dotGap}px ${toString dotGap}px !important;
            background-attachment: fixed !important;
            background-repeat: repeat !important;
            background-blend-mode: lighten !important;
          }
        }
      '';
    };
  };
}
