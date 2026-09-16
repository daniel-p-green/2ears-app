---
format: 1080x1080
duration: 45s
message: "A private tap on the wrist the moment you've talked past the point of listening, and nobody else in the room knows."
arc: PAS → mechanism → privacy → intents → score → brand
audience: "People who walk into rooms where the right move is to listen: founders, managers, salespeople, anyone who has been told they talk too much."
mode: autonomous
music: none
---

## Video direction

- **Palette system** (from `frame.md`): canvas is `bg` black, and the navigation-glow deep blue (`glow`) is allowed only as a soft radial bloom behind a hero, never a flat fill. Type is `text` white with `text-muted` for secondary lines. `primary` cyan is the one accent: the ring, the wordmark, symbol circles, the tick mark. `negative` orange appears in exactly one place in the whole film, the ring when it crosses the line, and its glow. `positive` green appears once, on the score band "Good". No other hues. The frame preset's cards apply: `card-bg` white at 6% with the `border` hairline, `card-lg` radius, no shadows.
- **Type**: display and numerals in the display ramp (Space Grotesk roles `h1` / `h2` / `metric-value` / `stat-num`), body copy in the body ramp (Inter). The wordmark "two.ears" is lowercase with the dot, always in `primary`. Watch-screen text inside the drawn watch uses the display ramp at small sizes; never the raw screenshot text upscaled.
- **Motion grammar + reveal model**: long-tail `power3` settles everywhere; no overshoot anywhere in this film, the product is calm. Every frame reveals on its spoken cue: at t=0 only what the VO is saying enters; every further line, row, or number arrives when the narration names it, with reveals spread into the back half. During a hold the only aliveness is a low-amplitude subtle jitter on the hero, or the ring's own fill; no breathing, no back-half camera drift. The watch outline, when drawn, is a flat rounded rectangle in a 1px `border` hairline with a black face; no photoreal device render, no strap detail.
- **Rhythm / held frames**: Frame 4 (Not words) is the deliberate breather: three statements with air, still between them. Frame 7 holds its lockup for the final third of the film. Frames 3 and 6 are the busy frames (the ring fill and the count-up); Frames 1, 2, and 5 are quick.
- **Negative list**: no waveforms, transcripts, speech bubbles with words, or anything that implies recording; no third-party logos; no stock photography; no purple-blue "AI" gradients; no bokeh; no upscaled screenshot pixels visible; no bouncy entrances; no slideshow (everything at t=0 then frozen) and no screensaver (elements floating independently). Caption band: keep all content in the top 83% of the canvas.

## Frame 1 — Some rooms

- scene: Bold white type on black; the last word of one line swaps in place, listening → talking → broadcasting
- voiceover: "Some rooms are for listening. Then somehow you're talking. Then you're broadcasting."
- duration: 5.035s
- transition_in: cut
- status: animated
- src: compositions/frames/01-some-rooms.html
- type: hook
- persuasion: Pain validation
- beat: recognition → discomfort
- blueprint: kinetic-type-beats (Reproduce, sub-shape A fixed-line token swap)
- focal:
- roles:
- sfx:
- asset_candidates:

narrativeRole: Name the failure mode in the viewer's own experience before the product exists. The drift from listening to broadcasting is the whole pain, said in three words.
keyMessage: You know this drift. It happens to you.

Scene 1 (0.0–1.8s): black field; the fixed line "Some rooms are for" arrives dead-center via per-word staggered reveal (`dynamic-content-sequencing`) on a `power3` settle, and the slot word "listening." lands last in `primary` cyan. Centered, the line is ~60% of the width, display ramp `h2`. Nothing else on screen.
Scene 2 (1.8–3.6s): as the VO says "talking", the slot hard-cuts (`discrete-text-sequence`) to "talking." in `text` white, the rest of the line unchanged; a thin `border`-hairline underline draws left→right beneath the slot word. The line does not move.
Scene 3 (3.6–6.0s): as the VO says "broadcasting", the slot hard-cuts to "broadcasting." and the word steps up one size in the display ramp (`h1`) while the fixed words dim to `text-muted`; the underline redraws to the new width. Holds still to the cut; nothing else moves.

## Frame 2 — One private tap

