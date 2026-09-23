# EMZ Content Studio

Live workspace: https://mmetwally23.github.io/EMZ-Contnet/

An English content calendar for EMZ Clinic, with a read-only client view and an authenticated team workspace. No client approval workflow.

## Using the workspace

- Clients open Calendar to see each idea, publication date and time, reference, caption and final file. Board, Table and Feed provide alternative views.
- Team members select **Team sign in**, enter their approved email and open the secure link from their inbox. Only authorized workspace members can edit.
- The workspace administrator can add editors through **Workspace settings > Manage team access**. Members then use their own email to sign in.
- Add the reference when planning a post. Add the single final delivery URL when the finished reel, image or carousel is available. **Ready to publish** requires that final URL.
- Team edits save to Supabase. Other visible sessions check for changes every 12 seconds. Conflicting saves preserve a local recovery copy instead of silently replacing another person's work.
- Missing publication times and timezone remain clearly marked until the team sets them.

The board includes grouping, subgroups, drag-and-drop, column controls, card properties, saved filters and bulk actions. The editor includes production briefs, assigned tasks, internal comments, history, reusable templates and archive/restore. Media previews require a directly accessible image/video URL; Drive and other share links open at their source.

## Publishing and data

`index.html` is the self-contained site served by GitHub Pages. A commit to the Pages source branch publishes code changes after GitHub's deployment completes. Content edits are stored in Supabase and do not create GitHub commits. This app does not publish to social platforms.

The public Supabase publishable key is intentionally embedded in the browser application. No secret/service-role key is included. Direct database table access is disabled, RLS is enabled, and RPC functions enforce team membership, administrator roles and revision checks. The public projection excludes internal notes, assignments, comments, archived posts and source history.

`schema.sql` documents the database functions and tables. Existing content is not embedded as private team data in this public repository. Client exports include the public projection only. Team exports can contain internal data and should be kept with the team.

For team-wide email sign-in, production SMTP may be needed if Supabase's default sender restricts recipients or rate limits emails. Configure the application's Site URL and redirect URL to the live workspace URL above.
