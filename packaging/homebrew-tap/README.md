# Setting up the Homebrew tap (one time)

A *tap* is just a GitHub repository whose name starts with `homebrew-`.

1. On GitHub create a **public** repository named `homebrew-breakbar` (public, because Homebrew
   cannot download release files from a private repo).
2. In it, create the folder `Casks/` and put the `breakbar.rb` file there. You get that file from
   each BreakBar release (it is attached next to the zip and DMG).
3. Commit it. People can now install with:

```bash
brew tap 12amcoffee/breakbar
brew install --cask breakbar
```

## Releasing a new version

1. Tag BreakBar (`git tag v0.2.0 && git push origin v0.2.0`). The workflow builds the zip, DMG and a
   fresh `breakbar.rb` with the right version and checksum.
2. Replace `Casks/breakbar.rb` in the tap with the new file and commit. Users then run
   `brew upgrade --cask breakbar`.

## Good to know

- The cask removes macOS's quarantine flag after install (see `postflight` in the file), because the
  app is not notarised. That skips the "unidentified developer" warning, so only keep it if you are
  comfortable with that. Homebrew's rules for taps change over time; check
  https://docs.brew.sh/Cask-Cookbook if it stops working.
- The official Homebrew cask repository requires notarised apps from well-known projects, so this
  tap is the route until then.