- scene: A watch on a wrist in profile on black; a single soft haptic ring expands once from the watch and fades; type lands: "One private tap." then "Nobody else feels it."
- voiceover: "two.ears taps your wrist the moment you've talked past the point of listening. Nobody else feels it."
- duration: 6.4s
- transition_in: zoom-through
- status: animated
- src: compositions/frames/02-one-private-tap.html
- type: product_intro
- persuasion: Friction reduction (the intervention is one silent tap, not a report)
- beat: relief + intrigue
- blueprint: kinetic-type-beats (Adapt, Hook triptych variant: the middle beat is a non-text element, the tap pulse)
- focal: assets/app-icon.png
- roles: app-icon = supporting (the glyph on the drawn watch face, small)
- sfx:
- asset_candidates: assets/app-icon.png — the icon, small, as the watch's app glyph

narrativeRole: Land the message by beat two: the value is a private correction in the moment. The pulse is the product's entire intervention, so the visual is one pulse and nothing else.
keyMessage: One tap, in the moment, that only you feel.

Adapt: keep the arrive-hold-clear law and the one-element-alone-at-center discipline; the three beats are wordmark, pulse, and closing line. No spring overshoot; the pulse is a ring, not a glow explosion.
Scene 1 (0.0–1.4s): black field; the wordmark "two.ears" in `primary` arrives centered via per-word staggered reveal (`dynamic-content-sequencing`), display ramp `h1`, then scales down smoothly to a small centered lockup (a plain scale tween on the wordmark, no camera) as the VO moves on, clearing the center.
Scene 2 (1.4–4.6s): a drawn watch outline (flat rounded rectangle, `border` hairline, black face) fades in at center, ~45% of the frame height, with the icon's ear glyph small on its face; as the VO says "taps your wrist", ONE ring expands outward from the watch's center and fades, a thin circle stroke scaling out with an opacity fade-out in `primary` at low opacity, a single pulse; the watch face brightens for a beat then settles. Centered, layered-depth: field, faint `glow` radial gradient behind the watch fading in to low opacity (peak ≤ 0.3), watch, ring.
Scene 3 (4.6–7.0s): as the VO says "Nobody else feels it", the watch shrinks and slides up to the upper third and the line "Nobody else feels it." arrives beneath via per-word staggered reveal in `text` white, display ramp `h2`. Holds still.

## Frame 3 — The ring

- scene: The live ring rebuilt full-size: it fills from a low share, crosses the 40% tick, turns orange, the tap pulse lands; then the ring drains back under the line and the orange fades to cyan
- voiceover: "It measures your share of the last two minutes, from loudness alone, on the watch. Cross your line, one tap. Keep going, one more. Back under, silence."
- duration: 9.429s
- transition_in: crossfade
- status: animated
- src: compositions/frames/03-the-ring.html
- type: feature_showcase
- persuasion: Show-don't-tell proof
- beat: clarity → control
- blueprint: device-surface-showcase (Adapt, static-tour variant: the surface is the drawn watch, the "screens" are ring states; camera static)
- focal: assets/22-live-over.png
- roles: 22-live-over = supporting (reference for the orange over-threshold state; not shown as pixels) · 21-live-early = supporting (reference for the calm state; not shown as pixels)
- sfx:
- asset_candidates: assets/22-live-over.png — live ring at 68% in orange, reference for the over-threshold state; assets/21-live-early.png — live ring before evidence, reference for the calm state

narrativeRole: The mechanism as evidence for the promise: the ring is the only thing on the watch during a conversation, and the tap is tied to a visible line. Silence as the reward is the product's principle and closes the beat.
keyMessage: Your share, a line you chose, one tap when you cross it, silence when you're back.

Adapt: keep the held hero surface and element-level state changes with a static camera; the surface is the drawn watch from Frame 2, now large, and instead of screens cycling, one SVG ring animates through four states in sync with the VO. The screenshots are references for the ring's geometry and the orange/cyan states; the worker rebuilds the ring in SVG at full resolution.
Scene 1 (0.0–2.6s): the drawn watch holds at center, ~70% of the frame height; inside, the ring track in `card-bg` white 6% with the `primary` fill drawing from 12 o'clock (`svg-path-draw`, rotated −90°) to about 30% as the VO says "your share of the last two minutes"; a centered value counts up 0→30 with "%" (`counting-dynamic-scale`, no scale growth, `metric-value`) and "talking" beneath in `text-muted`; a small tick mark sits at the 40% position in `text` white at 70%. A caption line above the watch reads "your share of the last 2 minutes" in `text-muted`, arriving with the VO.
Scene 2 (2.6–4.8s): as the VO says "Cross your line", the fill continues 30→52% and the number follows; the moment the fill passes the tick, the ring's stroke crossfades `primary`→`negative` orange and the same single pulse ring from Frame 2 expands once from the watch, a thin circle stroke scaling out with an opacity fade-out in orange at low opacity; the caption hard-cuts to "one tap".
Scene 3 (4.8–6.6s): as the VO says "Keep going, one more", the fill nudges 52→58% and a second pulse fires, this time as two quick rings in succession (the double tap); the caption swaps to "one more".
Scene 4 (6.6–9.0s): as the VO says "Back under, silence", the fill drains 58→34% on a long `power3` tail, the stroke crossfades orange→`primary`, the number counts down, the caption swaps to "silence" in `text-muted` and then fades; the watch holds still with the ring at rest. No pulse. Subtle jitter only.

