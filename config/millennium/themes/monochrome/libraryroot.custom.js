// Turns every color in Steam's own stylesheets grey (dark greys darker), so the
// UI is black & white without listing Steam's hashed class names. Images
// (game art, avatars) aren't touched, so they keep their colors.
// Also loaded in the friends/chat windows (friends.custom.js links here).
(() => {
    const COLOR = /(?<!url\(\s*["']?)#([0-9a-f]{8}|[0-9a-f]{6}|[0-9a-f]{3,4})\b|rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)\s*(?:[,/]\s*([\d.]+%?|var\([^)]*\)))?\s*\)/gi;
    const DONE = new WeakSet();

    function grey(r, g, b, a) {
        // Rec. 709 luma, so light colors stay light and dark stay dark
        let v = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        // Darker: Steam's panel greys (below ~100) go near-black, like the
        // rest of the rice; text (lighter) is eased in and then left as is
        if (v <= 100) v *= 0.4;
        else if (v < 160) v = 40 + ((v - 100) * (160 - 40)) / 60;
        v = Math.round(v);
        return a === undefined ? `rgb(${v}, ${v}, ${v})` : `rgba(${v}, ${v}, ${v}, ${a})`;
    }

    function convert(value) {
        return value.replace(COLOR, (_, hex, r, g, b, a) => {
            if (hex) {
                if (hex.length <= 4) hex = [...hex].map((c) => c + c).join("");
                const n = (i) => parseInt(hex.slice(i, i + 2), 16);
                const alpha = hex.length === 8 ? +(n(6) / 255).toFixed(3) : undefined;
                return grey(n(0), n(2), n(4), alpha);
            }
            if (a !== undefined && a.endsWith("%")) a = parseFloat(a) / 100;
            return grey(+r, +g, +b, a);
        });
    }

    function walk(rules) {
        for (const rule of rules) {
            // Whole cssText, not per property: Chromium rejects multi-layer
            // background longhands set one at a time
            const style = rule.style;
            if (style && /#|rgb/i.test(style.cssText)) {
                const next = convert(style.cssText);
                if (next !== style.cssText) style.cssText = next;
            }
            if (rule.cssRules) walk(rule.cssRules);
        }
    }

    function sheet(s) {
        if (DONE.has(s)) return;
        let rules;
        try {
            rules = s.cssRules; // cross-origin sheets throw
        } catch {
            return;
        }
        if (!rules.length) return; // not loaded yet: the load listener retries
        DONE.add(s);
        walk(rules);
    }

    function all(doc) {
        for (const s of doc.styleSheets) sheet(s);
    }

    function watch(doc) {
        all(doc);
        // Steam loads more CSS chunks as pages open
        new MutationObserver(() => all(doc)).observe(doc.head || doc.documentElement, {
            childList: true,
            subtree: true,
        });
        // Stylesheets are added before they're parsed: catch them on load
        doc.addEventListener("load", (e) => {
            if (e.target.tagName === "LINK") all(doc);
        }, true);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", () => watch(document));
    } else {
        watch(document);
    }
})();
