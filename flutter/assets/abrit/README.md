# abritdesk artwork

`wordmark.png` preserves the supplied Abrit logo and tagline. `logo.png` and
`logo.svg` provide the cloud mark for app icons. The original is retained at
`res/abrit/logo-source.jpg`. Regenerate all resources using:

```
python res/abrit/generate_brand_assets.py
```

This regenerates Flutter, Windows executable/tray, Linux, macOS, Android and
iOS icons while retaining package IDs and executable names.
Tray and notification resources use the supplied cloud mark's silhouette.

`servers.png` and `hero-light.png` are independently generated imagegen assets.
Banner prompt:

> Wide 3:1 cinematic photorealistic navy data-center aisle, blue server racks
> concentrated on the right, cyan LEDs and a flowing luminous blue ribbon;
> quieter navy space on the left. No text, logos, interface or watermark.

Light hero prompt: wide 3:1 high-key blue server racks on the right, cyan data
ribbon, airy white and pale blue environment, left side fading into pale blue;
no text, letters, logos, watermark, interface or people. The UI mirrors only
this unlettered background in RTL; all headings are real localized text.

Fonts are bundled from Google Fonts' upstream repository. Their respective
SIL Open Font License files are included beside the font files.
