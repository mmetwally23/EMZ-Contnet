# EMZ Content Studio

## Shared editing without login

The owner enabled link editing on 23 September 2026. Choose **Team workspace** to edit immediately; no email or verification is required. Changes save to Supabase and other open tabs synchronize every 12 seconds. Anyone with the website URL can read the team workspace and change the shared plan. Client view is a presentation view, not an access restriction.

Use **Your name** to label changes on this browser. Names are not verified identities. Revision history, Undo, final-file validation and conflicting-edit protection remain active. Database tables and membership administration remain protected.

To restore restricted access, the database owner can run `update public.emz_sharing set link_editing=false where id=1;` and rebuild with `sharedEditing: false`. The original email sign-in code remains available but is not used in link-editing mode.

Live workspace: https://mmetwally23.github.io/EMZ-Contnet/

An English content calendar for EMZ Clinic, with a client presentation view and a shared team workspace. No client approval workflow.

## Using the workspace

- Clients open Calendar to see each idea, publication date and time, reference, caption and final file. Board, Table and Feed provide alternative views.
- Team members select **Team workspace** to edit without login.
- **Your name** optionally labels changes, with no email verification.
- Add the reference when planning a post. Add the single final delivery URL when the finished reel, image or carousel is available. **Ready to publish** requires that final URL.
- Team edits save to Supabase. Other visible sessions check for changes every 12 seconds. Conflicting saves preserve a local recovery copy instead of silently replacing another person's work.
- Missing publication times and timezone remain clearly marked until the team sets them.

The board includes grouping, subgroups, drag-and-drop, column controls, card properties, saved filters and bulk actions. The editor includes production briefs, assigned tasks, internal comments, history, reusable templates and archive/restore. Media previews require a directly accessible image/video URL; Drive and other share links open at their source.

## Publishing and data

`index.html` is the self-contained site served by GitHub Pages. A commit to the Pages source branch publishes code changes after GitHub's deployment completes. Content edits are stored in Supabase and do not create GitHub commits. This app does not publish to social platforms.

The public Supabase publishable key is intentionally embedded in the browser application. No secret/service-role key is included. Direct database table access is disabled, RLS is enabled, and RPC functions enforce revision checks and validation. With link editing enabled, team data is accessible to anyone with the link. Membership administration remains restricted.

`schema.sql` documents the database functions and tables. Existing content is not embedded as private team data in this public repository. Client exports include the public projection only. Team exports can contain internal data and should be kept with the team.

SMTP is not required for the current no-login mode.
