// Theme.qml
import Quickshell
import QtQuick
import Quickshell.Io

QtObject {
    id: parent
    property color bgColor: "#1e1e2e"
    property color fgColor: "#cdd6f4"
    property color accentColor: "#89b4fa"
    property bool lightMode: false
    property string themeMode: "light" // light | dark | auto
    property real modeInterpolation: 1.0 // 0.0=dark, 1.0=light
    property color _scratchColor: bgColor

    function toColor(value) {
        _scratchColor = value
        return _scratchColor
    }

    function srgbToLinear(v) {
        if (v <= 0.04045) return v / 12.92
        return Math.pow((v + 0.055) / 1.055, 2.4)
    }

    function luminance(c) {
        const r = srgbToLinear(c.r)
        const g = srgbToLinear(c.g)
        const b = srgbToLinear(c.b)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    function contrastRatio(a, b) {
        const l1 = luminance(a)
        const l2 = luminance(b)
        const hi = Math.max(l1, l2)
        const lo = Math.min(l1, l2)
        return (hi + 0.05) / (lo + 0.05)
    }

    function bestWalForeground(bg, candidates) {
        let best = candidates[0]
        let bestRatio = 0

        for (let i = 0; i < candidates.length; i++) {
            const ratio = contrastRatio(bg, candidates[i])
            if (ratio > bestRatio) {
                bestRatio = ratio
                best = candidates[i]
            }
        }

        return best
    }

    function darkenColor(c, t) {
        return Qt.rgba(
            c.r * (1 - t),
            c.g * (1 - t),
            c.b * (1 - t),
            1
        )
    }

    function lightenColor(c, t) {
        return Qt.rgba(
            c.r + (1 - c.r) * t,
            c.g + (1 - c.g) * t,
            c.b + (1 - c.b) * t,
            1
        )
    }

    function ensureReadableForeground(bg, base, minContrast) {
        let candidate = base
        let ratio = contrastRatio(bg, candidate)
        if (ratio >= minContrast) return candidate

        const bgIsLight = luminance(bg) > 0.5
        for (let i = 1; i <= 20; i++) {
            const t = i / 20
            candidate = bgIsLight ? darkenColor(base, t) : lightenColor(base, t)
            ratio = contrastRatio(bg, candidate)
            if (ratio >= minContrast) return candidate
        }

        return candidate
    }

    function mixColor(a, b, t) {
        return Qt.rgba(
            a.r * (1 - t) + b.r * t,
            a.g * (1 - t) + b.g * t,
            a.b * (1 - t) + b.b * t,
            1
        )
    }

    function clamp01(v) {
        return Math.max(0, Math.min(1, v))
    }

    function resolvedModeBlend(wallpaperBg) {
        if (themeMode === "light") return clamp01(modeInterpolation)
        if (themeMode === "dark") return clamp01(1 - modeInterpolation)

        const autoLight = luminance(wallpaperBg) > 0.5 ? 1 : 0
        return clamp01((autoLight * 0.7) + (modeInterpolation * 0.3))
    }

    function makeSurfaceColor(accent, wallpaperBg, toneAnchor, modeBlend) {
        // Keep light mode visibly tinted by accent.
        const lightSurface = mixColor(mixColor(wallpaperBg, accent, 0.42), toneAnchor, 0.12)
        // Keep dark mode wallpaper-reactive while deeper.
        const darkSurface = mixColor(mixColor(toneAnchor, accent, 0.30), wallpaperBg, 0.15)
        return mixColor(darkSurface, lightSurface, modeBlend)
    }

    property FileView walFile: FileView {
    id: pywalFile
    path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
    
    watchChanges: true 

    onLoaded: {
        try {
            let colors = JSON.parse(text());
            const nextBg = parent.toColor(colors.special.background)
            const nextFg = parent.toColor(colors.special.foreground)
            const nextAccent = parent.toColor(colors.colors.color4)
            const nextDarkText = parent.toColor(colors.colors.color7)
            const nextLightText = parent.toColor(colors.colors.color15)
            const toneAnchor = parent.toColor(colors.colors.color0)
            const candidateText = [
                nextFg,
                nextDarkText,
                nextLightText,
                parent.toColor(colors.colors.color1),
                parent.toColor(colors.colors.color2),
                parent.toColor(colors.colors.color3),
                parent.toColor(colors.colors.color5),
                parent.toColor(colors.colors.color6),
                parent.toColor(colors.colors.color8),
                parent.toColor(colors.colors.color9),
                parent.toColor(colors.colors.color10),
                parent.toColor(colors.colors.color11),
                parent.toColor(colors.colors.color12),
                parent.toColor(colors.colors.color13),
                parent.toColor(colors.colors.color14)
            ]

            const modeBlend = parent.resolvedModeBlend(nextBg)
            const nextSurface = parent.makeSurfaceColor(nextAccent, nextBg, toneAnchor, modeBlend)
            const baseText = parent.bestWalForeground(nextSurface, candidateText)

            parent.accentColor = nextAccent
            parent.lightMode = modeBlend >= 0.5
            parent.bgColor = nextSurface
            parent.fgColor = parent.ensureReadableForeground(nextSurface, baseText, 7.0)
            console.log("Pywal: Colors loaded successfully.")
        } catch (e) {
            console.log("Pywal Error: " + e)
        }
    }

    onFileChanged: reload()
}}
