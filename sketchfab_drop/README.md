# Sketchfab CC-BY source packages

This directory receives four **optimized ZIPs**, preserving the original geometry,
license.txt and credit information while reducing PBR texture resolution.

The ZIPs are prepared from four user-provided Sketchfab downloads in this chat.
For ease of web upload, each ZIP is below GitHub's 25 MiB browser limit.
Never upload the original heavy archives into `dev`.

Upload all four `<slug>.zip` files here on the `feature/sketchfab-casino-assets`
branch. Keep their exact names:
`blackjack_table.zip`, `roulette_table.zip`,
`retro_slot_machine.zip`, `poker_set.zip`.

After the files appear on the branch, GitHub Actions can verify SHA-256,
extract the glTF dependencies, test the Godot scene and create a preview.
all four assets are **CC BY 4.0**, not CC0. Their license texts and creator
attributions are bundled in their respective ZIPs.

Source hashes and original artist details are in `catalog.json`.
The oversized Poker set includes an extracted, 27k-triangle `poker_props.glb`
with a few cards, chips and dice. The original set is retained in the ZIP for
traceability but is not placed into the performance-sensitive main scene.

