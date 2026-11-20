# Tonight design reference

- [Design file](https://www.figma.com/design/GHtxtKhVYQiFi6HP5EP2xD)
- [Tonight screen](https://www.figma.com/design/GHtxtKhVYQiFi6HP5EP2xD?node-id=6-98)
- Screen node: 6:98.
- Custom components: 6:79, 6:83, 6:86, 6:90.
- Source: App/TonightView.swift and App/Theme.swift.
- Figma font: Inter, selected by Alec after SF Pro was reported missing.
- Native font: system typography; reading uses Georgia with Dynamic Type scaling.
- Figma icons: editable Lucide vectors, with license in THIRD_PARTY_NOTICES.md.
- Native icons: SF Symbols.

The screen is composed of editable layers, bound tokens, and component instances.
The primary action remains visible while content scrolls. The first-use
protection state requires setup; no sample effectiveness numbers are shown.

tonight.figma.js records the initial composition. It intentionally refuses to
recreate an existing Tonight screen. Subsequent updates should target its actual
nodes and preserve designer changes.
