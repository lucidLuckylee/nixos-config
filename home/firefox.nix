{ pkgs, ... }:

# Firefox theme and preferences. Preserve the existing profile directory
# so history, logins and extensions remain available.

let
  theme = import ./colors.nix;
  inherit (theme) colors accent dotGap;

in {
  programs.firefox = {
    enable = true;

    # A native toolbar button controls the same live CSS preference. AutoConfig
    # needs access to Firefox's UI modules to register the button.
    package = pkgs.firefox.override (old: {
      extraAutoConfig = (old.extraAutoConfig or "") + ''
        pref("general.config.sandbox_enabled", false);
      '';
      extraPrefs = (old.extraPrefs or "") + builtins.readFile ./firefox/website-style-button.js;
    });

    # Set a default rather than a user.js value, which would reset the toggle
    # on every start. Firefox persists the user's choice in prefs.js.
    policies.Preferences."browser.theme.websiteCss.disabled" = {
      Value = false;
      Status = "default";
    };

    # Keep the existing profile location across Home Manager default changes.
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

        # Use about:blank for new tabs so userContent.css can theme them.
        "browser.newtabpage.enabled" = false;
        "browser.startup.homepage" = "about:blank";
        "browser.startup.page" = 1;

        # Still worth setting: these govern the activity-stream page that the
        # Home button and any restored session tabs can still reach.
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;

        # Use compact density and reduced animation through supported preferences.
        "browser.uidensity" = 1;              # 0 normal, 1 compact, 2 touch
        "browser.compactmode.show" = true;    # unhide the setting in the UI
        "toolkit.cosmeticAnimations.enabled" = false;
        "browser.tabs.hoverPreview.enabled" = false;
        "browser.urlbar.accessibility.tabToSearch.announceResults" = false;

        # Always use the shared portal file picker (1 = always, 2 = sandbox only).
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };

      # Theme Firefox through its colour variables and targeted widget overrides.
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
          --tab-selected-bgcolor: var(--nx-surface) !important;
          --tab-selected-textcolor: var(--nx-fg) !important;
          --lwt-tabs-border-color: var(--nx-dim) !important;
          --chrome-content-separator-color: var(--nx-dim) !important;

          --sidebar-background-color: var(--nx-bg) !important;
          --sidebar-text-color: var(--nx-fg) !important;
        }

        /* Keep shared popup tokens out of the stock address-bar menu. */
        panel:not(.searchmode-switcher-panel),
        menupopup {
          --arrowpanel-background: var(--nx-surface) !important;
          --arrowpanel-color: var(--nx-fg) !important;
          --arrowpanel-border-color: var(--nx-dim) !important;

          --panel-border-radius: 0 !important;
          --arrowpanel-border-radius: 0 !important;
        }

        #TabsToolbar,
        #PersonalToolbar,
        findbar {
          --border-radius-small: 0 !important;
          --border-radius-medium: 0 !important;
          --border-radius-large: 0 !important;
          --toolbarbutton-border-radius: 0 !important;
          --tab-border-radius: 0 !important;
        }

        /* Square off themed widgets without touching address-bar controls. */
        .tab-background,
        .toolbarbutton-1:not(#urlbar *) > .toolbarbutton-icon,
        .toolbarbutton-1:not(#urlbar *) > .toolbarbutton-badge-stack,
        #TabsToolbar toolbarbutton > .toolbarbutton-icon,
        menupopup,
        panel:not(.searchmode-switcher-panel) {
          border-radius: 0 !important;
        }

        /* Terminal typeface for the themed tab and bookmarks toolbars. */
        #TabsToolbar,
        #PersonalToolbar,
        .tabbrowser-tab .tab-label {
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

        /* Address bar, search-engine picker and suggestions use Firefox defaults. */

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
        #navigator-toolbox toolbarbutton:not(#urlbar toolbarbutton) .toolbarbutton-icon {
          fill: var(--nx-hot) !important;
          color: var(--nx-hot) !important;
          -moz-context-properties: fill, fill-opacity !important;
          fill-opacity: 0.9 !important;
        }
        #navigator-toolbox toolbarbutton:not(#urlbar toolbarbutton):hover .toolbarbutton-icon {
          fill-opacity: 1 !important;
        }

        /* Hover: a wash of the neon, flat and square. */
        #navigator-toolbox toolbarbutton:not(#urlbar toolbarbutton):hover {
          background-color: color-mix(in srgb, var(--nx-neon) 14%, transparent) !important;
        }

        /* Bookmarks toolbar rides on the rastered surface. */
        #PlacesToolbarItems > .bookmark-item {
          color: var(--nx-muted) !important;
        }
        #PlacesToolbarItems > .bookmark-item:hover {
          background-color: color-mix(in srgb, var(--nx-neon) 14%, transparent) !important;
          color: var(--nx-fg) !important;
        }

        /* Accents for themed controls, leaving address-bar focus styling stock. */
        #TabsToolbar,
        #PersonalToolbar,
        findbar,
        panel:not(.searchmode-switcher-panel),
        menupopup {
          --focus-outline-color: var(--nx-neon) !important;
          --link-color: var(--nx-blue) !important;
          accent-color: var(--nx-neon) !important;
        }
      '';

      # Style internal blank pages and apply the content tint below.
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
          /* Toggle website styling in about:config; a missing pref leaves it on. */
          @media not -moz-pref("browser.theme.websiteCss.disabled") {
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
        }
      '';
    };
  };
}
