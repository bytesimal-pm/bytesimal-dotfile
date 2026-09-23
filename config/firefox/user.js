// Firefox prefs for the monochrome, see-through look (chrome/userChrome.css).
// Linked into the Firefox profile; read on every start.

// Load chrome/userChrome.css and chrome/userContent.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Let the window and new tab page be transparent (blurred by Hyprland)
user_pref("browser.tabs.allow_transparent_browser", true);
// Dark built-in theme underneath the CSS, dark pages where sites support it
user_pref("extensions.activeThemeID", "default-theme@mozilla.org");
user_pref("browser.theme.toolbar-theme", 0);
user_pref("browser.theme.content-theme", 0);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
// Hyprland draws the window border/rounding; no Firefox title bar buttons
user_pref("browser.tabs.inTitlebar", 1);
