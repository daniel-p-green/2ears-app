---
workflow: product-launch-video
flow: automation
storyboard: no
message: "A private tap on the wrist the moment you've talked past the point of listening, and nobody else in the room knows."
destination: x-feed
aspect: 1080x1080
language: en
audience: "People who walk into rooms where the right move is to listen: founders, managers, salespeople, anyone who has been told they talk too much."
length: 40s
angle: "the tap nobody else feels"
narration: none
music: "Wait, SEA (symphonic) — user-supplied track, trimmed to the video's own 39.9s and faded, not the full 2:19"
---

## Intent

Launch video for two.ears, a private talk-share coach for Apple Watch. It measures how much
of a conversation you are talking, from loudness alone, and taps your wrist once when you
cross the share you chose. Nothing is recorded, transcribed, or sent anywhere. The video
makes one argument: the private tap. Calm, confident, Apple-adjacent; the product's own
palette (deep blue, cyan accent, orange only when over the line). Not a feature list.
Destination is the X and LinkedIn feed, so it must work muted: on-screen type carries the
story; the video is silent on purpose (no voice) and a trimmed slice of a user-supplied
score runs under the whole thing.

Revision 3 (2026-09-16): stays quick, 39.9s, same seven beats as the previous silent cut.
Two changes only: (1) a background track, trimmed from a 2:19 supplied file down to the
video's own length rather than stretching the video to fit the whole track; (2) every beat
that shows the watch renders it noticeably larger and closer — hero scale, the way Apple's
own device films hold a product — rather than a small demo inset. No new beats, no length
change beyond what the bigger watch geometry costs in layout.

## Assets

- ../../Watch/TwoEarsWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png — the app icon, two ears on a cyan-to-blue gradient; closes the video as the lockup.
- ../../docs/launch-assets/50-start.png, 21-live-early.png, 22-live-over.png, 53-score-hero.png, 51-history.png — simulator screenshots, references only, already used to build the seven frames.
- assets/audio/wait-sea-symph.m4a — the supplied track, trimmed to 39.9s (from its 2:19 original) with a 1.0s fade-in and a 3.0s fade-out, mixed at 0.85 since nothing else competes for it.

## Customizations

- Bigger watch, every beat: increase each frame's watch element to roughly 85-92% of frame height (up from about 45-70%), close enough that the case or band may clip the frame edge in a couple of beats. This is a geometry change only; scene timing and copy are unchanged.
- Keep the seven existing beats and their order exactly. Do not add or remove beats.

## Notes

- Never show a transcript, waveform of words, or anything that implies recording. The product measures loudness, not words.
- No third-party logos. No comparison to named competitors.
- Silent by design: on-screen kinetic type carries every beat, no captions, no voice. A local synthetic voice was tried in revision 1 and cut for sounding cheap; do not reintroduce narration without a real sign-in voice provider.
- A longer cut using the full 2:19 track was drafted and explicitly rejected in favor of staying quick; the full track stays at ~/Documents if a longer cut is wanted later.
