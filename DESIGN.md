---
name: oto Android
description: The existing oto identity adapted to native Material 3 Android controls.
colors:
  seed: "#C53D43"
  light-primary: "#AD303B"
  dark-primary: "#FFA5AE"
  light-on-primary: "#FFFFFF"
  dark-on-primary: "#590D1B"
  light-surface: "#FAF7F2"
  dark-surface: "#11131D"
  light-on-surface: "#25211F"
  dark-on-surface: "#F1EAE3"
  light-secondary-text: "#6B605C"
  dark-secondary-text: "#BEB6C5"
  light-container-low: "#F0EBE4"
  dark-container-low: "#1A1C28"
  light-container: "#ECE5DC"
  dark-container: "#222431"
  light-container-high: "#E6DFD7"
  dark-container-high: "#2A2B39"
  light-outline-variant: "#D8CFC6"
  dark-outline-variant: "#45414D"
typography:
  headline-large:
    fontFamily: serif
    fontSize: 38sp
    lineHeight: 1.15
    letterSpacing: -0.8sp
  headline-medium:
    fontFamily: serif
    lineHeight: 1.2
    letterSpacing: -0.5sp
  title-large:
    fontFamily: serif
    fontSize: 23sp
  title-medium:
    fontWeight: 600
  body-medium:
    lineHeight: 1.5
rounded:
  artwork: 12dp
  control: 14dp
  surface-group: 16dp
  chip: 24dp
  sheet-top: 24dp
spacing:
  compact: 8dp
  inline: 12dp
  group: 16dp
  field-inset: 18dp
  preview-inset: 20dp
  gutter: 24dp
  section: 32dp
components:
  button-primary-light:
    backgroundColor: "{colors.light-primary}"
    textColor: "{colors.light-on-primary}"
    rounded: "{rounded.control}"
  button-primary-dark:
    backgroundColor: "{colors.dark-primary}"
    textColor: "{colors.dark-on-primary}"
    rounded: "{rounded.control}"
  button-outlined:
    rounded: "{rounded.control}"
  input-light:
    backgroundColor: "{colors.light-container-low}"
    rounded: "{rounded.control}"
    padding: "{spacing.field-inset}"
  input-dark:
    backgroundColor: "{colors.dark-container-low}"
    rounded: "{rounded.control}"
    padding: "{spacing.field-inset}"
  chip:
    rounded: "{rounded.chip}"
    padding: "{spacing.compact}"
  download-card-light:
    backgroundColor: "{colors.light-container-low}"
    rounded: "{rounded.surface-group}"
    padding: "{spacing.field-inset}"
  download-card-dark:
    backgroundColor: "{colors.dark-container-low}"
    rounded: "{rounded.surface-group}"
    padding: "{spacing.field-inset}"
  mini-player-light:
    backgroundColor: "{colors.light-container}"
    rounded: "{rounded.surface-group}"
  mini-player-dark:
    backgroundColor: "{colors.dark-container}"
    rounded: "{rounded.surface-group}"
---
# oto Android design

## Overview

This Android surface extends the existing oto identity in the parent website: quiet typography, warm light surfaces, indigo dark surfaces, and a red accent. Material 3 supplies native navigation, sheets, fields, chips, dialogs, buttons, semantics, and system Back behavior.

These tokens describe the implemented Flutter theme and recurring components. Measurements use Android logical pixels (dp) and scalable text (sp), not browser CSS. Unspecified properties inherit Flutter Material 3 defaults.

**Key Characteristics:**
- Quiet serif headlines above clear system-sans controls.
- Tonal containers and clipped artwork in independently mapped light and dark themes.
- Native interaction feedback, safe insets, and system accessibility settings.

## Colors

### Primary

The red seed derives remaining Material roles, including primary-container, error, and interaction-state colors. The light/dark primary and on-primary pairs are explicitly mapped in the frontmatter. Use primary for the main action, selected playback details, and relevant icons.

### Neutral

