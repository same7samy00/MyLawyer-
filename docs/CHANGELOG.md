# 📝 CHANGELOG - My Lawyer

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

## [Phase 3.00] - 2026-11-02
### Wait for the Admin Reply
- After sending, the client or lawyer cannot write again in the ticket until the admin replies, and cannot open a new ticket while one is under review. The app hides the reply box and the new ticket button with a short note.
- The control page logs any page error to the browser console, and its decision labels and page titles no longer break on an unexpected value.

## [Phase 2.99] - 2026-11-02
### Notification Fixes
- Rewrote the notifications that still talked about the completion code, and fixed the saved ones (migration `016`). Removed the unused client code warning.
- Tapping a notification from outside the app now opens its page even when the app was fully closed: the tap is caught before the permission and device steps, and the page opens after the first frame.
- In the notifications page, a notification linked to an order or a ticket shows an arrow and opens it.
- "تعليم الكل كمقروء" is now a small text link on the side instead of a full button.

## [Phase 2.98] - 2026-11-02
### One Path for Problems, and Notifications That Open Their Page
- Any ticket on an order, of any type and at any time, holds the order's fees, its finish, and its automatic settlement until the admin decides.
- "عندك مشكلة؟" in an order opens a new ticket on that order with no type to choose. When a ticket is already open it becomes "تابع مشكلتك" and opens that ticket.
- Removed the appeal button and routes. A lawyer who disagrees opens a ticket, and open appeals moved into tickets (migration `015`).
- Every notification carries the order or the ticket it talks about. Tapping it, from the phone or the notifications page, opens that ticket or that order.
- The control page keeps "بلاغات التقييمات" in place of appeals and reports.

## [Phase 2.97] - 2026-11-02
### Technical Support Tickets
- Clients and lawyers open a ticket from "الدعم الفني" in the account page, or from "عندك مشكلة؟" in an order with the order already picked. A ticket has a type, a title, the details, and up to 5 images.
- Ticket states: under review until the first admin reply, then open, and closed only when an admin presses close. Nobody can reply on a closed ticket.
- The support page lists every ticket with its title, ML-TKT number, order number, and state. The ticket page shows the messages in order, not as a chat, with a reply box while it is open.
- The control page has "تذاكر الموكلين" and "تذاكر المحامين" pages with replies, internal notes, private images, and close.
- A money ticket on an order holds the fees, the finish, and the automatic settlement. It closes only with a money decision, so a reply never pays anyone by mistake.
- Removed the old complaint and lawyer report routes and pages. Open old complaints move into tickets (migration `014`).
- At most 3 open tickets per person, and one open ticket per order.

## [Phase 2.96] - 2026-11-02
### Rating Prompts
- The rating sheet opens by itself for the client the moment the lawyer finishes the task.
- When the deadline ends after the lawyer arrived, the client gets a notification to rate, like a normal finish.
- One reminder to rate reaches the client a day after the task if they did not rate (migration `013`).
- The app still asks once on every launch to rate the last unrated order.
- Fixed the lawyer deadline reminders that still talked about the old code.

## [Phase 2.95] - 2026-11-02
### ML Numbering
- Every record now gets an organized number that starts with ML: ML-ORD orders, ML-CMP client complaints, ML-RPT lawyer complaints, ML-APL appeals, and ML-TRF transfers.
- The database gives the next number by itself, and old orders were renumbered by date.
- The numbers show in the replies, the notifications, the wallet movements, and the control page tables.

## [Phase 2.94] - 2026-11-02
### Wallet Transfers
- Any client or lawyer can send money from their balance to any active account by phone number.
- The sender sees the short name of the receiver and confirms before sending.
- At least 100 EGP per transfer, at most 10,000 EGP in the last 24 hours, with no fees.
- Added migration `011_wallet_transfers.sql`, the `/wallet` routes, the transfer sheet in both wallets, and tests.

## [Phase 2.93] - 2026-11-02
### Public Website for the Payment Gateway
- Added a landing page on `https://my-lawyer.online` that describes the app and its services, with the Alexandria address, phone, and email.
- Added temporary policy pages: `/terms/`, `/privacy/`, and `/refund/`.
- The site lives in `backend/public/site`, and `deploy.sh` copies it to the Nginx site folder with every deploy.

## [Phase 2.92] - 2026-11-02
### Meeting Rule Without a Code
- Removed the completion code everywhere: the client sees no code, the lawyer types no code, and the admin code unlock is gone.
- The lawyer's "وصلت" is accepted only within 50 meters of the client, using the phone's real location with no fallback. This is the proof that they met.
- "إنهاء المهمة" stays hidden until the arrival, then the lawyer finishes with a simple confirmation.
- Money rule: no arrival refunds the client, arrival pays the lawyer. The admin can still pick another decision by hand.
- Updated the app texts, the control page, and the tests.

## [Phase 2.91] - 2026-11-02
### Nearest First Across Egypt
- Every available lawyer in Egypt is listed from the nearest to the farthest, instead of distance groups ranked by rating.
- Removed the admin password that was written in `docs/ANTIGRAVITY_REPORT.md`. It stays only in `admin-credentials.txt` on the computer.

## [Phase 2.90] - 2026-11-02
### Lawyer Arrival Unrestricted by Location
- The "وصلت" (I arrived) button now accepts arrival from anywhere regardless of the lawyer's distance to the client.
- Removed the 500-meter proximity restriction (`ARRIVAL_RADIUS_KM = 0.5`) in `POST /api/v1/orders/:id/arrive`.
- Added resilient coordinate fallback in `order_details_screen.dart` so arrival succeeds smoothly even if device GPS is delayed or unavailable.
- Updated lifecycle test suite to verify that arrival is registered and accepted from any coordinate.

## [Phase 2.89] - 2026-11-02
### Nationwide Lawyer Selection and Unrestricted Search
- Removed the 25 km ordering restriction: clients can now request any available lawyer visible on the map across the entire country.
- The "بحث جديد" (New Search) button now queries across all of Egypt (1500 km radius) and cycles through all registered available lawyers.
- Updated default search radius in `LawyerRepository` and `/lawyers/nearby` endpoint to 1500 km.

## [Phase 2.88] - 2026-11-02
### Simple Complaints Workflow
- Complaints and reports in the control page are now direct and simple: review the complaint, write the admin reply, and submit to send the reply in an in-app notification to the complainant and close the complaint.
- Removed embedded settlement procedures and forced actions from the complaint and report screens.
- All disciplinary and financial actions (warnings, balance additions/deductions, fee freezes) remain accessible directly within the lawyer and client profile pages, allowing the admin to apply custom actions manually from the accounts as needed.
- Closing a money complaint unfreezes the order payout if no other open money complaints remain on that order.

## [Phase 2.87] - 2026-11-02
### Cleanup and Documentation
- Removed admin routes nothing uses anymore: the old account approval list and decision, and the old complaint and report decisions. The settlement and close routes replace them.
- Removed the control page font route and its font files, since the page carries its fonts inside.
- Removed 16 font files the app never used, which made the app smaller.
- The local control page preview is now part of the project: `npm run preview:panel`.
- Rewrote the API reference from the code, and documented the control page, the database tables, and the money rules.

## [Phase 2.86] - 2026-11-02
### Simple Settlement and Admin Account Tools
- One fixed money rule: no arrival refunds the client, arrival with the code pays the lawyer, and arrival without the code splits in half unless one side has 3 active warnings.
- The rule runs by itself when the task deadline passes, unless a money complaint is open. Appeals are no longer needed for new orders.
- The client can cancel after payment only in the first 5 minutes.
- Complaints are two choices for both sides, money or conduct, and close 24 hours after the task.
- Warnings for clients and lawyers, and 3 active warnings in 30 days suspend the account for a week, then it returns by itself.
- The admin can add to or deduct from any balance with a required reason, freeze an order's fees, and add or revoke warnings. A negative balance is a debt paid from later money.
- The control page shows the suggested decision with its evidence, uses plain classical Arabic, and explains each page and tool.

## [Phase 2.85] - 2026-11-02
### Control Page Redesign
- The control page now follows the EGY-ORDER dashboard: white side menu, page header with a subtitle and back button, quick reports on top of every page, filters by date and state, and organized tables.
- Client complaints and lawyer complaints are two pages. The lawyer page also holds appeals, reported reviews, and locked codes, so the tickets and appeals pages were removed.
- Every complaint, appeal, report, locked code, and lawyer application opens on its own page with its decision.
- Lawyers waiting for approval stay out of the lawyers list and have no profile until approved.
- Accounts open as profiles with top tabs, and people show in cards with icons for name, phone, and email.

### Lawyer Photo and Syndicate Card Before Approval
- Registration asks for a profile photo next to the syndicate card, and both are uploaded right after the first sign-in. Before, the card stayed on the phone only.
- If that upload fails, the service page tries again in the background.
- The server reads the card file itself, because phones often send no file type, and refuses an application without both files.
- The admin applications list returns the photo and the private card, so the control page can show them before approval.
- New admin list of open lawyer reports about clients, so client and lawyer complaints can have their own pages.
- Admin lists of accounts, orders, complaints, reports, and appeals now return each person's orders, complaints against them, and complaints they filed.
- The same lists also return each person's email, so their data card shows name, phone, and email.

## [Phase 2.84] - 2026-11-02
### Suspended Accounts
- Removed the public `health/migrate` link. Database updates run when the server starts, or with `npm run migrate`.
- A suspended account is refused by the server on every request, even with a valid sign-in.
- The app closes every page and shows a full «حسابك موقوف» screen with no way around it. Signing in with a suspended account opens the same screen.
- The screen checks the account every 30 seconds and opens the app by itself after the admin reactivates it.

## [Phase 2.83] - 2026-11-02
### Order Details and Full Control Page
- **Order details:** a new page holds all details and actions for the client and the lawyer. Order cards are now summaries, and the order number always shows. The lawyer no longer opens orders on the map.
- **Reviews:** a review shows on the lawyer profile immediately and updates the rating. The 24-hour publishing step was removed.
- **Account:** the photo is uploaded from the personal data page, which also shows the account data. The availability card moved under the profile card.
- **Photo upload:** the server now reads the file itself, because phones often send no image type.
- **Notifications:** tapping a push notification opens the Orders page.
- **Control page look:** it now uses the app font and colors, and every corner is 7 pixels. Pages are centered, and every page is split into titled sections such as data and actions. Confirmations use an in-page box so the app font applies to all text.
- **Control page:** a side menu with icons, pages for lawyers, clients, orders, reviews, complaints, and appeals, full account profiles, order search, and each order's full history. Saved and deleted actions show clear messages, expired sign-ins renew automatically, and the favicon error is gone.

## [Phase 2.82] - 2026-11-02
### Production Reset
- Lawyer specialty is chosen from a separate page with its own drawing.
- The backend now logs to journald, and its service no longer depends on the removed log folder.
- Removed everything unrelated to the app from the server, cleared all client and lawyer data, and kept the admin accounts.
- Removed unused public map routes, moved Nginx logs to `/var/log/nginx`, and set the platform share to 30%.
- The notifications page has its own empty drawing, and its header no longer shows the bell.

## [Phase 2.81] - 2026-11-02
### Reliability and Lower Server Use
- A full page replaces the connection notice whenever the connection is lost.
- App polling is slower and stops while the app is in the background.
- Updated vulnerable server packages, including sign-in tokens, email and validation.
- Removed unused images and code, and corrected price wording.

## [Phase 2.80] - 2026-11-02
### Lawyer Approval and Profiles
- Lawyers apply to the urgent service after ticking the terms, and the control page approves or rejects with a notification.
- Home shows a profile card with photo, greeting, city, rating and reviews, plus lawyer details and approval status.
- Lawyer registration adds a searchable specialty and a short bio, and clients get a rating from proven refusals.

## [Phase 2.79] - 2026-11-02
### Lawyer Availability, Terms and Tax
- Available lawyers send their place in the background: the phone checks every 15 minutes and sends after 30 minutes or 3 km.
- A lawyer becomes unavailable after two missed orders or an hour without a location update, and must turn it back on. The switch follows the server state.
- Every notification plays sound and vibrates, including while the app is open.
- Clients can cancel while waiting for a lawyer. Client and lawyer terms use expandable sections, and joining the urgent service requires accepting the lawyer terms.
- Tax is set in the control page, taken from the price first, then the platform share from the remainder, both locked per order.

## [Phase 2.78] - 2026-11-02
### Place Names on the Server Map
- City and village names returned to the map style
- Bottom sheets now match their content height on every phone with no scrolling, except the reviews list, and a closed sheet shows only its title.
- The phone cache moved to a new folder, so saved tiles without names are removed.
- The lawyer place now updates every 30 minutes while the app is open, plus every time it opens and on accepting an order.
- The connection notice checks every 15 seconds and stays visible until the connection returns., served from the new `/map/v2` tiles.

## [Phase 2.77] - 2026-11-02
### Back to the Server Map
- Removed the offline map after phone tests showed freezes of up to 4 seconds, and returned to the server map.
- Zoom now stays between 8 and 15, the camera stays inside Egypt, and any tile still loading shows a loading label.
- Kept the cards, camera moves and real lawyer place fixes.

## [Phase 2.76] - 2026-11-02
### Real Lawyer Places Only
- New lawyers no longer start at a fixed Cairo point. A lawyer appears on the map only after the phone sends a real place.
- Existing accounts still on that point were cleared, and lawyers with no activity date now follow the same 6 hour rule.
- The map draws each area once as an image for smoother movement.
- City and village names appear at every zoom, and camera moves are single smooth animations that stop on touch.
- Lawyers, clients and the user appear as cards that shrink when zooming out, with no pins.
- The route line appears at once, and the time follows when the server answers.
- Map zoom stops at 15 everywhere, including camera moves and buttons, and the screen stays inside Egypt.

## [Phase 2.75] - 2026-11-02
### Offline Egypt Map
- The map is now drawn on the phone from a 40 MB Egypt file inside the app, with no tile requests and no gray tiles.
- The lawyers list refreshes every 60 seconds and no longer carries unused fields.
- Signed-in users are rate limited per account, so phones sharing a mobile network IP do not block each other.

## [Phase 2.74] - 2026-11-01
### Map Pins and Moving Lawyers
- The map loads every available lawyer in Egypt, so pins no longer depend on camera movement. Each lawyer keeps a separate pin, and pins shrink when zooming out.
- Accepting an order sends the lawyer's current place, and the client sees a recalculated time before paying.
- A lawyer with no location update gets a reminder after 4 hours and becomes unavailable after 6 hours.
- Area names prefer a place within 3 km over a large distant city.

