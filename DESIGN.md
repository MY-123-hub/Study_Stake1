# Design System Inspired by Stripe

## 1. Visual Theme & Atmosphere

Stripe's design language opens with the gradient mesh. A wide horizontal band of pastel cream, sherbet orange, lavender, electric indigo, and ruby pink occupies the upper third of nearly every marketing page — the brand's instantly-recognizable atmospheric backdrop. Type and product UI mockups float above it on `#ffffff` (white), with the gradient acting as both decoration and visual anchor. The lower portion of the page returns to white, with feature explanations on `#f6f9fc` (a barely-tinted cool off-white) and dashboard product mockups composited as faux IDE/console panels in deep navy.

The color system has two primary roles. **Indigo** (`#533afd`) is the brand's signature CTA color, used sparingly: one filled pill per band. **Deep navy** (`#0d253d`) is the universal body text color and the fill of dashboard mockups, the featured pricing tier, and the dark-app surfaces on the dashboard track. Ruby (`#ea2261`) and magenta (`#f96bee`) appear inside the gradient mesh and as accent dots in product UI mockups; they are not used as button colors.

Typography is built around **Sohne** at weight 300 with negative letter-spacing — the brand's editorial-density display signature. Display sizes (32–56px) use -1.4px to -0.64px tracking; body sizes use 0; tabular caption sizes (where money and numerics matter) use the OpenType `tnum` feature plus a tightening -0.36 to -0.42px tracking. The `ss01` stylistic set is enabled across all roles. Use **Inter** (open-source via Google Fonts) at weight 300 with `letter-spacing: -1.4px` and `font-feature-settings: "ss01"` for display tiers — Inter is the closest open-source analogue.

**Key Characteristics:**
- Gradient-mesh backdrop on every marketing hero — cream/orange/lavender/indigo/ruby horizontally washed across the upper third of the page.
- Single-indigo CTA hierarchy: filled `#533afd` pill is the only filled button on marketing surfaces.
- Sohne/Inter thin (weight 300) display tier with negative tracking from -1.4px to -0.2px depending on size.
- Tabular-figure body type (`tnum`) for any cell containing money or numerics — the brand's quiet financial-data signal.
- Dark-app dashboard track: deep navy product UI mockups sit composited above the white canvas.
- Pill-shaped buttons (`9999px` radius) with tight `8px 16px` padding — short, decisive, transactional.
- Cream-band feature cards (`#f5e9d4`) introduce a warm interlude between blue/white sections.

## 2. Color Palette & Roles

### Brand & Accent
- **Indigo** (`#533afd`): Primary CTA color. Filled-pill button, link emphasis, gradient anchor.
- **Indigo Deep** (`#4434d4`): Deeper indigo for gradient mid-stops and press-state.
- **Indigo Press** (`#2e2b8c`): Pressed-state.
- **Indigo Soft** (`#665efd`): Lighter indigo for product-UI accents and chart highlights.
- **Indigo Subdued** (`#b9b9f9`): Pale indigo fill for soft tag background.
- **Brand Dark 900** (`#1c1e54`): Deep navy for featured pricing tier and dashboard chrome.
- **Ruby** (`#ea2261`): Gradient accent and chart highlight; never a button.
- **Magenta** (`#f96bee`): Brighter pink stop in gradient meshes.
- **Lemon** (`#9b6829`): Warm sherbet stop in gradient backdrops.

### Surface
- **Canvas** (`#ffffff`): Default page background.
- **Canvas Soft** (`#f6f9fc`): Cool-tinted off-white for feature bands.
- **Canvas Cream** (`#f5e9d4`): Warm cream feature-band fill.
- **Hairline** (`#e3e8ee`): 1px borders on cards and tables.
- **Hairline Input** (`#a8c3de`): Cooler hairline for form inputs.

### Text
- **Ink** (`#0d253d`): Default body text. Deep navy, never pure black.
- **Ink Secondary** (`#273951`): Secondary text.
- **Ink Mute** (`#64748d`): Helper text, captions, table labels.
- **On Primary** (`#ffffff`): Text on indigo/dark-navy surfaces.

## 3. Typography Rules

### Font Family
- **Primary**: `'Inter', 'SF Pro Display', system-ui, -apple-system, sans-serif`
- **Monospace**: `'Berkeley Mono', ui-monospace, 'SF Mono', Menlo`
- **Font Features**: `"ss01"` globally on body; `"tnum"` on money/numeric cells.

### Hierarchy

| Role | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|--------|-------------|----------------|-------|
| Display XXL | 56px | 300 | 1.03 | -1.4px | Hero headline |
| Display XL | 48px | 300 | 1.15 | -0.96px | Section opener |
| Display LG | 32px | 300 | 1.1 | -0.64px | Card title |
| Display MD | 26px | 300 | 1.12 | -0.26px | Compact card title |
| Heading LG | 22px | 300 | 1.1 | -0.22px | Section heading |
| Heading MD | 20px | 300 | 1.4 | -0.2px | Sub-heading |
| Heading SM | 18px | 300 | 1.4 | 0 | Mini-section label |
| Body LG | 16px | 300 | 1.4 | 0 | Marketing lead |
| Body MD | 15px | 300 | 1.4 | 0 | Default UI body |
| Body Tabular | 14px | 300 | 1.4 | -0.42px | Money / numeric tables (`tnum`) |
| Button MD | 16px | 400 | 1.0 | 0 | Pill button label |
| Button SM | 14px | 400 | 1.0 | 0 | Compact pill label |
| Caption | 13px | 400 | 1.4 | -0.39px | Helper, table labels |
| Micro | 11px | 300 | 1.4 | 0 | Fine print |
| Micro Cap | 10px | 400 | 1.15 | 0.1px | All-caps eyebrow |

