# 📝 CHANGELOG - My Lawyer

## [Control Page: Style Files] - 2026-11-03
- Moved the latest control page styles into `css/lists.css` and `css/profile.css`, merged rules that overrode each other, and removed unused ones. Header action buttons now sit two on each line and fill their part.

## [Control Page: Home and Tasks] - 2026-11-03
- The home page now shows whole-app totals only, and its menu name is stretched by the Arabic line ـ to match the names under it. A new «متابعة المهام» page below it lists what needs the admin now, and opens each list with all dates. Every menu page now has quick numbers at the top.

## [Control Page: List Layout] - 2026-11-03
- Main list pages now read: numbers, full-width search, filters, then dates with quick choices, each filter in a box with an icon and a name. They open on today. Search works while typing, looks through all dates, and has a clear button that brings today back. Reports, reviews, decisions and tickets gained a search box.

## [Control Page: Table Order] - 2026-11-03
- Applications, reported reviews, frozen money, and tickets now list the newest first, like the other tables. Order timelines and chat messages stay in time order.

## [Control Page: Main Tables] - 2026-11-03
- Main tables now start with a running number and have shorter rows.  The name column is wider, and the experience and rating columns are narrower. Status in tables and inner page headers is coloured text with a matching dot, and those headers are split into separate parts with labelled status lines and icons side by side, which now include availability and location. The control page now says «كارنيه النقابة». An application now opens as the lawyer's profile, and its activity and balance tables stay covered until approval. Tables inside sections are unchanged.

## [Control Page: Speed] - 2026-11-03
- The control page script is now compressed by Nginx, and its fonts moved to WOFF2 with the two main weights preloaded. Page files are read once at server start.
- Moving between pages reuses answers for 20 seconds, and any change clears them. Counts, search and ticket messages always ask the server.
- Removed costly `transition: all` rules and extra sticky and paint layers.

## [Control Page: Table Lines] - 2026-11-03
- Tables across the control page now form one connected grid of dashed lines that meets the edges of their containers, with the same 5px corners. Account tables no longer show photos, which stay in the profile.

## [Control Page: Service Users] - 2026-11-03
- Added the «محاميك حالاً» page under a new «الخدمات» menu group, replacing the join requests page: it holds applications with their decisions, approved lawyers, and rejected ones.
- «حسابات المحامين» now lists every lawyer from sign-up, with a service column and service filters. The service name shows in the profile header only when the service is active.

## [App Font] - 2026-11-03
- The app text font is now IBM Plex Sans Arabic (SIL OFL, licence inside the font files) in six weights from Thin to SemiBold, replacing flat-jooza. Bold text uses SemiBold, the heaviest weight included. English digits still come from `app-digits.ttf`. The control page uses the same six weights through `/admin-panel/font/:weight`, replacing the Vodafone font. The public website keeps its own font.

## [Load Test] - 2026-11-03
- Measured a separate copy of the backend on the live server with a temporary database (55,006 users, 200,000 orders), then deleted it. One process, no Nginx or TLS in the path. Per second: nearby search 86, order list 480, wallet read 966, login 17, wallet transfer 325, full order flow 108. Mixed use peaks near 200 operations per second. Nearby search returns 328 KB with 5,000 available lawyers.

## [Phase 3.21] - 2026-11-03
### Server and Code Quality
- `/health` now reports only status and database. CORS refuses other websites, and the deploy check follows the new health reply. Removed four unused tables (migration `021`).
- Separated map and order flow code from the tracking screen, and documents and review from lawyer registration. Split backend and app session tests into files by subject.
- Moved old changelog entries to `CHANGELOG_ARCHIVE.md`, and aligned the documented corners with the current app and control page.
- Deployed to the server. Nginx in `/etc/nginx/sites-available/mylawyer` now answers 404 for missing paths such as `/.env`. A database backup from before migration `021` is in `/root/backups`.

## [Phase 3.20] - 2026-11-03
### Project Organization
- One rules file for all accounts and models: `AGENTS.md` section 7 holds the start and handoff routine. `CLAUDE.md`, `GEMINI.md` and `.cursorrules` point to it. Added `docs/TASKS.md` and `docs/DECISIONS.md`.
- Split the large screens: tracking, promo map, and lawyer and client registration. Split order routes into `create`, `queries`, `decisions`, `progress` and `reviews`, with no change in behavior.
- Rewrote `README.md`, removed outdated evaluation text from the server document, corrected architecture facts, and removed the unused `@fastify/sensible`.