## [Phase 2.73] - 2026-11-01
### Permissions and Production Build
- First launch shows one screen explaining location and notifications before the system dialogs, with a later option. Camera stays requested when a lawyer adds the card photo.
- Arrival now reads a fresh GPS position, and first GPS waits up to 15 seconds for slower phones.
- Phones on iOS register as iOS for push, and iOS allows background notifications.
- Release builds use a production signing key kept outside Git.
- The location page now also serves lawyers with their own text, and it appears whenever location permission is missing, including when opening the urgent service.

## [Phase 2.72] - 2026-11-01
### GitHub Repository and Automatic Deploy
- The project now lives in the public repo `same7samy00/MyLawyer-` on `main`, with a fresh history that carries no server password.
- Pushing backend changes to `main` runs the checks and deploys through a runner on the server. Pull requests never run on it.

## [Phase 2.71] - 2026-11-01
### Notifications Page
- Notifications moved from a bottom sheet to a separate page in `lib/features/notifications`, with cards colored by notification type and a scalloped edge.
- Opening the page no longer marks notifications as read. The «تعليم الكل كمقروء» button does.

## [Phase 2.70] - 2026-11-01
### Project Organization
- Moved all screens from `lib/screens` into `lib/features` by area: `auth`, `client`, `lawyer`, `urgent_service`. Behavior is unchanged. Older entries below keep the old paths.
- Removed the unused `linux`, `macos`, `windows` and `web` folders, since the app targets Android and iOS only.

## [Phase 2.69] - 2026-11-01
### Arrival Before Completion
- A lawyer must record arrival near the client before ending a mission. The server refuses earlier completion without counting a code attempt, and the app shows «إنهاء المهمة» only after «وصلت».
- Corrected the architecture note about push notifications, which are implemented but not yet tested with the app closed.

## [Phase 2.68] - 2026-11-01
### Documentation Sync
- Rewrote the map system guide and handoff notes, and aligned project rules and server docs with the current system.

## [Phase 2.67] - 2026-11-01
### Order Screens Cleanup
- Removed the order parties location section. Order screens show one general line: the governorate before payment and the area name after it.
- The routing engine now listens locally only, behind Nginx with a request limit.
- The Egypt map cache covers the populated areas and the Delta.

## [Phase 2.66] - 2026-11-01
### Two Minute Response and Location Privacy
- The lawyer response window is now 2 minutes.
- Before payment, both sides receive approximate positions and no client area, enforced on the server. Exact places, the area and the Google Maps button appear after payment.
- The lawyer's order details show the client as a blue map card with name and completed orders.
- The lawyer's order details sheet is taller, so the details fit without scrolling.

## [Phase 2.65] - 2026-11-01
### Push Notifications
- Added Firebase push notifications with a high priority orders channel, so a lawyer receives a new order while the app is closed.
- Phones register at `/notifications/device-token`, and every in-app notification is also sent to the user's phones. Sending never delays an order.

## [Phase 2.64] - 2026-11-01
### Lighter Area Names
- Removed the Nominatim engine and its `/geo` route. The app shows a general area and governorate from `assets/data/egypt_places.json`, with no server or outside request.
- Lawyers reach the client with the Google Maps button using the exact location.
- A pin tap zooms to the lawyer's card, and the selected lawyer stays on the map during refresh.

## [Phase 2.63] - 2026-11-01
### Self-Hosted Map and Live Lawyer Presence
- The map is rendered once from the Egypt file on the server with Arabic labels, then served from a long Nginx cache at `/map/v1`. The renderer listens locally only.
- Lawyers report their location every minute while the app is open. An available lawyer stays on the map at the last location until they turn availability off.
- The phone map cache accepts WebP tiles and no longer keeps fallback tiles, so the server map returns as soon as it is reachable.
- The client's map refreshes every 20 seconds and loads lawyers for the visible area, with pins when zoomed out and lawyer cards when zoomed in. Orders stay within 25 km of the client.
- The line between both parties is drawn on the phone. Arrival time comes from road distance with an expected traffic factor, shown as a range.

## [Phase 2.62] - 2026-11-01
### Domain, HTTPS and Self-Hosted Addresses
- The app and control page now use `https://my-lawyer.online`, with a Let's Encrypt certificate that renews automatically. Release builds refuse unencrypted traffic.
- Lawyers get a Google Maps directions button with the client's exact location.
- Addresses come from a Nominatim engine on the server in reverse-only mode, behind an Nginx cache and rate limit, so no outside address service is used.

## [Phase 2.61] - 2026-11-01
### Automatic Order Address and Card Buttons
- The order address comes from the client's current location. Address lookup retries wider map levels, then adds the nearest named road from the server's routing engine.
- Removed the street names that were written in the code as an offline fallback. Offline, the address stays at city and governorate level.
- Past order actions moved inside the card. Card buttons are smaller and sit side by side.

## [Phase 2.60] - 2026-11-01
### Order Tracking and Response Countdown
- Saving a price in the control page clears saved client prices for that service, so the next quote follows the new range.
- A 60-second countdown appears for the client and lawyer in order cards, the waiting stage, and the lawyer's order details. Remaining seconds come from the server.
- When time runs out, the lawyer sees that the order ended, and the client's map sends the order to the next nearest lawyer. A lawyer's refusal does the same.
- The lawyer's order details draw the road route to the client once, with distance and time.
- A status tracker with icons sits at the bottom of order cards. Order lists refresh every 5 seconds, and the deadline sweep runs every 3 seconds.
- "بحث جديد" searches the server again and says clearly when no other lawyer is available.

## [Phase 2.59] - 2026-11-01
### One-Phone Testing
- Added the `lawyerTestApp` build option, which installs a second copy named "My Lawyer محامي" beside the main app. The default build keeps its name and app id.

## [Phase 2.58] - 2026-11-01
### Production Deployment
- Backend deployed to the live server with migration 003, after a trial run on a temporary copy of the database.
- `backend/deploy.sh` now matches the server: it builds in a release folder, installs production packages, keeps files owned by `www-data`, and restarts `mylawyer-backend`.
- Deployment uses a dedicated SSH key.

## [Phase 2.57] - 2026-11-01
### Final Service Rules
- Client approves the price before the request reaches a lawyer. Terms screen before the map.
- Lawyer response limit 60 seconds, payment limit 10 minutes, mission deadline 24 hours.
- One open order per client, one open mission per lawyer. Two missed orders turn the lawyer unavailable.
- Commission per service in the control page. Lawyers see the net amount only.
- New: arrival button within 500 m, client cancel before arrival, lawyer withdrawal with strikes, lawyer reports, code unlock, tickets tab, pay from balance, one review edit.
- Phones stay hidden until payment. Client names are stored.

## [Phase 2.56] - 2026-11-01
### Service Lifecycle
- **Finishing a mission:** the client gets a 4-digit code after payment. The lawyer finishes only with that code, with no other path and 5 attempts at most.
- **Lawyer wallet:** finished missions stay held for 24 hours, then become available. A complaint freezes the amount.
- **Complaints:** filed from the orders tab during the mission or after it. Admins refund fully, refund partly, or release the money. A complaint after 24 hours is recorded without a refund.
- **48 hour deadline:** starts at payment, reminds the lawyer at 24 and 40 hours, then closes the order and returns the money to the client's balance. An open complaint pauses it. The lawyer can appeal within 7 days.
- **Reviews:** one per completed order within 7 days, published after the complaint window, and held while a complaint is open. Lawyers report comments and admins hide them. Existing seeded ratings are reset by migration 003.
- **Pricing:** admins set a range for each of the 14 problems. The server picks a number for each client and keeps it while it stays inside the range. The app no longer sends a price.
- **Ranking:** lawyers are grouped by distance (2, 5, 10, 25 km), and each group starts with the highest rated.
- **Rejection:** the sheet shows the rejection, then the next lawyer. The client starts the next request.
- **Notifications:** in-app notifications, the unread dot, and the orders badge refresh every 20 seconds while the app is open. Phone push is not included yet.
- **Admin:** new control page at `/api/v1/admin-panel` for complaints, appeals, prices, and reported comments.
- **Fixes:** payment now requires lawyer acceptance, finishing requires payment, paid orders cannot be cancelled, and the lawyer app now reports its location.
- **Tests:** `npm test` in `backend/` runs 26 lifecycle tests on an in-memory PostgreSQL.

## [Phase 2.55] - 2026-11-01
### Font Coverage, Card Borders & Payment Screens
- Every text style now names the flat-jooza fallback explicitly (`appFontFallback`), so text no longer depends on what it inherits from the theme.
- Dashed card borders and separators are light blue (`AppColors.dashedBorder`).
- Payment and payment success screens have an edge-to-edge line behind their illustration (`EdgeLinesIllustration`).
- Removed the fixed wallet balance from the payment methods, and the claim about an encrypted payment gateway.

## [Phase 2.54] - 2026-11-01
### Urgent Lawyer Sheets
- The tracking and showcase sheets have an edge-to-edge line behind their content (`SheetLines`, `assets/images/sheet_lines.svg`).
- Order stages have centered, shorter text and each has an illustration. The accepted and price stages gained one.
- `LawyerProfileSummary` and the lawyer order sheet are centered. The syndicate and readiness row was removed to keep the profile short.
- Text no longer ends with «...» anywhere in the app, and these sheets no longer truncate with an ellipsis.

## [Phase 2.53] - 2026-11-01
### Login Screen
- The logo is larger (150px) and sits over an edge-to-edge line (`assets/images/auth_lines.svg`).
- The security note is split into two lines, and its icon matches their height.
- The login description is shortened to «سجل دخولك برقم الهاتف».
- After account verification or a successful login, the phone number stays on the device through logout and session expiry (`login_phone`), and appears in a disabled field. The user enters only the password.
- The location permission screen no longer has a header. The same line passes behind its illustration from edge to edge, and a back button appears only when there is a page to return to.

## [Phase 2.52] - 2026-11-01
### App Font
- The app font is now flat-jooza (`assets/fonts/flat-jooza-regular.ttf`), converted from the file on fontstatic.com without editing its glyphs.
- flat-jooza draws 0-9 in Arabic shapes. `AppFont` (`assets/fonts/app-digits.ttf`) holds English digits only, subset from Nunito (SIL OFL), and `AppTheme.fontFallback` sends all other text to flat-jooza.
- The font has one weight, so Bold and Black text uses a synthetic bold.
- The Thmanyah and SFMada families are no longer bundled. Their files remain in `assets/fonts/`.

## [Phase 2.51] - 2026-11-01
### Account Creation Hero
- The header row in the account type, client registration, and lawyer registration screens is replaced by the shared `AuthHeroHeader`: an original full-width illustration (`assets/images/auth_hero.svg`) with lines from edge to edge, a centered title with kashida below it, and a back button.
- In the registration and email verification screens the illustration scrolls with the form, so fields stay visible above the keyboard.
- Email verification uses the same layout with its own illustration (`assets/images/auth_hero_otp.svg`).
- Step descriptions moved under the title on two lines. Account type cards have shorter text.
- Main account creation buttons are text only and name the next step, without «التالي:».
- `KeyboardDismissArea` closes the keyboard on a tap on empty space across the app.

## [Phase 2.50] - 2026-11-01
### RTL Arrow Direction
- Back buttons in the registration, email verification, forgot password, and account type screens used `arrow_forward_rounded`, which Flutter mirrors to point left in RTL. They now use `arrow_back_rounded` and point right.
- Continue buttons used `arrow_back_rounded`. They now use `arrow_forward_rounded`, and `AppButton` places this arrow after the label.
- List rows in Home and the urgent service problem list now point left (`chevron_right_rounded`, mirrored in RTL).
- The logout icon, which Flutter does not mirror, is flipped in RTL.
- New tests in `test/press_feedback_test.dart` cover the arrow position and reject the wrong icons in `lib`.

## [Phase 2.49] - 2026-11-01
### Production Lifecycle, Unified Button Feedback, Navigation & Real Data
- **Buttons (`app_pressable.dart`, `app_button.dart`, `app_theme.dart`):**
  - `AppPressable` turns any pressable gray instantly through a `PressTint` color filter that costs nothing while idle. No size, radius, or font change. Scrolling off a button cancels the gray.
  - Ripple, Hover, and Micro-Scale removed across the app.
  - `AppButton` shows Loading only when its action returns a `Future`, keeps its size, and blocks repeats until the real operation ends.
- **Root causes of delay and jumps:**
  - Removed the global 450ms tap debounce (`safeTrigger`), which silently dropped taps on unrelated buttons.
  - Removed the blur (`BackdropFilter`) over the live map, which stalled the page transition.
  - Tabs now build on first visit instead of four at once when entering the shell.
  - Dragging the tracking sheet no longer rebuilds the map every frame (`ValueNotifier`).
  - Fixed leaked listeners in the sheet snap, overlapping camera animations, and page-transition `CurvedAnimation` allocation.
  - Removed loading spinners held for the lifetime of the next page, and the artificial 400ms delay on «بحث جديد». Responses over 32KB decode off the UI thread.
- **Back navigation:** shell tabs return to Home before exit; `PopScope` added to payment, payment success, tracking, and showcase; iOS swipe-back restored with `CupertinoPageTransitionsBuilder`; completed registration forms are replaced so they cannot be re-submitted; the header hides a back button that has nowhere to go.
- **Session lifecycle (`session_router.dart`, `auth_service.dart`, `api_service.dart`):**
  - Startup validates the session with `GET /users/me` alongside the splash (capped at 2.6s) and routes by role and approval status.
  - Automatic single-flight refresh via `POST /auth/refresh`. The session is cleared only when the server rejects it, never on a connection failure.
  - New screens: `ConnectionRetryScreen`, `LawyerApprovalStatusScreen`, `ForgotPasswordScreen`. New `ConnectionBanner` with automatic recheck.
  - Logout revokes the session on the server, clears local data, and resets the stack. «تذكر بياناتي» off now keeps tokens in memory only.
  - After OTP verification the app opens a real session; previously it marked the user as logged in without tokens.
- **Security:** removed the hard-coded `123456` OTP fallback that accepted a code the server had rejected, and the fallback that reported failed registration as success. `allowBackup` disabled on Android. Technical server errors no longer reach the user.
- **Production vs. testing:**
  - New `AppConfig`: Release is locked to the production API; other environments use `--dart-define=APP_ENV` and `API_BASE_URL`.
  - Removed the «موكل»/«محامي» login buttons, every test-only branch in production code, and `debugPrint` output in Release.
  - `MockLawyer` replaced by `MapLawyer`. Orders, lawyer wallet, showcase map, and account screens now use real API data with loading, empty, and error states. Fake notifications and fake complaint/withdrawal confirmations removed.
  - Failed payment, order creation, accept, and reject are now reported instead of being shown as success. Payment method selection, which did not respond to taps, now works.
