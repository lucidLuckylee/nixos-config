// Loaded by the Firefox package's AutoConfig, once per browser process.
(() => {
  const pref = "browser.theme.websiteCss.disabled";
  const id = "website-style-toggle";
  const topic = "browser-delayed-startup-finished";

  // Wait until the first browser window has initialized its toolbars.
  const startup = () => {
    Services.obs.removeObserver(startup, topic);
    const { CustomizableUI } = ChromeUtils.importESModule(
      "moz-src:///browser/components/customizableui/CustomizableUI.sys.mjs"
    );
    const icon = "data:image/svg+xml," + encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">' +
      '<path fill="context-fill" fill-rule="evenodd" d="M8 1a7 7 0 1 0 0 14h1a2 2 0 0 0 2-2c0-.6-.3-1.1-.7-1.5-.3-.3-.3-.5-.3-.5h2a3 3 0 0 0 3-3 7 7 0 0 0-7-7Zm0 1.5A5.5 5.5 0 0 1 13.5 8c0 .8-.7 1.5-1.5 1.5h-2c-1.5 0-2 1.6-.8 3 .2.2.3.4.3.5a.5.5 0 0 1-.5.5H8a5.5 5.5 0 1 1 0-11Z"/>' +
      '<g fill="context-fill"><circle cx="5" cy="6" r="1"/><circle cx="8" cy="4.5" r="1"/><circle cx="11" cy="6" r="1"/><circle cx="4.5" cy="9" r="1"/></g></svg>'
    );

    function update(node) {
      if (!node) return;
      const enabled = !Services.prefs.getBoolPref(pref, false);
      node.setAttribute("label", "Website styling");
      node.setAttribute("tooltiptext", enabled
        ? "Website styling on — click to disable"
        : "Website styling off — click to enable");
      node.setAttribute("aria-pressed", String(enabled));
      if (enabled) node.setAttribute("checked", "true");
      else node.removeAttribute("checked");
    }

    CustomizableUI.createWidget({
      id,
      type: "button",
      defaultArea: CustomizableUI.AREA_NAVBAR,
      label: "Website styling",
      tooltiptext: "Toggle website styling",
      onCreated(node) {
        node.style.listStyleImage = 'url("' + icon + '")';
        update(node);
      },
      onCommand() {
        Services.prefs.setBoolPref(pref, !Services.prefs.getBoolPref(pref, false));
      },
    });

    // Keep every window in sync, including changes made through about:config.
    Services.prefs.addObserver(pref, () => {
      for (const instance of CustomizableUI.getWidget(id).instances) {
        update(instance.node);
      }
    });
  };
  Services.obs.addObserver(startup, topic);
})();
