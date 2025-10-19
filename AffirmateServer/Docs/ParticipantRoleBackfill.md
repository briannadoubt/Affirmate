# Participant Role Backfill Plan

## Audit

1. **Identify affected chats**  
   Run a SQL query (or Fluent script) to list chat IDs where more than one participant currently has the `admin` role:
   ```sql
   SELECT chat_id, COUNT(*) AS admin_count
   FROM participant
   WHERE role = 'admin'
   GROUP BY chat_id
   HAVING COUNT(*) > 1;
   ```
   This isolates the chats likely impacted by the historical bug that promoted every invitee to admin.

2. **Spot-check participants**  
   For each flagged chat, fetch the participant list ordered by `id`. The earliest participant (lowest `id`) should correspond to the chat creator that was seeded as admin at chat creation. Capture the remaining participant `id`s—these are candidates for demotion back to `participant`.

3. **Validate with application logs (optional)**  
   If available, cross-reference server logs or analytics to ensure no legitimate secondary admins were intentionally granted elevated privileges outside the normal invitation flow.

## Backfill / Migration Strategy

1. **Create a one-time migration**  
   Write a migration that iterates over each chat. For every chat, keep the participant with the lowest `id` (assumed chat creator) as `admin` and set all other participants to the `participant` role. Using the `id` surrogate key is reliable because the bug only affected invitees created after the chat owner.

2. **Run in a transaction**  
   Perform updates inside a transaction per chat (or per batch) to guarantee atomicity. In Fluent this can be done with `database.transaction { db in ... }`.

3. **Log adjustments**  
   Persist a record (e.g., in a maintenance log table or structured logs) with the chat ID and affected participant IDs so the support team can audit after deployment.

4. **Post-migration verification**  
   Re-run the audit query to confirm every chat now has exactly one admin. Also perform a targeted UI test (or manual check) to ensure demoted participants retain expected capabilities.

5. **Communicate to stakeholders**  
   Notify support and impacted teams that participant privileges were corrected. Provide guidance in case any user reports missing admin capabilities they previously relied on.

## Preventing Regression

* Keep the new server test (`ChatRouteCollectionTests.test_joinChatUsesInvitationRole`) in CI so any regression re-promoting participants to admin is caught immediately.
* Consider adding an additional authorization rule in the client/server flows that restricts admin-only actions to participants explicitly flagged as admins in the database.