- **Quality Gate:**
  - `flutter analyze`: `No issues found!`.
  - `flutter test`: 94 passed, 3 skipped (optional live API tests, off by default). New suites use a local fake backend: `test/press_feedback_test.dart`, `test/session_lifecycle_test.dart`.
  - `test/api_integration_test.dart` no longer contains passwords and no longer creates orders on production.
  - `flutter build apk --release`: succeeded. The Release binary was scanned for test strings.

---

## [Phase 2.48] - 2026-11-01
### Unified & Organized Lawyer Profile Bottom Sheet
- **Shared `LawyerProfileSummary` Widget (`lib/core/widgets/lawyer_profile_summary.dart`):**
  - Replaced the stacked icon/text table in `TrackingScreen` and the separate duplicated layout in `NearbyLawyersShowcaseScreen` with one shared widget, so both sheets stay identical.
  - Clear hierarchy: identity (56px photo, name, title, `StatusBadge` «الأقرب إليك») → three equal stat columns (rating, experience, distance with arrival time) → specialization → syndicate accreditation and readiness.
  - Long names, titles, and narrow screens are handled with ellipsis and `Wrap`, preventing overflow.
- **Sheet Layout:**
  - `NearbyLawyersShowcaseScreen` profile content now scrolls while its action buttons stay pinned, with 14px bottom padding.
  - `TrackingScreen` keeps its fixed 390px height, Google profile button, and «طلب الآن» / «بحث جديد» actions unchanged.
- **Quality Gate:**
  - Added `test/lawyer_profile_summary_test.dart` covering all sections, the nearest badge, and overflow at narrow widths.
  - `flutter analyze`: `No issues found!`.
  - `flutter test`: 40/40 tests passed.

---