## Frame 4 — Not words

- scene: Three short statements land one at a time on black, each alone: "Loudness, not words." "Nothing recorded." "Nothing leaves your wrist."
- voiceover: "It listens to how loud the room is, not what anyone says. Nothing is recorded. Nothing leaves your wrist."
- duration: 6.763s
- transition_in: crossfade
- status: animated
- src: compositions/frames/04-not-words.html
- type: benefit_highlight
- persuasion: Risk reversal (the objection to a listening app is recording; remove it outright)
- beat: trust
- blueprint: kinetic-type-beats (Reproduce, Problem variant: statements land alone on a bare canvas)
- focal:
- roles:
- sfx:
- asset_candidates:

narrativeRole: Answer the objection every viewer has by now. Privacy is the product, so it gets its own beat and its own stillness, three statements with air between them.
keyMessage: It never knows what anyone said.

Scene 1 (0.0–2.2s): black field; "Loudness, not words." arrives centered via per-word staggered reveal (`dynamic-content-sequencing`), display ramp `h2`; the word "not" in `primary`. Holds alone.
Scene 2 (2.2–4.0s): as the VO says "Nothing is recorded", the first line clears by a hard cut and "Nothing recorded." arrives the same way; a small crossed-out circle glyph (a thin `border`-hairline circle with a diagonal) draws itself via a stroke-dashoffset tween to the left of the line. Holds alone.
Scene 3 (4.0–6.0s): as the VO says "Nothing leaves your wrist", the line hard-cuts to "Nothing leaves your wrist." with the same glyph; the field stays black and still to the cut. This is the breather frame: no jitter, no glow, nothing moves during the holds.

## Frame 5 — Pick the room

- scene: Three list rows assemble in a staggered cascade inside a drawn watch outline: Listen, tap past 40%; Balanced, tap past 55%; Presenting, stats only
- voiceover: "Pick the room. Listen, Balanced, or Presenting."
- duration: 3.307s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/05-pick-the-room.html
- type: feature_showcase
- persuasion: Feature-to-benefit translation (the threshold is a dial you set per situation, not a verdict)
- beat: control
- blueprint: grid-card-assemble (Reproduce, Benefits vertical-list BUILD sub-mode)
- focal: assets/50-start.png
- roles: 50-start = supporting (reference for the three rows, symbols, and the cyan symbol circles; rebuilt as HTML rows, never shown as pixels)
- sfx:
- asset_candidates: assets/50-start.png — the real start screen, reference for the three rows and their symbols

narrativeRole: Show that the line is yours to set, which is the coach-not-scoreboard principle made visible. Three rows, one glance.
keyMessage: You choose how much you should be talking in this room.

Scene 1 (0.0–1.2s): the drawn watch holds at center, ~70% of the frame height, its face showing the wordmark "two.ears" small in `primary` at the top like the real navigation title; as the VO says "Pick the room", a caption above the watch arrives: "Pick the room" in `text` white, display ramp `h3`.
Scene 2 (1.2–4.0s): three rows assemble one per spoken word (`center-outward-expansion` in its direct-into-slot form, ~1 row/s): each row is a `card-bg` card with a `primary` circle holding a white symbol (ear; two speech bubbles; a person with sound waves), a `text` title, and a `text-muted` detail: "Listen / Tap past 40%", "Balanced / Tap past 55%", "Presenting / Stats only". Each arrives as the VO names it. Rows fill the watch face top to bottom.
Scene 3 (4.0–5.0s): the assembled list holds; the Listen row's circle glows once (`ambient-glow-bloom`, one pass, low) to mark it as the default. Still.