## [Phase 3.19] - 2026-11-03
### Location Screen and Always-On Permission
- The location screen shows only until the location is set once. The promo map still opens on every entry.
- An available lawyer without the always-on location permission is asked once on each app opening, and the app settings open on devices that do not show the system choice.

## [Phase 3.18] - 2026-11-03
### Illustrations, Promo Map and Photos
- Removed all SVG files and `flutter_svg`. One drawn illustration replaces them, smaller, with its line running from edge to edge. Empty and error states now use it too.
- The promo map opens on every client entry unless a notification was tapped. Its fixed sheet lists the highest rated lawyers within 50 km, and a profile opens inside the same sheet. A close button at the top leads home, and nothing can be ordered from it.
- The control page shows client and lawyer photos, and a lawyer's syndicate card stays in their profile after approval.
- Moved private widgets out of the two largest map screens, and removed unused control page styles.

## [Phase 3.17] - 2026-11-03
### Organized Control Page Files
- Rewrote all notifications to be short and clear. Added the missing ones: a new rating for the lawyer, the result of a comment report, and frozen fees for the lawyer even when the lawyer opened the ticket. The control page announces new tickets, applications, reports and frozen money while open.
- The one large control page file was split into `backend/public/admin/`: structure, styles, shared code, windows, and one file per page. Browsers keep these files until the next release, which makes the page lighter.
- Removed a note about when the decisions log started. Brought the architecture, database, development and handoff documents up to date, and removed the old `ANTIGRAVITY_REPORT.md`, which no longer matched the system.

## [Phase 3.16] - 2026-11-03
### Lawyer Experience
- Pressing a notification marks it read. A request to act (new order, complete the payment, start the task) disappears once the order has passed it, and old ones were cleared (migration `020`). The control page notifications use strong colors.
- Existing lawyers' experience was reset to 0.
- Lawyer sign-up asks for years of experience, which show in the lawyer's profile. Specialty and bio were removed from sign-up and every profile view. Their old values stay in the database, unused.
- Clearer names for the control page menu.

## [Phase 3.15] - 2026-11-03
### Records and Screenshot Mark
- Errors on the control page and in the app's location messages are always clear Arabic. Buttons and pages show loading, and moving between pages sends fewer requests.
- New "سجل القرارات" page records account suspension, prices and rates, lawyer applications, and comment decisions, with who and when (migration `019`).
- Order stages now also record deadlines that close an order, fees becoming available, tickets, and freezing, with who did each. Settlement notes are kept.
- The app name and signed-in account repeat faintly over the page. Notifications moved to the bottom left, the menu button is a dashed circle on the header line, the logo is larger, and tables have icons beside their titles.

## [Phase 3.14] - 2026-11-03
### Payments Log and Copying
- Every client payment now has its own number (`ML-PAY`) and method (migration `018`, old payments included). They show on the money page, the order and the client profile.
- Order, ticket and payment numbers copy when pressed.
- The login page and side menu use the app logo without text, the side menu collapses to icons, and the top header shows the signed-in account.

## [Phase 3.13] - 2026-11-03
### Take Action and Chat
- Ticket, order, account, application and report pages now have one "اتخاذ إجراء" button in their header. It opens a window that asks one step at a time and shows a review before running. The prices page keeps its actions at the end.
- A ticket has a "الشات" button that opens the conversation in a window: Enter sends, Shift+Enter starts a new line, and up to 5 images can be attached.
- Images open in a floating viewer instead of leaving the page, application documents show small, and every window has a close icon.
- A join request now shows in one container: name and action button, then data beside the documents.
- Every inner table has a short description, and order money shows as plain sentences.

## [Phase 3.12] - 2026-11-03
### One Box per Action
- Every action on every page sits at the end in its own box, side by side, with a short description of what it does. This includes the ticket reply and note, cancelling a warning, and editing a service price.
- Filters are now buttons that apply when pressed, instead of drop-down lists.
- Action boxes stand alone with no box around them, and the ticket reply and internal note open in a floating window.
- Each action box has its own icon.
- Related actions share a row: deductions together, additions together, warnings together, and so on.
- The control page corners are now 5px, and containers have dashed edges.
- Added one search in the top header for accounts, orders and tickets, and a light shadow on every container.