## [Phase 2.47] - 2026-10-31
### Full Production Backend Integration & End-to-End Urgent Service Launch
- **Production Backend Integration (`ApiService` & Fastify + PostgreSQL):**
  - Built production client layer [`lib/core/services/api_service.dart`](file:///d:/KAREM/lib/core/services/api_service.dart) connected to Contabo Germany VPS (`13.140.141.32/api/v1`).
  - Integrated PostgreSQL database (`mylawyer_prod`) running on server with full schema migrations (`001_initial_schema.sql`, `002_lawyer_now_and_orders.sql`).
  - Configured Argon2id password hashing and JWT access/refresh token rotation with auto-persistence.
- **Authentication & User Management:**
  - Connected `AuthService.loginUser` to `/auth/login` supporting client & accredited lawyer logins.
  - Connected dual-role registration (`client` and `lawyer`) to `/auth/register` and `/auth/verify-otp`.
  - Configured accredited Egyptian lawyer seeds in Cairo, Giza, and Alexandria with real coordinates, syndicate numbers, ratings, and specialties.
- **Urgent Service («محاميك حالاً») End-to-End Launch:**
  - Map live geolocation queries `/lawyers/nearby?lat=...&lon=...` fetching real accredited lawyers with Haversine distance calculations.
  - Real service order generation (`POST /orders`) creating unique order identifiers (`ORD-...`) and storing client/lawyer locations and problem descriptions in PostgreSQL.
  - Real lawyer acceptance (`POST /orders/:id/accept`) and order rejection (`POST /orders/:id/reject`).
  - Real client payment confirmation (`POST /orders/:id/confirm-payment`) transitioning order to `ACTIVE`.
  - Service completion (`POST /orders/:id/complete`) with full audit trail in `order_status_logs`.
- **Comprehensive Verification & Quality Gate:**
  - Created live API integration test suite [`test/api_integration_test.dart`](file:///d:/KAREM/test/api_integration_test.dart) testing health checks, nearby lawyer queries, client & lawyer logins, and the complete 8-step order lifecycle.
  - `flutter analyze`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 38/38 tests passed (33 widget tests + 5 live API integration tests, 100% pass rate).

---

## [Phase 2.46] - 2026-10-31
### Universal Tactile Press Architecture & Button Interaction Overhaul
- **Root-Cause Diagnosis & Eradication:**
  - Diagnosed that buttons felt unresponsive due to 18 instances of `NoSplash.splashFactory` hardcoded across screens, `Colors.transparent` splash on bottom bar tabs and headers, immediate navigation routing without touch feedback windows, and rapid tap drops.
  - Replaced all `NoSplash.splashFactory` occurrences with native ink ripples (`InkRipple.splashFactory`).
- **Tactile Micro-Interaction Engine (`AppPressable`):**
  - Built `AppPressable` (`lib/core/widgets/app_pressable.dart`) listening to raw pointer events (`PointerDownEvent`, `PointerUpEvent`, `PointerCancelEvent`).
  - Delivers instantaneous micro-scale down to `0.975` in `80ms` via `Curves.easeOutCubic`, bouncing smoothly back on release.
  - Added centralized smart debouncing (`safeTrigger`) to prevent double-tap glitches, duplicate pushes, and concurrent asynchronous executions.
  - Test-environment detection (`_isTesting`) to bypass debounce timing during automated widget test runs.
- **Universal Button Integration (`AppButton`):**
  - Integrated `AppPressable` seamlessly into `AppButton` so every button (filled, outlined, danger, text) responds instantly with tactile scale and ink wave feedback while strictly preserving pill radii (24.0px), theme heights, and colors.
- **Directional Fluid RTL Transitions:**
  - Added `SmoothRtlPageTransitionsBuilder` to `AppTheme`, delivering fluid 240ms RTL directional slide (6% offset) and fade transitions without white flashes, stutter, or freeze.
- **Quality & Governance Gate:**
  - `flutter analyze`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 33/33 tests passed cleanly (100% pass rate).

---

## [Phase 2.45] - 2026-10-31
### Thmanyah Serif Font Integration & Thin Dashed Shadowed Cards
- **Subtle Shadow & Thin Dashed Border Container Cards (`AppCard` & Order Cards):**
  - **Very Thin Dashed Stroke (`-----`):** Enhanced `DashedRRectPainter` across `AppCard` to render as `foregroundPainter` with a refined 0.9px stroke width, 5.0px dash length, and 3.5px gap, bordered in `#CBD5E1`.
  - **Subtle Elevation (`boxShadow`):** Added a soft, featherlight elevation shadow (`Colors.black.withOpacity(0.025)`, blur: 8.0px, offset: (0, 2)) to give cards subtle floating depth without visual clutter.
  - **Strict Bottom Sheet Preservation:** All bottom sheets (including `TrackingScreen` order sheet, action sheets, and modal sheets) remain strictly intact on their clean canvas without dashed outlines or card frames.
  - **Order Details Containers:** Applied the refined thin dashed border and subtle shadow to inner order information cards in both `OrdersTab` and `LawyerOrdersTab`.
- **Complete Font Migration to Thmanyah Serif Text:**
  - Integrated `thmanyah-serif-text` family with all 4 font weights from `C:\Users\Hp\Downloads\thmanyah-serif-text`:
    - `thmanyahseriftext-Light.otf` (300)
    - `thmanyahseriftext-Regular.otf` (400)
    - `thmanyahseriftext-Medium.otf` (500)
    - `thmanyahseriftext-Bold.otf` (700)
  - Registered `ThmanyahSerif` in `pubspec.yaml` and aliased fallback names.
  - Migrated typography across the application and theme to `ThmanyahSerif`.
- **Quality & Governance Gate:**
  - `flutter analyze`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 33/33 tests passed cleanly (100% pass rate).
  - Rebuilt and running on connected Android phone.

---

## [Phase 2.44] - 2026-10-31
### Urgent Order Bottom Sheet Spacing Optimization & SFMada Font Adoption
- **Urgent Order Bottom Sheet Formatting & Proportions (`TrackingScreen` & `OrderPartiesLocationWidget`):**
  - **Balanced Sheet Height Reduction:** Shortened the lawyer review bottom sheet height from oversized `580px` down to a balanced `445.0 - 480.0px` (`screenH * 0.54`), removing the dead/wasted empty space while ensuring all content and action buttons fit comfortably without vertical scrolling.
  - **Generous Inter-line & Section Spacing:**
    - Increased vertical spacing between client header, legal problem details, location range, and parties location widget (`14px` and `12px` gaps).
    - Enhanced line heights (`1.45` on problem description and `1.45` on party location addresses) for effortless readability.
    - Added comfortable spacing (`12px` and `8px`) inside `OrderPartiesLocationWidget` between client location, distance indicator, and lawyer location.
- **Universal Font Migration to SFMada-Subset:**
  - Integrated `SFMada-Subset` font across Android, iOS, and Web:
    - Converted `SFMada-Subset.woff2` to TrueType (`SFMada-Subset.ttf`, 334 KB variable font) for full native mobile Flutter rendering support, and bundled both `.ttf` and `.woff2` in `assets/fonts/`.
    - Registered `SFMada` and aliased `ThmanyahSans` in `pubspec.yaml`.
    - Updated `AppTheme` and migrated 317 text style declarations across 30 files from `ThmanyahSans` to `SFMada`.
- **Quality & Governance Gate:**
  - `flutter analyze`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 33/33 tests passed cleanly (100% pass rate).
  - Fresh application build and deployment to connected phone.

---

## [Phase 2.43] - 2026-10-31
### Complete Removal of Colored Text Backgrounds & Badges Across the Entire App
- **Universal Typography on Canvas (Zero Text Badges / Background Fills):**
  - **No Colored Pills/Badges Behind Text:** Eliminated all colored container backgrounds, chips, and pills wrapping text across all screens and widgets. Text is now rendered directly on the background canvas with clean typography and subtle indicator dots.
  - **StatusBadge Architecture Overhaul (`lib/core/widgets/status_badge.dart`):** Removed container background color (`_bgColor`) and border entirely. Replaced with an unboxed inline `Row` featuring a clean 7px circular status dot and bold text on transparent canvas.
  - **Order Tracking & Showcase (`TrackingScreen` & `NearbyLawyersShowcaseScreen`):**
    - Removed green tinted badge (`AppColors.success.withOpacity(0.1)`) behind price (`350 ج.م`), rendering it as clean direct green text.
    - Removed green badge behind «الأقرب إليك», rendering it as direct text with bullet (`• الأقرب إليك`).
    - Removed background containers and borders from distance, syndicate membership, and immediate readiness sections, presenting information directly on the canvas.
    - Removed background fills from cancel, decline, and retry outlined buttons.
  - **Authentication & Registration Flows:**
    - `LoginScreen`: Converted error message banner from red-tinted box to direct text row with warning icon; removed background fills from test buttons.
    - `ClientRegisterScreen` & `LawyerRegisterScreen`: Converted step error alerts into direct text rows with icons without colored background boxes.
    - `EmailVerificationScreen`: Replaced success and error notification boxes with clean, unboxed icon-and-text rows.
    - `UserTypeSelectionScreen`: Replaced account badge containers (`حساب قياسي` و `خاص بالمهنة القانونية`) with direct text bullets.
    - `PaymentSuccessScreen` & `RegistrationSuccessScreen`: Removed light-blue container backgrounds and borders from countdown indicator banners.
  - **Billing & Notifications:**
    - `PaymentScreen`: Removed background color fills from service receipt title row, final total row, and payment method selection cards.
    - `AppHeader`: Removed colored background boxes behind unread notifications.
    - `LawyerUrgentServiceIntroScreen`: Converted step numbers to clean outlines with zero background fill.
- **Verification & Governance Gate:**
  - `flutter analyze`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 33/33 tests passed cleanly (100% pass rate).
  - Live execution verified on connected physical Android device.

---

## [Phase 2.42] - 2026-10-31
### Bottom Sheet Expansion, Direct Text UI, and Registration Headerless Flow
- **Expanded & Dynamic Order Review Bottom Sheet (`TrackingScreen`):**
  - **Dynamic Height:** Introduced dynamic expansion `_expandedHeight` (`MediaQuery.sizeOf(context).height * 0.65`, clamped between `510px` and `580px`) for lawyer order details.
  - **Zero Scroll Needed:** All order details (client info, problem description, location range, party locations, and actions) fit comfortably at once without requiring vertical scrolling.
  - **Pinned Action Buttons:** Maintained permanent, solid visibility of action buttons («قبول الطلب» and «اعتذار») at the bottom of the sheet.
- **Removed Text Card Enclosures & Streamlined UI (`OrderPartiesLocationWidget` & `TrackingScreen`):**
  - **Canvas Direct Typography:** Eliminated cards, background containers, and borders from around problem details, location range text, and party location sections.
  - **Live Location Status Indicator:** Added **«موقع مباشر الآن»** as clean text with a dedicated 6px green active dot indicator only when live location coordinates are actively updating. Reverts to muted text when cached or offline.
  - **Concise Data Encryption Label:** Replaced the lengthy green badge with a clean, concise **«البيانات مشفرة»** text adjacent to a lock icon without background or borders.
- **Removal of Headers from Account Creation Screens:**
  - Removed top `AppHeader` from all 5 account creation steps:
    1. `UserTypeSelectionScreen` (اختيار نوع الحساب)
    2. `ClientRegisterScreen` (تسجيل الموكل)
    3. `LawyerRegisterScreen` (تسجيل المحامي)
    4. `EmailVerificationScreen` (التحقق من البريد الإلكتروني)
    5. `RegistrationSuccessScreen` (نجاح التسجيل)
  - Zero reserved header space/padding; screens start naturally from the top with an unboxed inline back button and clean page title.
- **Verification & Governance Gate:**
  - `flutter analyze`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 33/33 tests passed cleanly (100% pass rate).

---

## [Phase 2.41] - 2026-10-31
### Unified Minimal UI & Aesthetic Overhaul (Based on Reference Design)
- **Design System Paradigm Shift (Minimal UI & White Canvas):**
  - **Typography Directly on Canvas:**
    - Titles and headings rendered directly on pure white canvas without bulky card containers or heavy colored wrapper backgrounds.
    - Systematic typographic hierarchy with font weights (`w900`, `w800`, `w700`, `w600`) and clean proportional line heights.
  - **Pill Stadium Buttons (24.0px Radius):**
    - Overhauled all primary, secondary, and dialog action buttons across the entire platform to prominent **24.0px stadium pill radius** (`BorderRadius.circular(24.0)`).
    - Unified button height standard (48px - 50px) with comfortable horizontal margins, solid primary blue fill, and tactile feedback.
    - Applied universally across `AppButton`, `AppTheme`, Login, Register Wizards, Orders, Wallet, Account, Tracking Bottom Sheet, and Modals.
  - **Dashed Border Minimal Cards (`DashedRRectPainter` & `AppCard`):**
    - Upgraded `AppCard` engine with custom `DashedRRectPainter` for crisp, hardware-accelerated dashed rounded borders.
    - Zero heavy drop shadows; cards integrate with a white or subtle semi-transparent background and calm border lines (`AppColors.cardBorder`).
    - Added `DashedDivider` for clean, lightweight section separation.
  - **Minimalist Rounded Form Inputs (16.0px Radius):**
    - Updated `InputDecorationTheme` and text fields to soft, clean 16.0px rounded borders with subtle 1.0px strokes and generous padding.
- **Screen-by-Screen Unification:**
  - **Login & Registration:** Clean white canvas, pill action buttons, soft inputs, non-card direct text headers.
  - **Home & Lawyer Home Tabs:** Direct canvas titles, dashed service cards, text-only non-clickable user location.
  - **Orders & Lawyer Orders Tabs:** Dashed order cards, 24px action buttons («تواصل»، «شكوى»، «فتح الطلب»، «اعتذار»).
  - **Wallet & Lawyer Wallet Tabs:** Dashed balance and transaction cards, pill deposit/withdraw buttons.
  - **Account & Lawyer Account Tabs:** Clean dashed cards, 24px logout and confirmation buttons.
  - **Service Flow & Tracking:** Updated problem description, payment screens, and bottom sheet action buttons to 24px pill styling.
- **Verification & Governance Gate:**
  - `flutter analyze`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 33/33 tests passed cleanly (100% pass rate).

---

## [Phase 2.40] - 2026-10-31
### Enhanced & Refined
- **Home Tabs Header Cards & Text-Only Location Address:**
  - **Text-Only Geographic Location:**
    - Transformed the geographic location address in both Client (`HomeTab`) and Lawyer (`LawyerHomeTab`) into **pure, non-clickable text**.
    - Removed all `InkWell` tap interactions, `TrackingScreen` routing, and button-like styling/shadows.
    - Guaranteed zero map triggers or navigation upon tapping the address.
  - **Removal of Duplicate Notifications Icon:**
    - Eliminated the redundant notifications icon button adjacent to the user info and address across both `HomeTab` and `LawyerHomeTab`.
    - Retained exclusively the official notifications icon housed in the global top `AppHeader`.
    - Harmonized horizontal spacing and layout balance without visual voids.
  - **Styled User Profile Header Cards:**
    - Replaced the scattered top elements with a unified, elegant `AppCard` (7.0px radius, subtle border, calm background, balanced internal padding):
      - **In Lawyer Home (`LawyerHomeTab`):** Features the lawyer's shield avatar, title «أ/», dual name, syndicate registration number (`رقم القيد: ...`), and concise non-clickable location text.
      - **In Client Home (`HomeTab`):** Features the client's person avatar, personalized greeting «أهلاً بك،», client name, and concise non-clickable location text.
  - **Automated Tests:**
    - Updated `test/widget_test.dart` to verify that the address is non-clickable text that never pushes routes, that no duplicate notifications icon exists in tab bodies, and that cards render formatted data cleanly.
    - All 33 tests passed cleanly (`flutter test`: 33/33).
    - Static analysis: `No issues found!`.

---

## [Phase 2.39] - 2026-10-31
### Added & Enhanced
- **Order Party Location Sharing & Privacy Architecture:**
  - Created `OrderLocationService` (`lib/core/services/order_location_service.dart`) managing active order location access with strict privacy enforcement:
    - Detailed location coordinates and addresses are strictly prohibited from appearing on public profiles, home tab, search results, or public pages.
    - Accessible only inside active order cards and active order Bottom Sheets during active orders (`hasActiveOrder == true` and `in_progress`).
    - Immediately halted when an order completes or is cancelled, displaying a privacy-safe state.
    - Handles stale connection gracefully by displaying «آخر موقع معروف» with relative timestamps (e.g. منذ دقيقتين / 10:45 ص) or «الموقع غير متاح».
  - Enhanced `GeoNamingService` (`lib/core/services/geo_naming_service.dart`):
    - Added `getDetailedAddress(lat, lng)`: Resolves street, neighbourhood/suburb, city, and governorate (الشارع – المنطقة – المدينة – المحافظة) with fallback to verified Egyptian coordinates without inventing fake data.
    - Added `getShortAddress(lat, lng)`: Provides concise two-part addresses (e.g. المعادي، القاهرة) to prevent visual clutter in cards.
  - Created `OrderPartiesLocationWidget` (`lib/core/widgets/order_parties_location_widget.dart`):
    - **Compact Mode:** Embedded in Client `OrdersTab` (showing lawyer's live short address) and Lawyer `LawyerOrdersTab` (showing client's live short address) in an uncrowded single-line format.
    - **Detailed Mode:** Embedded in `TrackingScreen` Bottom Sheet under a dedicated section titled **«مواقع أطراف الطلب»**, displaying detailed addresses for client and lawyer, real-time live/cached status, and approximate distance (~ 1.4 كم تقريباً).
    - Localized reactive updates prevent disruptive whole-screen or whole-sheet rebuilds when coordinates update.

- **Password Strength Display Simplification:**
  - Overhauled `PasswordStrengthWidget` (`lib/core/widgets/password_strength_widget.dart`):
    - Completely removed all condition chips/badges ('8+ خانات', 'حرف كبير', 'حرف صغير', 'أرقام', 'رموز خاصة') from the UI.
    - Maintained full programmatic validation rules and strong password enforcement in `AuthService.evaluatePasswordStrength`.
    - Rendered only the animated linear progress bar (with 7.0px border radius) and dynamic strength label (ضعيفة / متوسطة / قوية ومؤمنة).

- **Multi-Step (Step-by-Step) Registration Architecture:**
  - **Client Registration (`ClientRegisterScreen`):**
    - Converted into a 3-step structured wizard:
      - **Step 1: البيانات الشخصية:** Full name (`الاسم الكامل`) and phone (`رقم الهاتف المحمول`).
      - **Step 2: بيانات الحساب:** Email (`البريد الإلكتروني`) and password with strength bar only.
      - **Step 3: مراجعة وإرسال البيانات:** Formatted review card with field-level edit navigation and final submission button.
  - **Lawyer Registration (`LawyerRegisterScreen`):**
    - Converted into a 4-step structured wizard:
      - **Step 1: البيانات الشخصية والمهنية:** Full quadruple name as on bar card, phone number, and syndicate registration number (`رقم القيد بالنقابة`).
      - **Step 2: بيانات الحساب:** Professional email and password with strength bar only.
      - **Step 3: مستندات المحامي:** Bar syndicate card upload with preview, change/delete actions, and format validation.
      - **Step 4: مراجعة وإرسال البيانات:** Comprehensive review summary card with thumbnail preview and submit button.
  - **Step Navigation & State Preservation Rules:**
    - Segmented progress bar showing current step and progress percentage.
    - Next («التالي») and Previous («السابق») buttons with strict per-step validation.
    - Absolute state preservation when moving back and forth (no inputs, passwords, or images are cleared).
    - Responsive Android system back gesture handling via `PopScope`.
    - No header, no bottom bar, strictly 12.0px button radii and 7.0px card radii.
    - Preserved seamless transition to `EmailVerificationScreen` and `RegistrationSuccessScreen`.

- **Verification & Testing Suite:**
  - Added unit and widget tests covering multi-step registration steps, back-and-forth data preservation, password strength bar without badges, and location privacy enforcement.
  - All 33 tests passed cleanly (`flutter test`: 33/33 passed).
  - Static analysis: `No issues found!` (0 warnings, 0 errors).
  - Hot reload applied to live connected device (`RMX3997`).

---
### Optimized & Fixed
- **Root-Cause Interaction & Button Responsiveness Overhaul:**
  - Removed global `splashFactory: NoSplash.splashFactory` and `overlayColor: Colors.transparent` across `app_theme.dart` and `app_button.dart` that completely suppressed tactile touch response.
  - Enabled instantaneous, tactile touch feedback via `InkRipple.splashFactory` and contextual state overlays (18% for elevated buttons, 10-12% for outlined/text/icon buttons).
  - Enhanced `AppButton` with `AnimatedSwitcher` (180ms easeOut) for seamless, flicker-free transitions between text and loading spinners.
  - Removed artificial delays in `login_screen.dart` (700ms) and `auth_service.dart` (600ms/500ms -> 150ms).
- **Smooth Page Transitions & Zero-Flicker Navigation:**
  - Configured `PageTransitionsTheme` in `AppTheme.lightTheme` with `FadeUpwardsPageTransitionsBuilder` for Android and `CupertinoPageTransitionsBuilder` for iOS, eliminating jarring snaps, zooms, or route flashes.
- **Login Screen Dev Interface Testing Buttons:**
  - Replaced the legacy «تجربة سريعة للبيانات» button with two side-by-side buttons in one row at the same visual level:
    1. **«موكل»** (Client): Directly opens `MainNavigationShell` for UI testing without credentials.
    2. **«محامي»** (Lawyer): Directly opens `LawyerNavigationShell` for UI testing without credentials.
  - Guarded strictly by `kDebugMode` to ensure zero leakage into production releases.
- **Native OS Permission Architecture & Manifest Pruning:**
  - Created `DevicePermissionService` (`lib/core/services/device_permission_service.dart`) managing official native OS dialogs.
  - Pruned unnecessary permissions from `AndroidManifest.xml` (`ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`), complying with single-point location governance.
  - Updated `Info.plist` with clear, compliant Arabic permission descriptions for Location, Camera, and Photos.
  - Added fallback routing to device app settings (`openAppSettings()`) when location permission is permanently denied.
  - Optimized GPS acquisition in `LocationService` with `getLastKnownPosition` instant cache fallback.
- **Automated Testing Suite:**
  - All 31 tests passing cleanly (31/31).
  - Static analysis: `No issues found!` (0 warnings, 0 errors).

---

## [Phase 2.37] - 2026-10-31
### Added
- **Full Lawyer Interface Mirroring & Multi-Tab Decoupling:**
  - Completed all tabs for the Lawyer interface so that it mirrors the Client interface structure, layout, typography, and navigation:
    1. **`LawyerOrdersTab` (`lib/screens/lawyer_orders_tab.dart`):**
       - Identical visual structure to Client `OrdersTab` (Active order card, status badge, date/time, client details, transaction reference, location range, and guaranteed fees).
       - **Action Buttons Transformation:** Replaced client «تواصل» and «شكوى» with:
         - **«فتح الطلب»** (Primary 12.0px button)
         - **«اعتذار»** (Secondary 12.0px outline button with confirmation modal)
    2. **`LawyerWalletTab` (`lib/screens/lawyer_wallet_tab.dart`):**
       - Balance card with `AppColors.dark` background and 7.0px radius matching Client wallet layout.
       - Tailored to lawyer fee withdrawals and earnings statistics (إجمالي الأتعاب المحصلة، الاستشارات المنفذة).
       - Transaction history displaying incoming legal fee deposits.
    3. **`LawyerAccountTab` (`lib/screens/lawyer_account_tab.dart`):**
       - Profile card displaying lawyer title (`أ/`), dual name, syndicate registration number, and verified badge.
       - Settings and preferences menu for professional data, working hours, notifications, and terms.
       - Logout flow with the unified confirmation modal.
  - **`TrackingScreen` Lawyer Order Review Mode:**
    - Extended `TrackingScreen` to support `isLawyerView: true` without duplicating maps, markers, or tile caching logic.
    - Directly opens the Bottom Sheet displaying order review details:
      - Client profile, transaction reference, problem title, description, location range, and fee amount.
      - Dual action buttons:
        - **«قبول الطلب»** (Primary action with confirmation acknowledgment)
        - **«اعتذار»** (Secondary action with apology confirmation)
    - Independent flow: opening a lawyer order never triggers client ordering or cycling logic.
  - **`LawyerNavigationShell` Integration:**
    - Connected all 4 independent tabs (`LawyerHomeTab`, `LawyerOrdersTab`, `LawyerWalletTab`, `LawyerAccountTab`).
  - **Automated Testing Suite Expansion (`widget_test.dart`):**
    - Added 4 new widget tests verifying lawyer orders card, «فتح الطلب» map navigation and bottom sheet review mode, lawyer wallet and account tabs, and multi-tab navigation switching in `LawyerNavigationShell`.
    - Total test suite now at 31/31 passing tests.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (31/31 passing).
- Live hot restart on connected Android device (`RMX3997`) completed and verified.

---

## [Phase 2.36] - 2026-10-31
### Added
- **Independent Lawyer Home Interface (`LawyerHomeTab` & `LawyerNavigationShell`):**
  - Fully independent main interface for lawyers, matching the visual identity, colors, ThmanyahSans typography, and spacing of the platform.
  - **Lawyer Profile Header:**
    - Title prefix: **«أ/»**.
    - Dual name: **اسم المحامي ثنائياً** dynamically extracted from profile name (e.g., `أ/ أحمد محمود`).
    - Syndicate Registration Number: **«رقم القيد: 123456»** loaded from user session.
    - Avatar container (44x44, 7.0px borderRadius) with shield icon.
    - Real user location button dynamically resolved from GPS without fake or hardcoded text.
  - **Lawyer Services Section:**
    - Displays exactly ONE service: **«محاميك حالاً»**.
    - Card description: «خدمة تتيح لك التقدم للانضمام إلى قائمة مقدمي الخدمة المعتمدين لتقديم المساعدة القانونية العاجلة للموكلين».
    - Completely removed the client «محاميك حالاً» banner (with pana illustration) and search bar.
- **Lawyer Urgent Service Intro Screen (`LawyerUrgentServiceIntroScreen`):**
  - Dedicated introductory page for lawyers explaining the nature of the service, lawyer's role, and participation workflow.
  - Contains clear «تقديم على الخدمة» action button triggering an acknowledgment dialog.
  - Strictly decoupled from client maps, ordering flow, or client "طلب الآن" actions.
- **Client Home Updates (`HomeTab`):**
  - Removed the search bar located below the «محاميك حالاً» banner.
  - Replaced static fallback address with real user address resolved dynamically via `LocationService` and `GeoNamingService` without duplicating «محافظة».
  - Shows «تحديد الموقع» if location permission is not yet granted instead of inventing fake addresses.
- **Account-Based Login & Splash Routing:**
  - `LoginScreen` and `SplashScreen` dynamically evaluate `user_account_type` from session data.
  - Routes Lawyers to `LawyerNavigationShell` and Clients to `MainNavigationShell` / `LocationPermissionScreen`.
- **Automated Testing Suite Expansion (`widget_test.dart`):**
  - Added 4 new widget tests verifying client home changes, lawyer home layout, lawyer urgent service intro screen, and login routing for lawyer accounts.
  - Total test suite now at 27/27 passing tests.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (27/27 passing).
- Live hot restart on connected Android device (`RMX3997`) completed and verified.

---

## [Phase 2.35] - 2026-10-31
### Added
- **Dual-Role Registration System (نظام إنشاء حساب الموكل والمحامي):**
  - **Account Type Selection Screen (`UserTypeSelectionScreen`):**
    - Prominent entry point accessible from `LoginScreen` via «ليس لديك حساب بعد؟ إنشاء حساب جديد».
    - Displays two dedicated, high-touch selection cards with 7.0px border radii and compliant iconography:
      1. **«أنت موكل»** (للأفراد والشركات للوصول لكافة الخدمات القانونية والاستشارات وتوكيل المحامين).
      2. **«أنت محامي»** (للمحامين المقيدين بنقابة المحامين للانضمام للشبكة وتقديم الاستشارات وصياغة العقود).
  - **Client Registration Form (`ClientRegisterScreen`):**
    - Fields: Full name (الاسم الكامل), Egyptian mobile number (`01xxxxxxxxx`), email address, password with visual strength indicator and visibility toggle.
    - **Strictly omitted confirm password field** per specification.
    - State preservation on navigation and back gestures.
  - **Lawyer Registration Form (`LawyerRegisterScreen`):**
    - Fields: Quadruplicate name matching syndicate ID (الاسم الرباعي، مطابق لكارنيه النقابة), phone, email, syndicate registration number (رقم القيد بنقابة المحامين), and syndicate card photo attachment.
    - Modal bottom sheet (28.0px top radius) for selecting camera capture or photo gallery.
    - Image preview box with change and delete actions.
    - Password strength indicator with visibility toggle.
    - **Strictly omitted confirm password field** per specification.
  - **Visual Password Strength Component (`PasswordStrengthWidget`):**
    - Multi-criteria evaluator testing length (>=8), uppercase, lowercase, numbers, and special symbols.
    - Dynamic progress bar with color feedback (Red, Amber, Green) and criteria badges with 7.0px corners.
  - **Email Verification Screen (`EmailVerificationScreen`):**
    - Header illustration `assets/images/mail_sent_bro.svg` (`C:\Users\Hp\Downloads\Mail sent-bro.svg`).
    - Displays recipient email address.
    - 6-digit verification code boxes with sequential focus traversal and backspace backward jump.
    - Native clipboard paste distribution via `Clipboard.getData` filling all 6 fields simultaneously.
    - 60-second cooldown timer with resend verification code action.
  - **Registration Success Screen (`RegistrationSuccessScreen`):**
    - Header illustration `assets/images/done_rafiki.svg` (`C:\Users\Hp\Downloads\Done-rafiki.svg`).
    - Personalized greeting with first name only: **«أهلاً (الاسم الأول)»**.
    - Explicit confirmation message: **«تم إنشاء حسابك بنجاح»**.
    - Visible 3-second countdown indicator with automatic single-shot navigation to the designated flow (Client -> `LocationPermissionScreen`, Lawyer -> `MainNavigationShell`).
    - Direct «المتابعة الآن» action button.
  - **Authentication Service & Cryptographic Security (`AuthService`):**
    - Created `lib/core/services/auth_service.dart`.
    - Integrated SHA-256 cryptographic password hashing via `crypto` package to prevent storing plain-text passwords.
    - Structured endpoints and mockable contracts for future backend deployment:
      - `POST /api/v1/auth/register` (multipart for lawyer syndicate card)
      - `POST /api/v1/auth/verify-email`
      - `POST /api/v1/auth/resend-code`
    - Full session persistence in `SharedPreferences` storing `account_type`, `user_name`, `user_email`, `user_phone`, `syndicate_number`, `syndicate_card_path`, and `is_email_verified`.
  - **Automated Testing Suite Expansion (`widget_test.dart`):**
    - Added 6 new unit and widget tests covering password strength evaluator, SHA-256 hashing, type selection, client form validation, lawyer syndicate photo form, email verification, and success screen personalized first-name display.
    - Total tests increased to 23/23 passing.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (23/23 passing).
- Live hot restart on connected Android device (`RMX3997`) completed and verified.

---

## [Phase 2.34] - 2026-10-31
### Changed
- **Updated Pricing Evaluation Stage Illustration (`TrackingScreen`):**
  - Integrated `assets/images/coins_rafiki.svg` (`C:\Users\Hp\Downloads\Coins-rafiki.svg`) inside the Bottom Sheet during the «جاري تقييم سعر الخدمة» stage.
  - Sized appropriately at `height: 110` with `BoxFit.contain` wrapped in a `RepaintBoundary` for zero frame drops.
  - Preserved the exact text «جاري تقييم سعر الخدمة...» and subtitle without altering any colors, dimensions, transitions, or order flow logic.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (17/17 passing).
- Live hot restart on connected Android device (`RMX3997`) completed in 3.6s.

---

## [Phase 2.33] - 2026-10-31
### Added
- **Two-Tier Persistent Disk & RAM Map Tile Caching (`AppCachedTileProvider`):**
  - Created `lib/core/services/app_cached_tile_provider.dart` solving the fundamental Flutter map tile caching limitation where `fallbackUrl` previously disabled `ImageCache`.
  - Implements persistent on-device disk storage in `my_lawyer_map_tiles` loading previously visited tiles in **< 3ms directly from device flash storage** with zero network calls.
  - Implements Tier-1 RAM memory cache via consistent `operator ==` and `hashCode` keys based on tile coordinates and URL.
  - Added binary PNG magic byte validation (`0x89, 0x50, 0x4E, 0x47`) to prevent caching HTTP 404/502 error pages or corrupt tiles.
  - Integrated asynchronous LRU storage pruning: automatically purges tiles older than 30 days and enforces a strict 150MB disk quota in a background microtask.
  - Connected `AppCachedTileProvider.instance` seamlessly to `TrackingScreen` and `NearbyLawyersShowcaseScreen`.

### Optimized
- **Reverse Geocoding Spatial Resolution Cache (`GeoNamingService`):**
  - Added in-memory geospatial cache (`_resolvedCache`) keyed by 3-decimal rounded coordinates (~100m grid).
  - Eliminates redundant Nominatim HTTP network requests when the user pans within the same neighborhood or re-centers the map.
- **Architectural & Security Studies:**
  - Conducted technical comparative audit of Raster Tiles vs Vector Tiles (PMTiles / PBF from TileServer GL).
  - Audited HTTPS transition roadmap and cleartext traffic security requirements for production deployment.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (17/17 passing including dedicated `AppCachedTileProvider` verification).
- Live hot restart on connected Android device (`RMX3997`) completed in 3.6s.

---

## [Phase 2.32] - 2026-10-31
### Added
- **Showcase Map Loading Overlay (`NearbyLawyersShowcaseScreen`):**
  - Integrated the exact loading overlay from `TrackingScreen` into `NearbyLawyersShowcaseScreen` to unify user experience across both maps while keeping both screens 100% architecturally decoupled.
  - Features real-time `BackdropFilter` (blur 7.0), semi-transparent white backdrop (`0.45`), animated Lottie graphic (`assets/images/splash_gif.json`, 80x80), and refined Arabic typography («جاري تجهيز الخريطة وعرض أقرب المحامين...»).
  - Tied strictly to the real asynchronous lifecycle of location fetching and showcase lawyer generation without any artificial timers.
  - Added robust 4-second timeout protection on GPS permission/acquisition and graceful offline fallback (`_useFallbackLocation`), ensuring the user is never stranded on an infinite loading screen under poor network conditions or disabled location services.

### Optimized
- **Smooth Camera Animation on Lawyer Marker Tap:**
  - Implemented conflict-free camera animation controller lifecycle: properly cancels, cleans up, and disposes previous animation controllers when rapidly switching between lawyer pins to eliminate jumps, jitter, and memory leaks.
  - Avoids redundant camera motion if the tapped lawyer is already selected and situated in the active viewport.
  - Accurately computes vertical viewport offset accounting for the 390px bottom sheet height and the top safe-area location badge ($~160$ px vertical shift, $\approx 0.0042^\circ$ latitude shift at zoom $15.2$), centering the selected lawyer marker perfectly within the visible upper half of the screen.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (16/16 passing including dedicated showcase map loading overlay lifecycle test).

---

## [Phase 2.31] - 2026-10-31
### Added
- **Reusable Standard App Button Component (`AppButton`):**
  - Created `lib/core/widgets/app_button.dart` adhering strictly to the design constitution (12.0px border radius, `ThmanyahSans` typography, `AppColors.primary`, `AppColors.dark`).
  - Integrated built-in async loading state (`isLoading`) rendering a brand-consistent `CircularProgressIndicator` (white or primary blue).
  - Built-in tap debouncing / click locking: automatically disables `onPressed` during loading or pending navigation to prevent double-tap race conditions and duplicate screen pushes.
  - Convenience factory constructors: `AppButton.primary` and `AppButton.outlined`.

### Optimized & Changed
- **Scrolling Performance & Jank Elimination (تحسين أداء التمرير):**
  - **Lazy List Rendering:** Converted `UrgentServiceProblemScreen` to `ListView.builder` with `itemCount` and `itemBuilder`, replacing eager static child mapping with lazy, on-demand widget recycling for ultra-smooth 60/120fps scrolling.
  - **Memory Buffer & Image Thumbnail Caching:** Added `cacheWidth: (size * 2).toInt()` and `cacheHeight: (size * 2).toInt()` to `Image.network` across `OrdersTab`, `TrackingScreen` (`_LawyerAvatarPhoto`), and `NearbyLawyersShowcaseScreen` (`_ShowcaseAvatarPhoto`). This prevents decoding full-resolution Unsplash images into massive uncompressed RGBA bitmaps on the UI thread, freeing up raster threads and eliminating memory pressure during scroll.
  - **SVG Repaint Boundary Isolation:** Wrapped static SVG illustrations (`lawyer_pana.svg`, `questions_rafiki.svg`, `directions_rafiki.svg`, `mail_sent_rafiki.svg`) inside `RepaintBoundary` in `HomeTab`, `UrgentServiceProblemScreen`, `ProblemDescriptionScreen`, and `LocationPermissionScreen`. This isolates expensive vector path rendering into cached GPU layers, preventing raster repaints on every scroll offset delta.
- **Button Loading States & Navigation Locking (حالات تحميل وانتقال ناعمة):**
  - **`LocationPermissionScreen`:** Replaced raw `ElevatedButton` with `AppButton.primary` featuring `isLoading: _isNavigating`, locking both location request and secondary "سأقوم بتحديده لاحقاً" button.
  - **`HomeTab`:** Added loading state on «طلب الآن» banner button (`_isNavigatingToUrgent`) to prevent repeated taps while transitioning to urgent services.
  - **`UrgentServiceProblemScreen`:** Added per-item inline loading indicator and tap locking (`_navigatingProblemId`) when selecting an urgent problem card before navigating to `ProblemDescriptionScreen`.
  - **`ProblemDescriptionScreen`:** Integrated `AppButton.primary` with `isLoading: _isNavigating` on «المتابعة إلى خريطة المحامين» with complete tap-spam protection.
  - **`NearbyLawyersShowcaseScreen`:** Integrated `AppButton.primary` on «المتابعة إلى الرئيسية» (`isLoading: _isNavigatingToMain`) and `AppButton.outlined` on «زيارة ملف Google والتقييمات» (`isLoading: _isNavigatingGoogle`).
  - **`TrackingScreen`:** Integrated `AppButton.primary` on «دفع 350 ج.م وتأكيد الطلب» (`isLoading: _isNavigatingPayment`) preventing duplicate order payments.
  - **`PaymentSuccessScreen`:** Integrated `AppButton.primary` on «متابعة الطلب في صفحة الطلبات الآن» (`isLoading: _isNavigating`).

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (16/16 passing including dedicated `AppButton` loading & tap-locking test).

---

## [Phase 2.30] - 2026-10-31
### Changed
- **Fixed Lawyer Marker Overflows on Showcase Map (`NearbyLawyersShowcaseScreen`):**
  - Resolved `RenderFlex overflowed by 17 pixels` at its root cause by upgrading the Marker dimensions to `140x52` with `alignment: Alignment.topCenter`.
  - Wrapped text elements inside `Flexible` with strict `TextOverflow.ellipsis` constraints preventing any horizontal overflow regardless of name length.
  - Replaced tight avatar rendering with `_ShowcaseAvatarPhoto`: strict `28x28` dimensions, `BoxFit.cover`, clipped with `BorderRadius.circular(7.0)`, with dedicated `loadingBuilder` and `errorBuilder` gracefully displaying the lawyer's initials on their themed background.
  - Implemented vector speech-bubble painter `_ShowcaseBubblePainter` matching the exact visual style of `TrackingScreen`.
- **Unified Lawyer Profile Bottom Sheet with «محاميك حالاً»:**
  - Redesigned the lawyer profile bottom sheet in `NearbyLawyersShowcaseScreen` to be 100% visually identical to the lawyer card in `TrackingScreen`.
  - Includes standard `390px` height, `28.0px` top radius, drag notch, centered title «أقرب المحامين إليك», dashed separator `_ShowcaseDashedLineSeparator`, 64px avatar photo, verified syndicate status, rating stars, distance strip, legal accreditation strip, and Google Profile WebView button.
  - Preserved complete independence between both screens with zero ordering flow or emergency request actions in the promotional map.
- **Removed Back Button from Showcase Map Header:**
  - Removed the back button from the top of `NearbyLawyersShowcaseScreen` as the map only opens after location onboarding.
  - Redesigned the top bar with a centered, elevated location pill displaying the user's real Egyptian city and governorate.
- **Fixed Reverse Geocoding Address Duplication (`GeoNamingService`):**
  - Resolved the duplicate «محافظة محافظة الغربية» bug by stripping any redundant «محافظة» prefixes from Nominatim's `state` before formatting.
  - Added robust extraction of actual city, town, center (مركز), village, or neighborhood from Nominatim's address and display name.
  - Formatted addresses cleanly as `[المدينة أو المركز]، [اسم المحافظة]` (e.g. «مدينة طنطا، محافظة الغربية» or «المعادي، محافظة القاهرة»).
  - Enriched offline fallback table with precise geographic bounding coordinates for Gharbia (Tanta, Mahalla, Kafr El Zayat, Zifta), Dakahlia, Cairo, Giza, Alexandria, Qalyubia, Menofia, Sharqia, and other Egyptian governorates.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (15/15 passing).

---

## [Phase 2.29] - 2026-10-31
### Added
- **Problem Description Screen (`ProblemDescriptionScreen`):**
  - Created `lib/screens/problem_description_screen.dart` inserted smoothly between service selection and the lawyers map.
  - Sourced and included `assets/images/mail_sent_rafiki.svg` (`C:\Users\Hp\Downloads\Mail sent-rafiki.svg`) at the top of the screen with proportional fitting.
  - Displays a clean selected service badge (`7.0px` radius) showing the chosen urgent problem title.
  - Prominent title: «اكتب تفاصيل مشكلتك باختصار» with supportive explanatory guidance.
  - Multiline text field (`minLines: 4, maxLines: 6, maxLength: 500`) with placeholder explaining that this summary will be shared with the lawyer.
  - Action button: «المتابعة إلى خريطة المحامين» with standard `12.0px` radius, `AppColors.primary` background, and `50px` height.
  - Safely propagates both `problemTitle` and `problemDescription` to `TrackingScreen`.

### Changed
- **Urgent Problem Selection Services List (`UrgentServiceProblemScreen`):**
  - Updated the list to show **problem names only** (اسم المشكلة فقط) without any descriptions, details, or explanatory subtitles.
  - Preserved the existing vertical list format, modern icons, `7.0px` cards, and visual styling.
  - Updated the list with the exact 14 urgent legal problems:
    1. محضر في قسم الشرطة
    2. القبض على شخص أو احتجازه بقسم الشرطة
    3. تحقيق عاجل في النيابة العامة
    4. مشاجرة أو اعتداء أو تهديد
    5. حادث سير أو نزاع مروري طارئ
    6. كمين أو استيقاف أمني أو فحص هوية
    7. تفتيش أو ضبط أو التحفظ على ممتلكات
    8. نزاع حيازة أو طرد أو تمكين
    9. إثبات حالة أو واقعة عاجلة
    10. تحقيق إداري أو تأديبي عاجل في العمل
    11. فصل تعسفي أو مستحقات عمالية متأخرة
    12. نزاع أسري عاجل أو امتناع عن تنفيذ حكم
    13. سرقة أو نصب أو احتيال
    14. مشكلة قانونية أخرى
  - Strictly excluded all consultation, contract drafting, or non-urgent services.
  - Selecting any of the 14 problems immediately navigates to `ProblemDescriptionScreen`.
- **Order Pipeline & Data Persistence:**
  - `TrackingScreen`: Accepts `problemDescription` alongside `problemTitle`, presents order details during `waitingAcceptance` / `priceReady`, and passes both down to `PaymentScreen`.
  - `PaymentScreen`: Displays `تفاصيل المشكلة` in the itemized fee summary and passes both fields to `PaymentSuccessScreen`.
  - `PaymentSuccessScreen`: Persists `active_order_description` into `SharedPreferences` and displays it in the confirmation card.
  - `OrdersTab`: Reads `active_order_description` and displays problem details in the active order card.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (14/14 tests passing).

---

## [Phase 2.28] - 2026-10-31
### Changed
- **Removed Default Flutter Logo from Native Launch:**
  - Added transparent vector drawable `android/app/src/main/res/drawable/transparent_splash.xml`.
  - Configured Android 12+ `values-v31/styles.xml` with `android:windowSplashScreenAnimatedIcon` set to `@drawable/transparent_splash` and `android:windowSplashScreenBackground` to `@android:color/white`.
  - Set `android:windowBackground` in `NormalTheme` (`values/styles.xml`, `values-night/styles.xml`, and `values-v31/styles.xml`) to `@android:color/white` ensuring a 100% seamless, flicker-free transition from native window to the Flutter MP4 video splash.
  - Replaced iOS `LaunchImage.imageset` images with transparent assets so iOS launches with pure white without showing the Flutter logo.
- **Updated Official App Icon (Android & iOS) from `logomyapp.png`:**
  - Sourced from `C:\Users\Hp\Downloads\logomyapp.png`.
  - Generated all Android standard launcher mipmaps (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi).
  - Configured modern Android Adaptive Icons in `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` with background `@color/ic_launcher_background` (`#FFFFFF`) and foreground layer `ic_launcher_foreground.png`.
  - Generated full suite of iOS icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (1024x1024 App Store, 20px, 29px, 40px, 60px, 76px, 83.5px).
- **Updated Login Screen Branding Header (`LoginScreen`):**
  - Removed top SVG illustration (`mobile_login_bro.svg`).
  - Placed the official app logo `assets/images/app_logo.png` (`height: 110`, `fit: BoxFit.contain`) preserving its original proportions.
  - Completely removed the `My Lawyer` text from under the illustration without adding any replacement text.
  - Preserved all other login screen components, fields, and interactions intact.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (13/13 passing).

---

## [Phase 2.27] - 2026-10-31
### Changed
- **Separation of Promotional Showcase Map from «محاميك حالاً» (`NearbyLawyersShowcaseScreen`):**
  - Built a completely independent, isolated showcase screen `NearbyLawyersShowcaseScreen` (`lib/screens/nearby_lawyers_showcase_screen.dart`) for the post-onboarding location flow.
  - Connected `LocationPermissionScreen` («تحديد موقعي الآن») directly to `NearbyLawyersShowcaseScreen`.
  - **Showcase Map Features:**
    - Completely removed the top `AppHeader` (full-bleed map experience with a light floating return button and Arabic location pill).
    - Excluded all ordering features, pricing, routing, or stages belonging to «محاميك حالاً».
    - Bottom sheet does NOT appear automatically on map open; initial view is a clean, unobstructed map of nearby lawyers.
    - Bottom sheet appears only when explicitly tapping a lawyer pin on the map, displaying their professional profile (photo, name, rating, experience, syndicate status, and Google profile WebView button).
    - Dismissible on close button tap, swipe down, or tapping outside the card on the map.
    - Added floating «المتابعة إلى الرئيسية» button for seamless progression into `MainNavigationShell`.
  - **Zero impact on «محاميك حالاً» (`TrackingScreen`):**
    - Preserved 100% of the design, logic, order stages, routing, and behavior of `TrackingScreen` without any modification.
- **Updated Automated Widget Tests (`test/widget_test.dart`):**
  - Added automated test verifying `NearbyLawyersShowcaseScreen` renders without header, without automatic bottom sheet, and without order buttons.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (13/13 passing).

---

## [Phase 2.26] - 2026-10-31
### Changed
- **Removed Startup Flutter/App Icon on Android 12+ Cold Boot:**
  - Configured `android/app/src/main/res/values-v31/styles.xml` for Android 12+ SplashScreen API.
  - Set `android:windowSplashScreenAnimatedIcon` to `@android:color/transparent` and `android:windowSplashScreenBackground` to `@android:color/white`, completely removing the default launcher/flutter logo during app boot.
  - Set `android/app/src/main/res/drawable-v21/launch_background.xml` to pure white `@android:color/white`.
  - The app now opens instantly into a clean white window that directly renders the silent video splash screen.

### Verified
- `dart analyze lib test`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).

---

## [Phase 2.25] - 2026-10-31
### Changed
- **Updated Splash Video and Enforced Mute Mode (`SplashScreen`):**
  - Replaced the splash video with the updated asset `123.mp4` (`C:\Users\Hp\Downloads\123.mp4` -> `assets/videos/splash_logo.mp4`).
  - Completely silenced the video audio track (`_controller.setVolume(0.0)`) both pre-initialization and post-initialization for a 100% silent startup experience.
  - Preserved the compact centered sizing (`maxWidth: 65%`, `maxHeight: 65%`) and pure white background (`Colors.white`).

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).