## Frame 6 — Listening Score

- scene: A circular gauge with a red-to-green arc counts up to 82 with "Good" beneath it and "Listening Score" under that; two small rows arrive: "Longest stretch 48s" and "Course-corrected 2 of 2"
- voiceover: "Afterwards, a Listening Score, like a sleep score, and whether you course-corrected."
- duration: 4.885s
- transition_in: crossfade
- status: animated
- src: compositions/frames/06-listening-score.html
- type: benefit_highlight
- persuasion: Future pacing (the viewer sees the good session they want to have)
- beat: aspiration
- blueprint: dataviz-countup (Adapt, single gauge count-up as the hero; no camera push-through)
- focal: assets/53-score-hero.png
- roles: 53-score-hero = supporting (reference for the gauge geometry, gradient arc, and typography; rebuilt in SVG, never shown as pixels)
- sfx:
- asset_candidates: assets/53-score-hero.png — the real summary screen with the score gauge, reference for the gauge and typography

narrativeRole: The coaching loop closes after the conversation. A good score, not the demo's bad one, so the viewer pictures themselves succeeding.
keyMessage: You get better, and you can see it.

Adapt: keep the count-up hero and the numbers-as-argument; drop the push-through camera. One gauge, one number, then two rows on their spoken cue.
Scene 1 (0.0–2.4s): the drawn watch holds at center, ~70% of the frame height; its face shows "Summary" small in `primary` at top. As the VO says "a Listening Score", an open 270° gauge arc draws itself (`svg-path-draw`) through a red→orange→yellow→green gradient stroke while a marker dot travels along it, and the centered number counts 0→82 (`counting-dynamic-scale`, `metric-value`, no scale growth); beneath the gauge "Good" arrives in `positive` green and "Listening Score" in `text-muted`.
Scene 2 (2.4–4.2s): as the VO says "like a sleep score", the gauge holds and a caption above the watch arrives via per-word staggered reveal: "After the conversation" in `text-muted`. Still.
Scene 3 (4.2–6.0s): as the VO says "whether you course-corrected", two rows assemble beneath the gauge inside the watch (`center-outward-expansion`, direct-into-slot): "Longest stretch · 48s" and "Course-corrected · 2 of 2", `text` labels with `text-muted` values. Hold; subtle jitter on the number only.

## Frame 7 — two.ears

- scene: The stage clears; the icon's two ears draw on at center on the deep blue glow, the wordmark "two.ears" completes beneath, then the tagline: "Two ears, one mouth. Use them in that ratio." and a final line "Coming to Apple Watch"
- voiceover: "two.ears. Two ears, one mouth. Use them in that ratio."
- duration: 4.075s
- transition_in: zoom-through
- status: animated
- src: compositions/frames/07-two-ears.html
- type: branding
- persuasion: Rule of three (name, philosophy, platform)
- beat: confidence
- blueprint: logo-assemble-lockup (Reproduce, outline-draws-on variant resolving into a centered lockup with a tagline)
- focal: assets/app-icon.png
- roles: app-icon = cutout (the two ear glyphs are traced as SVG strokes and drawn on; the icon itself appears only as the small rounded app tile at the end)
- sfx:
- asset_candidates: assets/app-icon.png — the icon; the lockup is built from its two ears

narrativeRole: The name is the philosophy. Close on the lockup and hold it so the last frame is the brand.
keyMessage: two.ears, on Apple Watch.

Scene 1 (0.0–1.8s): black field with a soft `glow` radial bloom rising at center (`ambient-glow-bloom`, peak ≤ 0.35); as the VO says "two ears", two mirrored ear outlines draw themselves on (`svg-path-draw`) in white at center, ~30% of the frame width together, then the wordmark "two.ears" in `primary` arrives beneath via per-word staggered reveal, display ramp `h1`. Centered lockup.
Scene 2 (1.8–4.2s): as the VO says "Two ears, one mouth. Use them in that ratio.", the lockup slides up into the upper third on a `power3` settle and the tagline arrives beneath in two lines, `text` white, display ramp `h3`: "Two ears, one mouth." then, on its cue, "Use them in that ratio."
Scene 3 (4.2–6.0s): a final line "Coming to Apple Watch" arrives in `text-muted`, body ramp, beneath the tagline; the small rounded app-icon tile fades in beside the wordmark. Everything holds to the end; the final frame is the still lockup. Exit: none, this is the last frame.
