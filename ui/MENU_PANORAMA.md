# Main menu casino panorama

The full-screen background renders the current main.tscn visual geometry in an independent World3D/SubViewport at half the menu resolution in each dimension (one quarter of the pixels). The camera sweeps gently over the main aisle every 42 seconds and observes the camera-motion preference. The old abstract shader stays visible until the 3D view renders, and on load failure.

The showcase removes the player and run-specific nodes before tree entry. The hall and atmosphere scripts have a visual-only mode; no run controller, room audio, GI rig, reflection captures or animated dust are started. Existing authored models and materials are reused, and the environment is duplicated before menu-only lighting adjustments. The panorama is suspended during loading a run. No baked resources or gameplay geometry change.

Edit camera placement and FOV in ui/menu_showcase_3d.tscn; sweep, period and quality budget in ui/menu_showcase_3d.gd. The foreground remains ordinary sharp 2D controls. The GPU look should be checked in Forward+.