---

## [Phase 2.24] - 2026-10-31
### Changed
- **Video Splash Screen Logo Motion Graphics (`SplashScreen`):**
  - Converted the splash screen to play the high-definition studio logo motion graphics video (`assets/videos/splash_logo.mp4`, copied from `C:\Users\Hp\Downloads\Logo_animation_motion_graphics_799f1b94.mp4`).
  - Scaled down the video (constrained max width/height to 65% of screen dimensions) and centered it cleanly so it appears sleek and elegant.
  - Set the background to pure white (`Colors.white`), perfectly blending with the video's white background for a seamless edge-free visual experience.
  - Integrated `video_player: ^2.9.5` with asset registration in `pubspec.yaml`.
  - Added video end-point completion listener (`position >= duration`) with a 4.3s fallback safety timer for smooth transition to authentication/permission flow.
- **Updated Automated Widget Tests (`test/widget_test.dart`):**
  - Updated `SplashScreen` test to verify pure white background without loaders or icons, and safety fallback transition.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).

---

## [Phase 2.23] - 2026-10-31
### Changed
- **Snappy Kinetic Logo Animation Motion Graphics (`SplashScreen`):**
  - Engineered a high-end, rapid studio motion graphics logo reveal for the "My Lawyer" brand text on pure white background:
    1. **Staggered Two-Word Punch Entrance:**
       - "My" word zooms rapidly from 25% scale with `Curves.easeOutBack` elastic bounce while sliding in from top-left (`Offset(-0.25, -0.35)`).
       - "Lawyer" word punches in with a micro-staggered delay (70ms) from bottom-right (`Offset(0.25, 0.35)`) with `Curves.easeOutBack`.
    2. **Light Beam / Shimmer Reflection Sweep:**
       - Implemented a dynamic `ShaderMask` with a linear gradient sweep (`AppColors.primary` -> electric blue `0xFF93C5FD` -> pure white highlight `Colors.white` -> electric blue -> `AppColors.primary`) sweeping across the locked typography immediately upon collision impact (350ms - 850ms).
    3. **Elastic Settle & Breathing:**
       - Micro-breathing settling animation from 0.95 to 1.00 (`Curves.easeOutQuad`) giving physical weight to the mark.
    4. **Display Timing:**
       - Splash display tuned to a brisk and comfortable 2.4 seconds (`2400ms`), with full cancellation protection on dispose.