Surface and on-surface supply the page and principal text. Secondary text carries supporting metadata. Low containers group fields, previews, and download cards; containers carry the compact player; high containers carry artwork fallbacks. Outline variant supplies field outlines, chip borders, and dividers.

Use semantic ColorScheme roles rather than screen-specific raw colors. Themes are independently mapped, and the default follows Android.

## Typography

Android system sans is the body/control face; system serif carries oto's quiet headline character. The frontmatter records explicit overrides from `lib/ui/theme.dart`; other sizes and weights inherit Material 3. Headline medium and title large are serif. Title medium is semibold. Body medium has relaxed line height. All type scales with Android settings.

Song-row titles use semibold title-small text and one-line ellipsis; the full player allows up to three title lines. The oto wordmark uses headline-medium styling at 30sp.

## Layout

Phone content has 24dp horizontal gutters. Spacing mostly follows 4dp/8dp increments with observed optical gaps such as 10dp, 14dp, and 18dp. Task groups have clear separation, commonly 24–36dp. Song rows use 56dp artwork. The compact player uses 44dp artwork, a 12dp outer horizontal inset, and an 8dp bottom gap.

Three compact destinations: Home, Downloads, Library. A navigation rail replaces the bar at 700dp. Main content caps at 840dp, player content at 560dp. The app bar is 72dp high and the navigation bar is 76dp high before system insets. Phone is the primary delivery target. Content scrolls under small windows, large text, and the keyboard; safe insets and system Back are retained.

## Elevation & Depth

The app uses tonal layering rather than custom shadows. App-bar and navigation-bar surface tints are disabled. Material 3 retains native route, sheet, dialog, and pressed-state behavior; no custom shadow vocabulary is defined.

Material interaction feedback and route/sheet transitions carry motion. Navigation-bar transitions last 240ms and become immediate under Android's Remove animations setting. No continuous decorative animation. Position updates rebuild only progress/seek components, not the library list. Scrolling song rows are built lazily and artwork is decoded to display size.

## Shapes

Surface groups and the compact player have 16dp corners. Fields and buttons use 14dp corners. Chips and the top corners of sheets use 24dp. Standard artwork uses 12dp corners; the compact player's artwork uses 9dp, and full-player artwork uses 16dp. Album art is always clipped, including failure/loading fallbacks.

## Components

### Buttons and fields

Filled buttons have a 48dp minimum width and 52dp minimum height; outlined buttons have a 48dp minimum width and height. Their remaining color, disabled, and pressed states inherit Material 3. Filled inputs use the low container and 18dp insets, an outline-variant border at rest, and a 2dp primary border on focus.

### Chips and containers

Chips use outline-variant borders, 8dp padding, and no selection checkmark. Material 3 supplies selected state colors. Download cards use the low container with 18dp padding; preview cards use the low container with 20dp padding.

### Navigation and playback

The navigation bar uses the page surface and Material primary-container selection indicator. A mini player opens a separate full-player route with seek, queue, shuffle, and repeat. Song options expose favorites, multiple categories, rename, export, and confirmed deletion.

### Download and collection states

Home prioritizes paste → find → review → download. Progress distinguishes local preparation, audio downloading and MP3 conversion. The active-job copy explains that an Android notification keeps the download running outside oto, and Retry recovers interrupted jobs. Songs become playable only after a complete MP3 is present. Library prioritizes search, category chips, filter/sort, then the song list; empty and filtered states explain the next useful action.

### Settings

Settings begins with local downloads, the installed engine version, a Check for engine updates action and inline update status. It also includes system/light/dark appearance, quality, category management and storage information. Completed songs and cached artwork remain available offline.

## Do's and Don'ts

- **Do** reuse semantic ColorScheme roles and the existing serif/system-sans hierarchy.
- **Do** retain safe insets, scalable text, labeled controls, and native Back behavior.
- **Do** keep artwork and its loading/error fallback inside the same clipped shape.
- **Don't** add continuous decorative animation to task or playback screens.
- **Don't** treat an incomplete download as a playable library item.
