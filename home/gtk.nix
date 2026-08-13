{ pkgs, ... }:

# GTK and Qt theming, and one shared file picker.
#
# ── Why the pickers looked different ────────────────────────────────
# Nothing here was themed at all before, so each toolkit drew its own default:
# Firefox is GTK and opened the GTK chooser, Telegram Desktop is Qt6 and opened
# Qt's. Two different dialogs, both in default grey.
#
# The fix is to route both through the XDG desktop portal and let a single
# backend answer. xdg-desktop-portal-gtk is added in ../modules/sway.nix — the
# session previously had only the wlroots portal, which handles screencast and
# nothing else, so there was no file-chooser backend to share in the first
# place.
#
# With that in place:
#   * Firefox is pointed at the portal by a pref (see ./firefox.nix)
#   * Qt is pointed at it by QT_QPA_PLATFORMTHEME below
# and both then show the same GTK dialog, themed by the CSS here.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  accent = theme.accent;

  # GTK's named colours. Setting these is what reaches the parts of the dialog
  # that are not worth naming individually — entries, headers, the sidebar,
  # selection — and it is far more durable than chasing widget selectors, which
  # get renamed between GTK versions.
  paletteCss = ''
    @define-color theme_bg_color ${colors.background};
    @define-color theme_base_color ${accent.panel};
    @define-color theme_fg_color ${accent.textBright};
    @define-color theme_text_color ${accent.textBright};
    @define-color theme_selected_bg_color ${accent.primary};
    @define-color theme_selected_fg_color ${colors.background};
    @define-color insensitive_fg_color ${accent.muted};
    @define-color insensitive_bg_color ${colors.background};
    @define-color borders ${accent.line};
    @define-color accent_color ${accent.primary};
    @define-color accent_bg_color ${accent.primary};
    @define-color accent_fg_color ${colors.background};
    @define-color window_bg_color ${colors.background};
    @define-color window_fg_color ${accent.textBright};
    @define-color view_bg_color ${accent.panel};
    @define-color view_fg_color ${accent.textBright};
    @define-color headerbar_bg_color ${colors.background};
    @define-color headerbar_fg_color ${accent.textBright};
    @define-color popover_bg_color ${accent.panel};
    @define-color popover_fg_color ${accent.textBright};
    @define-color card_bg_color ${accent.panel};

    /* Square, to match the browser chrome and the window borders sway draws. */
    window, dialog, popover, popover contents, entry, button,
    headerbar, .background {
      border-radius: 0;
    }

    /* The dialog carries the same raster as the terminal and the browser
       chrome — GTK3 does support background-image with a gradient plus
       background-size, so the dot grid tiles here exactly as it does in CSS
       elsewhere. Same 8px pitch, same precomputed dot colour. */
    window, dialog, .background {
      background-color: ${colors.background};
      color: ${accent.textBright};
      background-image: radial-gradient(
        circle, ${accent.rasterOnBg} 0.5px, transparent 0.5px);
      background-size: ${toString theme.dotGap}px ${toString theme.dotGap}px;
      background-repeat: repeat;
    }

    /* The file list. Left transparent so the raster shows through rather than
       being covered by a flat panel. */
    filechooser, filechooser .view, treeview.view, list {
      background-color: transparent;
      color: ${accent.textBright};
    }
    list row {
      background-color: transparent;
      color: ${accent.textBright};
    }

    /* The places sidebar — Home, Downloads, mounted volumes. This is a third
       of the dialog and was the largest thing still arriving in stock grey. */
    placessidebar,
    placessidebar list,
    placessidebar row,
    .sidebar, .sidebar list {
      background-color: transparent;
      color: ${accent.textDim};
    }
    placessidebar row:selected,
    .sidebar row:selected {
      background-color: ${accent.primary};
      color: ${colors.background};
    }
    placessidebar row:hover,
    .sidebar row:hover {
      background-color: ${accent.panel};
      color: ${accent.textBright};
    }
    placessidebar row image {
      color: ${accent.hot};
    }
    treeview.view:selected, list row:selected,
    filechooser .view:selected {
      background-color: ${accent.primary};
      color: ${colors.background};
    }
    treeview.view:hover, list row:hover {
      background-color: ${accent.panel};
    }

    /* The path bar, name entry and search box. */
    entry, .path-bar button {
      background-color: ${accent.panel};
      color: ${accent.textBright};
      border: 1px solid ${accent.line};
    }
    entry:focus {
      border-color: ${accent.primary};
    }

    button {
      background-color: ${accent.panel};
      color: ${accent.textBright};
      border: 1px solid ${accent.line};
    }
    button:hover {
      background-color: ${accent.line};
    }
    button.suggested-action {
      background-color: ${accent.primary};
      color: ${colors.background};
      border-color: ${accent.primary};
    }

    headerbar {
      background-color: ${colors.background};
      color: ${accent.textBright};
      border-bottom: 1px solid ${accent.line};
    }

    scrollbar { background-color: transparent; }
    scrollbar slider { background-color: ${accent.line}; border-radius: 0; }
    scrollbar slider:hover { background-color: ${accent.primary}; }

    /* Selection everywhere else the file chooser uses it — the file list is a
       treeview, which does not inherit the `list row` rules above. */
    treeview.view:selected,
    treeview.view:selected:focus {
      background-color: ${accent.primary};
      color: ${colors.background};
    }
    treeview.view:hover {
      background-color: ${accent.panel};
    }
    treeview.view header button {
      background-color: ${colors.background};
      color: ${accent.textDim};
      border: 0;
      border-bottom: 1px solid ${accent.line};
    }

    /* Controls, so checkboxes and the location toggle pick up the accent
       rather than the theme's stock blue. */
    check:checked, radio:checked, switch:checked {
      background-color: ${accent.primary};
      color: ${colors.background};
      border-color: ${accent.primary};
    }
    separator {
      background-color: ${accent.line};
    }

    /* The dialog's action area (Open / Cancel). */
    .dialog-action-box, .dialog-vbox, messagedialog {
      background-color: transparent;
    }

    /* Tooltips were the last stock-grey surface. */
    tooltip, tooltip.background {
      background-color: ${accent.panel};
      color: ${accent.textBright};
      border: 1px solid ${accent.line};
    }
  '';
in {
  gtk = {
    enable = true;

    # A dark base to build on. The CSS above overrides the colours, but starting
    # from a dark theme means anything the CSS does not reach is at least dark
    # rather than defaulting to light grey.
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    gtk3.extraCss = paletteCss;
    gtk4.extraCss = paletteCss;

    # Pinned rather than left to default, for the same reason as Firefox's
    # configPath: home-manager is mid-migration here and which value you get is
    # keyed off home.stateVersion, so a later bump would silently change it.
    #
    # null is also the correct answer on its own merits — GTK4 apps style
    # themselves through libadwaita and ignore a GTK3 theme name entirely. The
    # GTK4 side of this config is carried by extraCss above, which does work.
    gtk4.theme = null;

    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  # Tells GTK apps to ask the portal rather than opening their own chooser, and
  # tells Qt apps (Telegram) to do the same — which is what makes the two agree.
  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  # Qt needs a platform theme plugin present to honour the variable above.
  home.packages = with pkgs; [
    libsForQt5.qtstyleplugins
    qt6Packages.qt6ct
  ];

  # GTK apps read the colour-scheme preference from dconf, not from the theme
  # name, and ignore the dark theme without it.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };
}