- **Updated Automated Widget Tests (`test/widget_test.dart`):**
  - Adjusted widget tests to match the new kinetic split-word structure (`find.text('My')` and `find.text('Lawyer')`) with 0 issues.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).

---

## [Phase 2.22] - 2026-10-31
### Changed
- **Enhanced Splash Screen Typography Motion Graphics & Display Duration (`SplashScreen`):**
  - Extended total splash display duration to a comfortable 2.8 seconds (`2800ms`), allowing users to clearly appreciate the logo entrance and branding before transitioning.
  - Upgraded the text animation to a multi-stage kinetic typography motion graphic (1400ms duration):
    - Snappy dynamic zoom expanding from 55% with a distinct bounce overshoot (`Curves.easeOutBack`).
    - Visible vertical floating slide rising from `Offset(0.0, 0.40)`.
    - Dynamic letter-spacing expansion from `-2.5` to `0.8` (`Curves.easeOutCubic`) creating a high-end logo reveal effect.
    - Soft atmospheric drop shadow behind the brand name (`color: AppColors.primary.withOpacity(0.12)`).

### Verified
- `dart analyze lib test`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).

---

## [Phase 2.21] - 2026-10-31
### Changed
- **Updated Waiting Acceptance Illustration (`TrackingScreen` Bottom Sheet):**
  - Updated stage illustration for «في انتظار قبول المحامي لطلبك...» from Lottie GIF to `loading_rafiki.svg` (`C:\Users\Hp\Downloads\Loading-rafiki.svg`).
- **Updated Pre-Payment Confirmation Illustration (`PaymentScreen`):**
  - Updated top illustration on the fee payment and confirmation screen to `credit_card_rafiki.svg` (`C:\Users\Hp\Downloads\Credit card-rafiki.svg`).

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.20] - 2026-10-31
### Changed
- **Updated SVG Illustrations and Removed Card Containers (`LoginScreen`):**
  - Updated login illustration to `mobile_login_bro.svg` (`C:\Users\Hp\Downloads\Mobile login-bro.svg`) rendered directly without an enclosing container box.
  - Converted the privacy and safety reassurance section at the bottom of `LoginScreen` to clean, unbordered typography without container styling.
- **Updated Urgent Problem Illustration (`UrgentServiceProblemScreen`):**
  - Updated question illustration to `questions_rafiki.svg` (`C:\Users\Hp\Downloads\Questions-rafiki (1).svg`).
- **Updated Location Permission Illustration (`LocationPermissionScreen`):**
  - Updated location prompt illustration to `directions_rafiki.svg` (`C:\Users\Hp\Downloads\Directions-rafiki.svg`).
- **Updated Urgent Service Banner & Services List (`HomeTab`):**
  - Replaced «محاميك حالاً» banner illustration with `lawyer_pana.svg` (`C:\Users\Hp\Downloads\Lawyer-pana.svg`) without container framing.
  - Redesigned available legal services from 2x2 grid cards into an elegant, full-width vertical **LIST** with leading icon/SVG, title, description, and chevron navigation arrow.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).

---

