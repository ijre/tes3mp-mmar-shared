# Shared Multiple Mark And Recall for TES3MP

This is a simple fork of the original repo, thus the installation and dependencies are mostly the same.

- New **optional** dependency of LevelingFramework; having it installed allows the script to automatically add level progress for Mysticism + main level when/if applicable
- - Highly recommended to install

### The other important changes are as follows:

- Marks are now shared between all players.

- Creating or deleting a mark will now tell everyone on the server who performed the action, alongside the name of the mark and in what cell.

- The config options have been fully redone and changed, now allowing for different colours for chat output, or for staff rank support

- New commands (check below!)

## Commands:
>`/mark`, `/markrm`, and `/recall`
- All work as expected, with the same usage as before.

>`/back`
- Teleports you back to your last position before using `/recall/`.
- Also has support for `/tp` and `/tpto`, the former setting the `/back` location for the player who was teleported.

>`/grave`
- Teleports you back to where you last died, also functions like `/back` in that typing it in twice will put you back where you started.

>`/ls`
- Prints all marks into chat in alphabetical order.

>`/lscmds` | `/lscommands`
- Prints all chat commands and their descriptions into chat.

>`/refresh`
- Reloads your config. Useful for testing different colours.