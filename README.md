# Shared Multiple Mark And Recall for TES3MP

This is a simple fork of the original repo, thus installation is the same. The important changes are as follows:

- Marks are now shared between all players.

- The config options and related code/checks for `maxMarks` and `teleportForbidden` plus its related entry, `msgNotAllowed` have been removed; the 1st now being irrelevant, and the latter two simply being personal choice, due to the nature of the script.

- Creating or deleting a mark will now tell everyone on the server who performed the action, alongside the name of the mark.