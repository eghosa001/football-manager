# Audio assets

Drop production `.ogg` files here with these exact names to override the
procedural fallback synthesized at runtime by
`game/audio/audio_asset_generator.gd`:

- `goal_roar.ogg` — goal celebration bed
- `whistle.ogg` — referee whistle (also covers kickoff / full-time / injury)
- `whistle_card.ogg` — card whistle variant
- `substitution.ogg` — substitution jingle
- `shot_contact.ogg` — shot / contact thump
- `ui_click.ogg` — UI tick / click
- `crowd_ambience.ogg` — looping crowd bed (streamed by the match viewer)

No binary assets are committed to keep the repository lean and CI headless-safe.
The game always has sound: missing files fall back to synthesized cues, and the
mixer honors per-bus gains (`ui/crowd/whistle/goals/subs`), master mute, and
reduced-sudden-sounds from the settings store.
