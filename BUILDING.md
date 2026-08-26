# Building locally

1. In Xcode, add your Apple account in **Settings > Accounts**.
2. If boringNotch is already installed, print its Team ID with this read-only command:

   ```sh
   codesign -dvv /Applications/boringNotch.app 2>&1 \
     | sed -n 's/^TeamIdentifier=//p'
   ```

   This only reads the existing signature; it does not sign or modify the app.

3. Create `.local-signing.env` in the repository root containing:

   ```sh
   DEVELOPMENT_TEAM=<YOUR_TEAM_ID>
   ```

4. Run:

   ```sh
   ./scripts/install-local.sh
   ```

The signing configuration is local to your checkout and ignored by Git.