### Principles
- **Thin weight is the brand.** Display tiers always render at weight 300.
- **Negative tracking on display.** -1.4px at 56px, scaling proportionally down.
- **Tabular figures for money.** Any cell rendering currency uses `font-feature-settings: "tnum"`.
- **`ss01` globally.** Apply `font-feature-settings: "ss01"` to the body element.

## 4. Component Stylings

### Buttons

**Primary Pill Button**
- Background: `#533afd`
- Text: `#ffffff`
- Typography: 16px weight 400
- Padding: 8px 16px
- Radius: 9999px
- Use: Primary CTAs, submit actions

**Secondary Button**
- Background: `#ffffff`
- Text: `#533afd`
- Border: 1px solid `#533afd`
- Radius: 9999px
- Padding: 8px 16px

**On-Dark Button**
- Background: `#1c1e54`
- Text: `#ffffff`
- Radius: 9999px
- Padding: 8px 16px

### Cards & Containers
- **Feature Card (Light)**: `#ffffff` bg, 32px padding, 12px radius, 1px `#e3e8ee` border
- **Pricing Card**: `#ffffff` bg, 32px padding, 12px radius, 1px `#e3e8ee` border
- **Featured Card (Dark)**: `#1c1e54` bg, `#ffffff` text, 32px padding, 12px radius
- **Cream Band Card**: `#f5e9d4` bg, 32px padding, 12px radius
- **Dashboard Mockup**: `#ffffff` bg, 24px padding, 12px radius, tabular type

### Inputs & Forms
- **Text Input**: `#ffffff` bg, `#0d253d` text, 8px 12px padding, 6px radius, 1px `#a8c3de` border
- **Focus state**: border swaps to `#533afd`

### Navigation
- Top nav floating over gradient hero
- Background: white or transparent
- Links in `#0d253d`
- CTA: filled `button-primary-pill` on the right

### Pills & Tags
- **Soft Tag**: `#b9b9f9` bg, `#4434d4` text, 4px 8px padding, 9999px radius, 10px weight 400

## 5. Layout Principles

### Spacing System
- Base unit: 8px
- Tokens: 2px, 4px, 8px, 12px, 16px, 24px, 32px, 64px
- Section padding: 64–96px on marketing surfaces; 32–48px on dashboard surfaces
- Card internal padding: 32px on feature cards; 24px on dashboard mockups

### Grid & Container
- Marketing pages center in ~1200px container
- Gradient mesh extends edge-to-edge above
- Pricing collapses 4-up → 2-up → 1-up at 1024 / 768 breakpoints

### Border Radius Scale
- 4px: Hairline tags, table chrome
- 6px: Form inputs
- 8px: Compact cards, alerts
- 12px: Pricing cards, feature cards
- 16px: Dashboard product mockup chrome
- 9999px: All buttons, tag pills

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| 0 | Flat | Default surface |
| 1 | `box-shadow: rgba(0,55,112,0.08) 0 1px 3px` | Card lift on white |
| 2 | `box-shadow: rgba(0,55,112,0.08) 0 8px 24px, rgba(0,55,112,0.04) 0 2px 6px` | Floating panels |
| 3 | Gradient mesh backdrop | Primary depth medium |

## 7. Do's and Don'ts

### Do
- Reserve `#533afd` for filled CTAs and inline link emphasis — one filled button per band.
- Apply the gradient mesh to every marketing hero.
- Render display tiers at weight 300 with negative letter-spacing.
- Use `font-feature-settings: "tnum"` on every money / numeric cell.
- Apply `font-feature-settings: "ss01"` globally on the body element.
- Use pill-shaped buttons (9999px radius) everywhere.

### Don't
- Don't bump display weight above 300 — at 400 the brand's editorial air collapses.
- Don't add new accent colors outside the documented gradient stops.
- Don't use indigo as a body-text color — it's a CTA and link color only.
- Don't shrink button padding below `8px 16px`.
- Don't render money cells without `tnum`.
- Don't replace the pill shape with rounded-rectangles for buttons.

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|
| Wide | ≥ 1440px | Full gradient mesh edge-to-edge |
| Desktop | 1024–1440px | Default content max-width; pricing 4-up |
| Tablet | 768–1023px | Pricing 2-up; dashboard composite simplifies |
| Mobile | < 768px | Pricing 1-up; hamburger nav; display drops 56 → 36px |

## 9. Quick Reference

- Primary CTA: `#533afd`
- Page Background: `#ffffff`
- Soft Background: `#f6f9fc`
- Cream Background: `#f5e9d4`
- Body text: `#0d253d`
- Secondary text: `#273951`
- Muted text: `#64748d`
- Border: `#e3e8ee`
- Input Border: `#a8c3de`
- Button Radius: 9999px
- Card Radius: 12px
- Input Radius: 6px
- Font: Inter at weight 300 (display) / 400 (buttons)
