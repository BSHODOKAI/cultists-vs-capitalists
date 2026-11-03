Open Items:
Out-of-scope items per spec (audio, final 3D art assets, terrain verticality, save/load, settings menu, meta-progression, tutorials, localization, and MultiMesh conversion for swarms) remain deferred for future milestones.

CI/CD (Auto Deploy to Itch.io on release tag for now)
Difficulty Selector

ITCH_IO_API_KEY

We need to setup some simple github actions flows for releasing and deploying

To build the artifact, using godot export, use the Web CVC preset

we are deploying to ITCH IO, using the ITCH_IO_API_KEY repository secret in github actions

we only want to run the action on a tagged commit, to limit the amount of build minutes that are used