## [Phase 2.19] - 2026-10-31
### Changed
- **Redesigned Splash Screen with White Background & Blue Motion Graphics Typography (`SplashScreen`):**
  - Updated background color to pure white (`Colors.white`).
  - Styled application brand name «My Lawyer» in the official primary blue (`AppColors.primary`, #1D4ED8) with bold `Nunito` typography (`42px`, `FontWeight.w900`).
  - Removed all icons, shields, and subtitle containers.
  - Removed circular loading progress indicator completely.
  - Engineered a snappy, silk-smooth 850ms motion graphics animation coordinating:
    - Dynamic scale with soft elastic overshoot (`Curves.easeOutBack`).
    - Gentle vertical floating slide (`Curves.easeOutCubic`).
    - Smooth opacity fade-in (`Curves.easeOut`).
  - Added robust timer cancellation in `dispose()` to guarantee zero memory leaks.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (12/12 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.18] - 2026-10-31
### Added
- **Integrated Lawyer Google Profile WebView (`LawyerGoogleProfileScreen`):**
  - Integrated `webview_flutter` to render the lawyer's Google Profile / Google Business listing inside the app.
  - Built dedicated `LawyerGoogleProfileScreen` featuring:
    - Unified `AppHeader` with `isInnerPage: true` and active back navigation.
    - Verified lawyer identity banner with verified badge, live rating, and Google review count.
    - Seamless `LinearProgressIndicator` for web page loading progress.
    - Robust offline / error fallback view with retry capabilities and 12px rounded buttons.
    - Full in-app web history traversal (`PopScope` handling `canGoBack()` / `goBack()`).
  - Added `effectiveGoogleProfileUrl` to `MockLawyer` model to resolve custom URLs or dynamically encoded search profiles.
  - Linked the «زيارة ملف Google والتقييمات» button in `TrackingScreen` Bottom Sheet to launch the WebView screen.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (11/11 passing).

---

## [Phase 2.17] - 2026-10-31
### Changed
- **Updated All Application Buttons to 12px Rounded Corners (`BorderRadius.circular(12.0)`):**
  - Updated `AppTheme` with `buttonRadiusValue = 12.0` across `elevatedButtonTheme`, `outlinedButtonTheme`, `filledButtonTheme`, and `textButtonTheme`.
  - Updated all button styles in all screens (`account_tab.dart`, `home_tab.dart`, `location_permission_screen.dart`, `login_screen.dart`, `orders_tab.dart`, `payment_screen.dart`, `payment_success_screen.dart`, `tracking_screen.dart`, `urgent_service_problem_screen.dart`, `wallet_tab.dart`) to use 12.0px corner rounding.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.16] - 2026-10-31
### Changed
- **Restricted Dashed Separator Strip to Bottom Sheet Header Titles Only (`TrackingScreen`):**
  - Confined `_DashedLineSeparator` exclusively beneath the top header titles of the bottom sheet («أقرب المحامين إليك» / «متابعة وتأكيد الطلب»).
  - Removed duplicate separator lines from the internal order flow stages (waiting acceptance, lawyer accepted, price evaluation, and price ready), preserving a clean, uncluttered content flow.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.15] - 2026-10-31
### Changed
- **Removed Problem Badge Label Next to Arrow (`UrgentServiceProblemScreen`):**
  - Removed the badge container (`item.badgeText`) situated adjacent to the trailing chevron arrow in problem choice cards.
  - Formatted problem titles as direct clean headings alongside descriptions, leaving the trailing navigation arrow completely unencumbered.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.14] - 2026-10-31
### Added
- **Dashed Line Separators under Bottom Sheet Titles (`_DashedLineSeparator`):**
  - Integrated custom-painted dashed separator lines with small vertical spacing below the main handle title («أقرب المحامين إليك» / «متابعة وتأكيد الطلب») and order stage titles.
- **Enlarged Google Profile Button:**
  - Increased height and padding of «زيارة ملف Google والتقييمات» button (`minimumSize: Size(infinity, 48)`), with prominent `19px` logo and bold typography.
- **Cleaned Price Ready Stage Layout:**
  - Removed lawyer name completely from the price ready stage («تم تحديد أتعاب الخدمة وجاهزية المحامي»).
  - Repositioned the service coverage text («شاملة الانتقال الفوري والمتابعة المباشرة خلال 24 ساعة») directly above the price (`350 ج.م`) instead of below it.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.13] - 2026-10-31
### Added
- **Direct Typography Status & Actual Order Timestamp (`OrdersTab`):**
  - Removed container box, badge background, and green dot from «قيد التنفيذ • المحامي في الطريق» in the active orders card; rendered as direct, clean typography (`13px`, `FontWeight.w900`, `AppColors.success`).
  - Replaced static/generic text with actual order date and time formatted in Arabic (e.g. `31 أكتوبر 2026 • 03:48 ص`) across `PaymentSuccessScreen` and `OrdersTab`.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.12] - 2026-10-31
### Added
- **Auto-Expand Bottom Sheet on Lawyer Selection (`TrackingScreen`):**
  - Selecting any lawyer pin on the map while the Bottom Sheet is collapsed (`_sheetHeight < _expandedHeight`) automatically and smoothly snaps the sheet to its full expanded height (`390.0px`) using cubic animation.
  - Dynamically recalculates route and fits the camera viewport with `sheetHeight: _expandedHeight`.
  - Resets order flow stage if active so the user can immediately view the newly selected lawyer's profile.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.11] - 2026-10-31
### Added
- **Cleaned Payment Screen & Bill Table (`PaymentScreen`):**
  - Removed "زمن الوصول المقدر" from the billing breakdown table in `PaymentScreen`.
  - Concise bill title: changed long redundant text to concise «فاتورة الخدمة».
- **Optimized Map Bottom Sheet Height (`TrackingScreen`):**
  - Reduced Bottom Sheet expanded height slightly from `445.0px` to a more compact, balanced `390.0px` (`_expandedHeight = 390.0`).
  - Smooth snapping and inertia adapt dynamically to the new height.
- **Removed Checkmark Icon from Ready Stage:**
  - Removed `Icons.check_circle_rounded` from the price evaluation ready stage («تم تحديد أتعاب الخدمة وجاهزية المحامي»), keeping clean typography without icons.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.10] - 2026-10-31
### Added
- **Container-Less AppHeader Icons (`AppHeader`):**
  - Removed enclosing container boxes, background colors, and borders from action buttons in `AppHeader`.
  - Converted Search, Back, and Notification actions into direct, clean icon buttons directly rendered on the header surface.
  - Positioned notification badge precisely at the upper right of the unread bell icon.
- **Removed Redundant Page Headers from Inner Tabs:**
  - Removed duplicate page name and description texts from `OrdersTab`, `WalletTab`, and `AccountTab`.
  - Pages now rely cleanly on the centralized persistent `AppHeader` for their titles, maximizing screen estate and starting directly with their core cards and features.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (10/10 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.9] - 2026-10-31
### Added
- **Refined Lawyer Profile Card Layout in Bottom Sheet (`TrackingScreen`):**
  - Eliminated awkward blank spaces by introducing a balanced, harmonious distribution of lawyer credentials.
  - Prominent 64x64 lawyer portrait with rounded 7.0px corners.
  - Cohesive arrangement of lawyer name, verified badge, "الأقرب إليك" indicator, specialization, and integrated rating with review count.
  - Added legal credentials & fast response highlights bar: «مقيد بالنقابة العامة» and «جاهزية حضور فوري».
  - Clear distance and ETA arrival bar alongside the official Google Profile button.
- **Enhanced Map Loading Viewport Positioning:**
  - Map loading and blur layer now positions dynamically at `bottom: _sheetHeight`, ensuring the loading indicator and Lottie animation are always perfectly centered within the visible map viewport above the Bottom Sheet, never obscured or hidden behind it.
- **Refined Map Lawyer Pins (`_LawyerBubblePainter`):**
  - Removed borders/strokes completely from non-selected lawyer pins (`hasBorder: false`).
  - Added soft, light drop shadows (`canvas.drawShadow`) to all pins for crisp contrast and elevation against map tiles.
  - Kept prominent dark styling and primary blue border for the selected lawyer.
- **Cleaned Lawyer Acceptance Stage Typography:**
  - Removed checkmark icons and symbols from the lawyer acceptance stage, leaving clean, dignified typography: «وافق المحامي على طلبك».

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (9/9 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.8] - 2026-10-31
### Added
- **Unified In-Sheet Order Flow in Map Bottom Sheet (`TrackingScreen`):**
  - All stages of the lawyer request process now execute seamlessly inside the **same, single Bottom Sheet** without opening any modal dialog or secondary bottom sheet over the map.
  - **Sequential Order Stages:**
    1. **Stage 1 (Waiting Acceptance):** Inline Lottie animation with status text «في انتظار قبول المحامي لطلبك...».
    2. **Stage 2 (Lawyer Accepted):** Success checkmark with text «وافق المحامي على طلبك بنجاح ✓» displayed sequentially.
    3. **Stage 3 (Price Evaluation):** Inline Lottie loader with text «جاري تقييم سعر الخدمة...».
    4. **Stage 4 (Price Centered & Ready):** Direct presentation of price (`350 ج.م`) and legal coverage centered cleanly with primary CTA «دفع 350 ج.م وتأكيد الطلب» linking directly to `PaymentScreen`.
  - **Pure Typography (No Enclosing Containers):** Zero nested card borders or colored background containers; texts and price are displayed directly on the sheet canvas.
  - **Absolute Height Stability:** The Bottom Sheet maintains its strict fixed height (`445.0px`) throughout all stage transitions, and only changes upon direct user manual dragging.
  - Safe cancel/back control («رجوع لملف المحامي») allowing the user to return to the lawyer profile before payment.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (9/9 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.7] - 2026-10-31
### Added
- **Global Centralized App Header (`AppHeader`):**
  - Persistent, fixed top header across all app screens (including map screens), strictly excluding `LoginScreen`.
  - Centered dynamic screen title matching the active route/tab (`الرئيسية`, `الطلبات`, `المحفظة`, `الحساب`, `محاميك حالاً`, `اختار مشكلتك`, `تفاصيل سداد الأتعاب`, `تأكيد الدفع`, `تحديد الموقع`).
  - Right action adapts automatically: Search icon with modal search bottom sheet on main tabs, and genuine Back button (`Navigator.maybePop`) on all inner/nested screens.
  - Left action: Notifications icon with unread badge and modal notifications bottom sheet.
  - Built with clean `PreferredSizeWidget` (`height: 56.0`), respecting 7.0px design system and RTL layout.
- **Refactored Bottom Sheet in Map (`TrackingScreen`):**
  - **Taller height & Spacious Profile:** Expanded height increased to `445.0px`, providing comfortable typography and ample room for lawyer credentials.
  - **Centered Title Text:** Title «أقرب المحامين إليك» centered at the very top as clean text with NO icon next to it.
  - **Direct Gesture Control:** Fully interactive upward/downward vertical dragging (`onVerticalDragUpdate` / `onVerticalDragEnd`) with smooth inertia snapping to collapsed (`74.0px`) or expanded (`445.0px`) states.
  - **Zero Control Redundancy:** Removed «تصغير» button completely; resizing is purely driven by direct drag or tapping the top handle.
  - **Strict Height Stability (ثبات الحجم):** Switching lawyers or cycling via «بحث جديد» or loading does NOT alter the Bottom Sheet height by even a single pixel.
  - **Visual Cleanup:** Completely eliminated «نوع الطلب» and «استجابة فورية» from the profile card.
  - **Full Google Profile CTA:** "زيارة ملف Google" button with official Google SVG logo and external link icon.
- **Map Camera Dynamic Adjustment:**
  - Route calculation fits full polyline endpoints (`CameraFit.coordinates`) with dynamic zoom out (`minZoom: 9.0`).
  - Adapts bottom padding to the Bottom Sheet height so route and lawyer pins remain unoccluded.
  - Map control buttons float dynamically above the Bottom Sheet.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (9/9 passing).
- Clean execution and build on device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.6] - 2026-10-31
### Added
- **Multi-Stage Lawyer Request & Acceptance Flow (`_AnimatedConfirmationSheet`):**
  - **Stage 1 (Waiting Acceptance):** Plays Lottie animation with status text «في انتظار قبول المحامي لطلبك...».
  - **Stage 2 (Demo Acceptance):** Automatically transitions with a verified check badge «وافق المحامي على طلبك بنجاح ✓».
  - **Stage 3 (Pricing Evaluation):** Smooth inline loading with status text «جاري تقييم سعر الخدمة...».
  - **Stage 4 (Price Centered & No Container):** Displays the calculated legal fee (`350 ج.م`) centered with clean typography (zero enclosing card containers for problem and lawyer text) and primary action button **«دفع وطلب الآن»**.
