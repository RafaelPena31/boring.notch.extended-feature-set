# Building locally

1. In Xcode, add your Apple account and select the intended Team in **Settings > Accounts**.
2. Print the last selected Team ID from Xcode's preferences:

   ```sh
   defaults read com.apple.dt.Xcode IDEProvisioningTeamManagerLastSelectedTeamID
   ```

   This is read-only and does not build, install, or sign an app.

3. Create `.local-signing.env` in the repository root containing:

   ```sh
   DEVELOPMENT_TEAM=<YOUR_TEAM_ID>
   ```

4. Run:

   ```sh
   ./scripts/install-local.sh
   ```

The signing configuration is local to your checkout and ignored by Git.