## [Phase 3.11] - 2026-11-03
### Control Page Short Names
- Shortened button names across the control page, since each box title already says the action, and the confirming window keeps the full name.
- Reviewed all texts in formal Arabic, including "بطاقة النقابة" instead of "كارنيه".

## [Phase 3.10] - 2026-11-03
### Control Page Finish
- Every page now uses the same action boxes in one "الإجراءات" section, with a small window for what a decision needs.
- Reviewed the wording, and strike types show in Arabic.

## [Phase 3.09] - 2026-11-03
### Order and Account Pages
- The order page has four tabs: summary, stages, money and actions. The money tab shows every balance movement and the freeze history of that order.
- The account page has four tabs instead of seven: data, activity, balance and warnings, and actions.
- A warning from a ticket is linked to its order, its window explains the automatic suspension, and party cards no longer repeat the name.

## [Phase 3.08] - 2026-11-03
### One Tickets Page
- Client and lawyer tickets are now one page with tabs for waiting, open and closed, a side filter, and the waiting time.
- A ticket opens in two columns: messages and reply beside the parties, money status, note and actions. Money actions and closing with a message open a small window.
- Ticket actions sit in one section below in equal boxes: transfer, deduct, add, warnings, freezing and closing. A warning to the lawyer or the client can now be sent from the ticket.

## [Phase 3.07] - 2026-11-03
### Control Page Home and Menu
- The side menu is grouped into follow-up, orders and accounts, and money, with a red count next to pages that have waiting work.
- The home page opens with a "المطلوب منك" list, each row opening its page, and small totals below it.

## [Phase 3.06] - 2026-11-03
### Money Page
- New control page "الأموال" with totals and three tabs: frozen money, all balance movements, and the freeze history.
- Every freeze, unfreeze and settlement of frozen fees is now recorded with who did it and why (migration `017`). Fees frozen before this update show no freeze date.

## [Phase 3.05] - 2026-11-03
### Money Actions Inside Tickets
- A ticket now has actions to deduct from or add to the lawyer and the client, and to freeze or unfreeze the order fees, with a note when the fees are frozen.
- A ticket on a finished order freezes its fees automatically, and nobody can open a ticket on an order 24 hours after its end, so the fees then stay available to the lawyer. The app hides the problem button after that time.
- Removed the half split from the whole system.
- Added two one-step transfers in a ticket, lawyer to client and client to lawyer, which deduct from one side and add to the other together.

## [Phase 3.04] - 2026-11-03
### Tickets Are for Replies Only
- Removed the money decision from tickets. Closing a ticket no longer changes any money, and frozen fees stay frozen until the admin decides on the order page.
- Control page notes sit in a box with a note icon, stat cards are separate, and labels and values follow fixed columns.
- Order parties show each person in a separate box, with data in ruled lines.
- Every account profile shows a current balance card: available fees for a lawyer, wallet balance for a client.

## [Phase 3.03] - 2026-11-03
### Control Page Look
- The control page brand color is now blue instead of green, and all corners are sharp. Green stays only for success states.
- Removed nested containers: the section is the only box, and what sits inside it (people, messages, tables, notes) is plain with thin dividers.

## [Phase 3.02] - 2026-11-03
### Control Page Cleanup
- Removed the suggested decision everywhere. The admin sees the facts and picks a decision, and all decisions look equal.
- Each page keeps its actions in one "الإجراءات" section at its end. A ticket has one message box with send reply, close with the message, and close without a message, and internal notes stay as they were. A profile has a "الإجراءات" tab for account status, balance and warnings, and the accounts list only opens the profile.
- Reduced the height and spacing of all containers, and rewrote the control page texts in formal Arabic.

## [Phase 3.01] - 2026-11-03
### Review Cards
- Every reviews view (my reviews page and the map sheets) now shows each review as a card: the reviewer photo on the right, then the short name, a "تجربة مؤكدة" mark, stars, comment, date and time.
- `GET /lawyers/:id/reviews` returns the short name (`أحمد م.`), `authorPhoto` and `publishedAt`. The full name stays on the server because this route is open.

المراحل الأقدم في [`CHANGELOG_ARCHIVE.md`](./CHANGELOG_ARCHIVE.md).