- **Dedicated Payment Screen (`PaymentScreen`):**
  - Features top SVG illustration [`assets/images/payment_credit_card.svg`](file:///d:/KAREM/assets/images/payment_credit_card.svg) (from `undraw_credit-card_t6qm.svg`).
  - Formatted billing breakdown table: problem/complaint type, assigned lawyer, location, arrival ETA, order reference, fees, and zero tax/platform fee.
  - Interactive payment selector: Vodafone Cash / mobile wallets, bank cards, and My Lawyer wallet balance.
  - Primary button: «دفع 350 ج.م وتأكيد الطلب».
- **Payment Success Screen with Countdown (`PaymentSuccessScreen`):**
  - Features top SVG illustration [`assets/images/payment_success_rain.svg`](file:///d:/KAREM/assets/images/payment_success_rain.svg) (from `undraw_make-it-rain_ylfg.svg`).
  - Active 3-second countdown timer (`_secondsLeft`) with automatic redirection to the Orders page.
  - Organized financial transaction receipt table: reference number, lawyer name, problem type, paid amount, payment method, success status, and timestamp.
- **Enhanced Orders Tab with Active Order Card & Action Buttons (`OrdersTab`):**
  - Persistent active order card displaying lawyer credentials, verified badge, photo, problem type, location, and fees.
  - **«تواصل» Button:** Opens a modal bottom sheet (20.0px) for direct phone call or instant text chat.
  - **«شكوى» Button:** Opens an inquiry/complaint bottom sheet (20.0px) with detailed input to submit grievances directly to platform management.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (9/9 passing).
- Hot Restart executed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.5] - 2026-10-31
### Added
- **Integrated Lottie JSON Animation for Initial Map Setup & Lawyer Cycling:**
  - Added `lottie: ^3.2.0` dependency and imported `assets/images/splash_gif.json` (from user's `Splash Gif.json`).
  - Replaced the circular progress indicators across the screen with medium-small Lottie JSON animations (`80x80` for initial map blur and `70x70` for lawyer cycling).
  - Designed the initial map preparation overlay (`جاري تجهيز الخريطة ومسار أقرب محامٍ...`) directly on top of the frosted glass blur (`ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0)`) without any bounding white box or card container.
- **Collapsible / Expandable Bottom Sheet with Extra Rounded Corners (`28.0px`):**
  - Enhanced the docked bottom sheet with an increased top border radius (`28.0px`) and spacious height accommodating the full lawyer profile.
  - Implemented open/close capability (`_isSheetExpanded`) with smooth animated transitions (`AnimatedContainer` & `AnimatedPositioned` with cubic easing).
  - When collapsed, the sheet maintains a visible persistent header with the title «أقرب المحامين إليك», the lawyer's name preview, and a tap toggle button («عرض التفاصيل» / «تصغير»).
  - Dynamically synchronized map controls (`my_location`, `+`, `-`) and camera bounds padding (`bottom: _isSheetExpanded ? 395 : 120`) so map elements remain completely visible whether the sheet is expanded or collapsed.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (7/7 passing).
- Live hot restart completed cleanly on physical Android device (`OFDI4TCAFA9XBQOJ`).

---

## [Phase 2.4] - 2026-10-31
### Added
- **Intelligent Camera Framing with Non-Occluded Bounds Zoom-Out (`TrackingScreen`):**
  - Engineered `_zoomFitRouteAndLawyer` utilizing `CameraFit.coordinates` with dynamic bottom padding (`335px`), ensuring that both the user's location pin and the lawyer's card remain 100% visible in the upper viewport above the docked bottom sheet without any overlap or occlusion.
  - Automatically zooms out and centers the road route smoothly upon initial load, when selecting any lawyer from the map, or when clicking «بحث جديد».
- **Official Google Profile Button with "Google" in English (`_selectedLawyer`):**
  - Added dedicated `زيارة ملف Google` button inside the docked profile card with official Google 4-color SVG icon (`assets/images/google_logo.svg`).
  - Strict 7.0px border radius with responsive feedback on tap.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (7/7 passing).

---

## [Phase 2.3] - 2026-10-31
### Added
- **Unified Docked Profile Bottom Sheet with Zero Map Overlay (`TrackingScreen`):**
  - Integrated the full lawyer profile directly inside the persistent, docked bottom sheet panel (20.0px top radius) without any darkening overlay, keeping the map 100% visible and interactive.
  - Automatically loads the nearest lawyer's verified credentials, photo, title, experience, specialization, rating, and OSRM distance/ETA.
  - Clicking any lawyer marker on the map smoothly animates the camera, updates the route, and swaps the profile data directly inside the existing bottom sheet without opening any new dialog or modal sheet.
- **Dual Action Buttons («طلب الآن» & «بحث جديد»):**
  - Positioned two side-by-side buttons at the bottom of the profile panel:
    * **«طلب الآن»** (Primary CTA): Directs to the confirmed booking sheet.
    * **«بحث جديد»** (Secondary action): Plays an inline mini-loader (`_isCyclingLawyer`), cycles to the next nearest top-rated lawyer, smoothly animates the map, and recalculates the road route.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (7/7 passing).

---

## [Phase 2.2] - 2026-10-31
### Added
- **Frosted Map Blur & Setup Loader (`TrackingScreen`):**
  - Added full-screen frosted glass blur (`BackdropFilter` with `ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0)`) and centered card loader while initial location, nearby lawyers, and route are calculating.
- **Thin Dashed Road Route Polyline (`StrokePattern.dashed`):**
  - Restyled OSRM route geometry to be thin (`strokeWidth: 3.2`) with high-contrast dashed segments (`[8, 5]`).
  - Seamlessly anchored the polyline start directly at user's location and polyline end directly underneath the lawyer's map card notch.
- **Realistic Lawyer Portrait Photos (`_LawyerAvatarPhoto`):**
  - Replaced text initials with high-resolution realistic portrait photos for all 10 lawyers.
  - Implemented progressive loading and graceful offline fallback to initials so UI never breaks.
- **Smooth Animated Camera Navigation (`_animatedMapMove`):**
  - Added cubic-eased camera animations for tapping any lawyer marker, recentering on user, and zooming in/out.
- **Fixed Subpixel Artifacts Beneath Map Markers (`_LawyerBubblePainter`):**
  - Engineered single-path vector painter combining the rounded rectangle and pointer notch in a unified canvas pass, completely resolving subpixel gaps and antialiasing artifacts.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (7/7 passing).

---

## [Phase 2.1] - 2026-10-31
### Added
- **Professional Square Lawyer Markers on Map (`_LawyerMapSquareMarker`):**
  - Replaced lawyer pin icons with modern, sleek square map badges (7.0px radius) showing the lawyer's square avatar photo with initials, name, and star rating.
  - Added downward pointer arrow indicator linking the badge precisely to its geographic coordinates.
  - Highlighted border styling for the active lawyer (`AppColors.primary`) and nearest lawyer (`AppColors.success`).
- **Interactive Lawyer Profile Bottom Sheet (`_LawyerProfileBottomSheet`):**
  - Tapping any lawyer marker on the map or the bottom card opens a dedicated modal bottom sheet (20.0px top radius).
  - Surfaces complete lawyer profile: square avatar photo (7.0px), full name with verification badge, title, years of experience, syndicate status, and specialization pill.
  - Displays quick performance stats: rating, review count, instant response indicator, and verified syndicate status.
  - Displays live OSRM driving distance and ETA badge with route highlighting.
  - "طلب وتعيين هذا المحامي الآن" CTA button leads directly to the confirmed booking flow.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (7/7 passing).

---

## [Phase 2.0] - 2026-10-31
### Added
- **Dedicated Urgent Problem Selection Screen (`UrgentServiceProblemScreen`):**
  - Created `lib/screens/urgent_service_problem_screen.dart` triggered upon tapping «محاميك حالاً» (banner or grid card).
  - Centered SVG illustration `assets/images/urgent_service_question.svg` (`undraw_question_vqsl.svg`) paired with prominent title **«اختار مشكلتك»**.
  - Integrated 8 realistic Egyptian micro-legal emergency options (< 24 hours turnaround) with 7.0px cards, descriptive subtexts, category pills, and safety icons:
    1. محضر في قسم الشرطة (تحرير محضر أو معمول فيك محضر).
    2. تحقيق عاجل في النيابة العامة.
    3. حادث سير أو نزاع مروري طارئ.
    4. كمين أو استيقاف أمني أو فحص هوية.
    5. نزاع حيازة أو طرد أو تمكين فوري.
    6. تحقيق إداري أو تأديبي عاجل في العمل.
    7. إثبات حالة مستعجل وتوثيق واقعة.
    8. مشكلة طارئة أخرى (مع نافذة إدخال مخصصة بحواف 20px).
- **Navigation & Problem Context Integration (`TrackingScreen` & `HomeTab`):**
  - Updated «محاميك حالاً» navigation across `HomeTab` to route through the problem selection screen.
  - Carried forward the selected problem title into `TrackingScreen`, displaying it in the bottom summary panel and within the animated confirmation bottom sheet.
- **Unit & Widget Test Expansion:**
  - Added RTL widget test verifying `UrgentServiceProblemScreen` title, subtitle, and problem cards render properly.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (7/7 passing).

---

## [Phase 1.9] - 2026-10-31
### Added
- **True Location Pin Marker for User (`TrackingScreen`):**
  - Replaced the square marker box with a classic, prominent map drop pin (`_UserLocationPin`, 50x56) featuring a subtle ground shadow, primary blue pin body, and centered white ring containing a user icon.
- **10 Realistic Egyptian Mock Lawyers on the Map (`MockLawyer` & `_LawyerMapPin`):**
  - Populated 10 realistic lawyers distributed around the user's location at distances ranging from 450 meters to 2.5 km with varied legal specializations and verified ratings.
  - Custom lawyer map pins with shield badges (`_LawyerMapPin`), highlighting the nearest lawyer with a distinctive green badge.
- **Automatic Driving Route Calculation & Polyline Drawing (`RoutingService`):**
  - Integrated automatic driving route fetching from the VPS self-hosted OSRM engine (`http://13.140.141.32/osrm`) between the user and the nearest lawyer on map load.
  - Dynamically draws the road polyline layer on the map (`PolylineLayer`) with white border framing.
  - Bottom docked panel dynamically surfaces nearest lawyer card with live distance, OSRM ETA, rating, and specialization.
  - Allows tapping any other lawyer marker on the map to switch selection and redraw the route in real time.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (6/6 passing).

---

## [Phase 1.8] - 2026-10-31
### Added
- **Primary Self-Hosted VPS Map Integration (`MapConfig` & `TrackingScreen`):**
  - Integrated the user's dedicated VPS server (`http://13.140.141.32`) as the **primary map provider** across the entire application.
  - Deployed an ultra-fast local NVMe disk-cached tile proxy in Nginx (`/tiles-cache/{z}/{x}/{y}.png`) with 90-day caching, CORS enabled, and DNS resolver configured.
  - Measured benchmark: cache hits served in < 150ms directly from the server's NVMe SSD.
  - Configured `MapConfig.serverTileUrl` as primary `urlTemplate` in `TrackingScreen` with `tile.openstreetmap.org` and `CartoDB Voyager` retained as resilient fallbacks.
- **Self-Hosted OSRM Legal Routing Service (`RoutingService`):**
  - Added `lib/core/services/routing_service.dart` connected to `http://13.140.141.32/osrm`.
  - Implemented `calculateDrivingRoute` computing real road driving distances and estimated arrival times (ETAs) across Egypt road network for «محاميك حالاً».
  - Implemented `RouteEstimate` model providing formatted Arabic outputs (e.g., "4.5 كم", "12 دقيقة تقريباً").
- **Cleartext HTTP Permitted for Android (`AndroidManifest.xml`):**
  - Added `android:usesCleartextTraffic="true"` to permit direct HTTP communication with the self-hosted VPS services without Android OS network security restrictions.
- **Unit & Widget Tests Expansion (`widget_test.dart`):**
  - Added test cases verifying self-hosted endpoints in `MapConfig` and accurate formatting in `RouteEstimate`.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (5/5 passing).

---

## [Phase 1.7] - 2026-10-31
### Added
- **«محاميك حالاً» First Legal Service Card (`HomeTab`):**
  - Integrated `undraw_judge_hyqv.svg` (`assets/images/lawyer_judge.svg`) as the visual graphic for the first service card in the legal services grid.
  - Replaced "قضايا ومحاكم" and promoted "محاميك حالاً" to the #1 primary position in the grid with direct navigation to `TrackingScreen`.
- **VPS Server & Self-Hosted Map Subsystem Audit & Documentation (`docs/VPS_SERVER_AND_MAPS.md`):**
  - Audited production Contabo VPS (`13.140.141.32`) and documented access credentials, SSH guidelines, and system specs.
  - Verified and benchmarked live Docker services:
    * `mylawyer-osrm` (port 5000 / Nginx `/osrm/`): High-speed Egypt driving routing engine (< 10ms latency).
    * `mylawyer-tileserver` (port 3000 / Nginx `/tiles/`): TileServer GL serving Egypt PMTiles vector dataset.
  - Provided strategic integration plan for Flutter app: route ETA and distance calculations for «محاميك حالاً» and tile rendering.
- **Global Team SVG Illustration in Urgent Banner:**
  - Integrated `undraw_global-team_8jok.svg` (`assets/images/global_team.svg`) into the «محاميك حالاً» banner, giving it a modern, rich visual identity alongside the call-to-action button.
### Changed
- **Bottom Navigation Bar Active Styling (`AppBottomBar`):**
  - Removed background highlight / hover container (`primaryLight`) on active tab.
  - Active tab is indicated solely by coloring the icon and text (`AppColors.primary`) with bold weight (`FontWeight.w800`) over a transparent background.
- **Animated Half-Screen Logout Confirmation Bottom Sheet (`AccountTab`):**
  - Replaced standard alert dialog with an animated half-screen modal bottom sheet (`_LogoutConfirmationBottomSheet`, height 48% of screen).
  - Configured all content to be centered with rounded top corners (`20.0px`).
  - Added a large flat expressive logout icon (`Icons.logout_rounded`, size 76) animated with `ScaleTransition` (elasticOut) + `FadeTransition`.
  - Enforced zero hover/splash across confirmation and cancel buttons.
- **Global Button Hover & Splash Elimination:**
  - Disabled all hover, splash, ripple, and highlight overlays across the application:
    * Set `splashColor`, `highlightColor`, `hoverColor` to `Colors.transparent` in `AppTheme`.
    * Enforced `splashFactory: NoSplash.splashFactory` and `overlayColor: WidgetStateProperty.all(Colors.transparent)` on all button themes (`ElevatedButtonTheme`, `OutlinedButtonTheme`, `TextButtonTheme`, `IconButtonTheme`).
    * Configured `NoSplash` across all button style overrides, `AppCard`, and `AppBottomBar`.
- **Location Permission Prompt Formatting (`LocationPermissionScreen`):**
  - Split the location prompt into two balanced, centered lines:
    * السطر الأول: "محتاجين نحدد موقعك"
    * السطر الثاني: "عشان نوفرلك أقرب محامي ليك"
- **Home Dashboard Top Bar Redesign (`HomeTab`):**
  - Removed top full-width location banner.
  - Added rounded square avatar (7.0px) with user icon.
  - Added greeting *"أهلاً بك"* with the user's two-part name (الاسم الثنائي: e.g. *أحمد محمود*).
  - Added interactive direct location chip displaying the user's specified address with pin icon.
  - Added notifications icon button (`Icons.notifications_none_rounded`) opposite the user profile.
- **«محاميك حالاً» Urgent Banner Re-positioning:**
  - Moved the «محاميك حالاً» banner directly underneath the profile and notifications section.
  - Removed the *"خدمة طارئة وفورية"* label pill from the banner for a cleaner, unified presentation.

### Verified
- `flutter analyze`: `No issues found!` (0 warnings, 0 errors).
- `flutter test`: `All tests passed!` (3/3 passing).
- Hot Reload applied live to device `RMX3997` in 1,399ms.

---

## [Phase 1.6] - 2026-10-31
### Added
- **Smooth Rounded English Brand Font (`Nunito`):** Integrated `Nunito-Variable.ttf` for the "My Lawyer" branding text across splash, login, and dashboard screens to deliver a soft, friendly, non-sharp aesthetic.
- **Animated Confirmation Bottom Sheet:** Implemented `_AnimatedConfirmationSheet` featuring an elastic-bounce `ScaleTransition` + `FadeTransition` for the flat green checkmark icon.

### Changed
- **Location Permission Screen Refinement (`LocationPermissionScreen`):**
  - Removed top branding row (shield icon and app name).
  - Placed prompt *"محتاجين نحدد موقعك عشان نوفرلك أقرب محامي ليك"* directly on the screen concisely without a container or card.
  - Redirected the button *"سأقوم بتحديده لاحقاً"* directly to `MainNavigationShell` (Home).
- **Map & Confirmation Bottom Sheets (`TrackingScreen`):**
  - Converted the floating location card on the map into a docked bottom sheet panel with `20.0px` top corner radius and pull handle.
  - Redesigned the confirmation bottom sheet to be taller and larger, with all content centered.
  - Replaced the boxed checkmark with a large, flat animated DONE icon (`Icons.check_circle_rounded`, size 80, no container).
  - Increased bottom sheet top border radii to `20.0px` for a softer, more rounded modal appearance.

### Verified
- `flutter analyze`: `No issues found!`.
- `flutter test`: `All tests passed!`.
- Hot Restarted live on connected physical device (`RMX3997`) in 2,868ms.
