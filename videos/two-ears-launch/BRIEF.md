---
workflow: product-launch-video
flow: automation
storyboard: no
message: "A private tap on the wrist the moment you've talked past the point of listening, and nobody else in the room knows."
destination: x-feed
aspect: 1080x1080
language: en
audience: "People who walk into rooms where the right move is to listen: founders, managers, salespeople, anyone who has been told they talk too much."
length: 45s
angle: "the tap nobody else feels"
narration: minimal
---

## Intent

Launch video for two.ears, a private talk-share coach for Apple Watch. It measures how much
of a conversation you are talking, from loudness alone, and taps your wrist once when you
cross the share you chose. Nothing is recorded, transcribed, or sent anywhere. The video
makes one argument: the private tap. Calm, confident, Apple-adjacent; the product's own
palette (deep blue, cyan accent, orange only when over the line). Not a feature list.
Destination is the X and LinkedIn feed, so it must work muted: the text carries the story
and any narration is a bonus layer.

## Assets

- ../../Watch/TwoEarsWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png — the app icon, two ears on a cyan-to-blue gradient; closes the video as the lockup.
- ../../docs/launch-assets/50-start.png — simulator screenshot, start screen (two.ears title, Listen / Balanced / Presenting rows). 374x446 px; frame it inside a watch outline, never scale it past 2x.
- ../../docs/launch-assets/21-live-early.png — simulator screenshot, live ring gathering evidence ("Listening").
- ../../docs/launch-assets/22-live-over.png — simulator screenshot, live ring at 68% in orange, over the 40% target; the beat where the tap happens.
- ../../docs/launch-assets/53-score-hero.png — simulator screenshot, summary with the Listening Score gauge (30, Very Low).
- ../../docs/launch-assets/51-history.png — simulator screenshot, History with scores.

## Customizations

- Rebuild the live ring as a real animated element for the hero beat (it must move: the ring fills, crosses the tick, turns orange, and the tap lands) rather than relying on the low-resolution screenshot; use the screenshots as reference and for the start, score, and history beats.
- The tap itself is the climax: a single, quiet haptic pulse visualized on a wrist, no sound effect louder than the music.
- Close on the icon and the wordmark "two.ears", lowercase with the dot.

## Notes

- Never show a transcript, waveform of words, or anything that implies recording. The product measures loudness, not words.
- Copy voice: plain, short sentences. The spec's own lines are the source: "The mistake I can make is too much broadcast." "When I'm going to sponge, keep me honest."
- No third-party logos. No comparison to named competitors.
- Sign-in status at setup: not signed in to HeyGen; offline engines had missing dependencies. Narration is minimal and the cut must stand muted.
