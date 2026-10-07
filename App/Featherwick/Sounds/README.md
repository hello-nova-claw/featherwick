# Sounds

Short sound effects for the farm. **There are no sound files yet.** The game works silently
without them: `Sound` (`Feedback/Sound.swift`) plays a file only if it is in the bundle.

Put the files in this folder. XcodeGen copies them into the app (run `xcodegen` again after you add one).

| File | When it plays | Length |
| --- | --- | --- |
| `cluck.caf` | Tap a bird on the farm, or a pet lands | under 0.6 s |
| `egg.caf` | Eggs collected, or eggs laid overnight | under 0.5 s |
| `hatch.caf` | Chicks hatched | under 1 s |
| `coins.caf` | Eggs sold, a bird rehomed, show prize money, something bought, a show entry | under 0.6 s |

- Format: CAF or M4A (AAC), 44.1 kHz, mono is fine. The name without the extension must match.
  `cluck.m4a` works too; `.caf` wins if both exist.
- Keep each sound under 1 second, soft, with no sharp attack. Cozy, not arcade.
- Normalise to about -16 LUFS so no sound is much louder than the others.
- The audio session is `.ambient`: the silent switch mutes the sounds, and the player's music keeps playing.
- The player can turn sound off in Settings (≡). Haptics have their own switch.
