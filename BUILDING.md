# Building locally

1. In Xcode, add your Apple account in **Settings > Accounts**.
2. Create `.local-signing.env` in the repository root containing:

   ```sh
   DEVELOPMENT_TEAM=<YOUR_TEAM_ID>
   ```

3. Run:

   ```sh
   ./scripts/install-local.sh
   ```

The signing configuration is local to your checkout and ignored by Git.
