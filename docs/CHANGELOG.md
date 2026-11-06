# 📝 CHANGELOG - My Lawyer

## [Production App Only] - 2026-11-06
- **One app:** the Android build has a single app id, `com.mylawyer.my_lawyer`, named «My Lawyer», with Firebase always on, for clients and lawyers. The phone and the emulator run this build.

## [Releases Without Downtime and Admin Split] - 2026-11-06
- **Releases:** `deploy.sh` builds the new code aside, swaps it in seconds and sends `SIGHUP`. The main process runs new migrations and replaces the workers one by one, each new one listening before an old one stops. A change to `server.js` itself still restarts fully. The new release must answer `UP` with its id in `/api/v1/health`, or the previous code comes back by itself. The time-based steps run in the workers behind a database lock, so they never stop during a release.
- **Admin routes:** `modules/admin/directory.ts` is split into `directory.ts` (counts, search, reviews), `accounts.ts` and `orders.ts`. Same 15 routes.
- **Owner rule:** a release may drop the server for seconds during development, never once real users are on it.

## [Restructuring Steps 2 and 3] - 2026-11-06
- **One definition of an open order:** `IS_OPEN_ORDER` and `HAS_OPEN_ORDER` in `lifecycle/service.ts` replace five copies, and the nearby lawyers search uses `LAWYER_CAN_WORK` like the request rounds. Behavior is the same.
- **Auth split:** `modules/auth/routes.ts` (600 lines) is now `register.ts` (sign up and activation), `session.ts` (sign in, renew, sign out), `password.ts` (reset) and `codes.ts` (code limits). Same routes and answers.

## [Cleanup Stage 1 and Shared Project Memory] - 2026-11-06
- **Shared memory for every model:** `docs/STATE.md` (read first, the current state), `docs/SESSIONS.md` (one line per session from any model, newest first) and `docs/README.md` (which doc answers which question). `AGENTS.md` section 7 now has the start routine (read only what the task needs, compare Git with `STATE.md`) and a required handoff. `.windsurfrules` and `.github/copilot-instructions.md` point to `AGENTS.md` like `CLAUDE.md`, `GEMINI.md` and `.cursorrules`.
- **Profile requests:** the account tabs, the personal data page and the home profile card read `/users/me` through `ProfileRepository`, so screens opened together share one request, with no stale copy kept.
- **Removed, unused:** the `lottie` package, `assets/images/splash_gif.json`, and the Thin, ExtraLight and Light IBM Plex Sans Arabic fonts (no weight under 400 is used anywhere). The app is about 720 KB smaller, and nothing looks different. Evidence and the restructuring plan are in `docs/engineering/CLEANUP.md`.

## [Code Guess Limit, Lawyer Tickets and Access Folder] - 2026-11-06
- **Verification and reset codes (SEC-02):** each guess now takes its attempt in one database step before the code is compared, so guesses sent together can't pass the limit of 5. A new test sends 12 at once: the old code let all 12 through, now only 5.
- **Lawyer tickets (SEC-04, owner decision):** a lawyer can't open a ticket on a paid order before registering arrival, so a lawyer who never came can't hold the client's refund. The client still can.
- **Access folder:** `.access/` inside the project (ignored by Git, the repo is public) holds the GitHub token, the VPS key and the panel and test logins, so any tool or model works without asking the owner. A push or deploy still happens only when the owner says «ارفع». Details in `docs/ACCESS.md` and `AGENTS.md` section 7.
- **Deferred by the owner:** the direct payment fix (SEC-01) until the payment gateway, and daily backups to Google Drive (OPS-01). A postponed task keeps the lawyer available.

## [Engineering Review and Approval Rule] - 2026-11-06
- **Review:** full review of the app, server, control page, database and VPS, built from the current code. New `docs/engineering/` holds the system map, the reference of all 97 server routes, the findings register (`FINDINGS.md`, numbered issues with severity and evidence), the checks report and the performance baseline and plan. No code changed.
- **Most serious finding:** SEC-01, a «direct» payment marks an order paid without collecting money, and cancelling it in the first 5 minutes adds real balance that can be transferred. It must close before launch, and the owner decides how.
- **New owner rule:** no `git push`, pull request, server change, restart, migration or deploy without the owner's explicit approval each time. This replaces the 2026-11-05 open-access rule in `AGENTS.md` section 7. Access details without secrets in `docs/ACCESS.md`, and the VPS opens with `ssh mylawyer-vps`.
- **Checks:** `flutter analyze` clean, `flutter test` 128 passed and 3 skipped, backend `tsc` clean, `npm test` 141 passed, `npm audit` 0. Production database statistics were not read because the safety tool refused the query.

## [New Logo] - 2026-11-06
- **Logo:** the owner's new bold blue «My Lawyer» logo, cleaned of stray dots, replaces the old one on the login screen, the Android and iPhone app icons, the control panel (login, side menu and browser tab) and the website header and tab icon. The splash video still shows the old logo until a new video is made.

## [Payment Method Page and Payments History] - 2026-11-06
- **Paying:** the invoice page only reviews the bill, and «اختار طريقة الدفع» opens a page of its own with the line drawing and title like the sign-up pages. The balance option is off when the balance is not enough.
- **Payments page:** «المدفوعات والفواتير» in the client account lists every payment with its state: paid, refunded, partly refunded or failed with the reason. Paid ones download a PDF invoice in Arabic through the phone's save and share screen.
- **Server:** `GET /wallet/payments`, and a failed payment (balance not enough or payment time over) is kept in `failed_payments`, migration `029`.
- **Libraries:** `pdf` and `printing`, approved by the owner for the invoice.

## [Transfers Without Held Fees] - 2026-11-06
- **Wallet transfers:** anyone sends to anyone, lawyer to lawyer included, and refunds can be sent. Only a lawyer's held or frozen fees cannot move until they are released, and the refusal says so.
- **Unactivated accounts:** by the owner's decision, an account keeps its phone and email reserved once created, and the phone is not checked by a code.

## [No Lawyer Degree] - 2026-11-06
- **Lawyer card:** the line under the lawyer's name (degree such as «محامي استئناف») is gone from the map sheet and the nearby lawyers sheet, by the owner's choice: no titles or specialties. The «الأقرب إليك» badge stays under the name.
- **Server:** `/lawyers/nearby` and `/lawyers/me` no longer send `degree`. The old database column stays untouched.

## [Nearby Lawyers Sheet] - 2026-11-06
- **Map sheet:** before a request it shows how many lawyers are near and the nearest distance, with one «اطلب عروض أسعار» button that sends to the nearest 5. A lawyer's profile shows only after tapping their card, with a back button and no order button. «بحث جديد» is gone.

## [Live Like Big Apps] - 2026-11-06
- **Changes with numbers:** every change on the live line names what changed (the order, request or ticket) and has a number. After a dropped line, the app asks `GET /events/since` for only what it missed, or reloads everything once if too much was missed. Migration `028`.
- **One orders store in the app:** every screen reads orders from `OrderStore`. A change to one order fetches that order alone with `GET /orders?id=` and every screen showing it updates together. The 30-second checks are gone, so screens no longer ask the server on a timer.
- **New request countdowns:** they count down on the phone, and a request whose time ran out without a price leaves the page by itself.
- **Control page:** a support change reloads only support pages, and other changes skip them.

## [Live Control Page and Dialogs] - 2026-11-06
- **Control page:** it keeps the same live line as the app, and every change reloads the open page and the counts quietly, with no button or notice. A change waits while a window is open or a field is being typed in. The one-minute count refresh is gone.
- **App:** the «data may be old» bar is removed, and the app reconnects and reloads quietly.
- **Dialogs:** one style for every floating window, a small line drawing in the middle, the title and text on the right, and two filled buttons side by side.
- **Accounts list:** shows the real suspension state, and a lawyer's countdown card refreshes as soon as the admin changes something.

## [Suspension Countdown] - 2026-11-06
- **Strikes:** a lawyer is told from the first strike how many count toward a suspension. The admin can cancel a strike: it stays recorded as cancelled, stops counting, and ends a strike suspension once fewer than three remain. Activating an account now ends a strike suspension too. Migration `027`.
- **Account status in the panel:** shows whether the account is suspended by the admin, by warnings or by strikes and until when, with active warnings and strikes out of 3.
- **Panel lists:** open on all dates, and tables show 30 rows a page with previous and next.
- **Suspension countdown:** a timed suspension shows a countdown on the suspended screen, and a lawyer stopped by strikes sees one on the availability card. Account suspended, activated and suspension ended now reach the phone.
- **Drawings:** the suspended screen and the sign out sheet use the app's line drawing.
- **Maps:** the full screen loading layer and its animation are gone, and loading shows inside the sheet.

## [Calmer Notifications] - 2026-11-06
- **Fewer alerts:** only steps that need action ring the phone. Settlements, payouts ready, new reviews, transfers sent and similar steps stay inside the app. The lawyer no longer gets «الطلب اتقفل» or «الموكل ما دفعش», and the 12 and 4 hour reminders are gone.
- **One line per order:** each order or request keeps a single notification that every new step replaces, offers show as «وصلك 3 عروض», and notifications older than 30 days are removed. Migration `026`.
- **Opening notifications:** an order opens at once from the saved copy, a new request opens its offer sheet for the lawyer, and notifications with no page show no arrow. Opening an order marks its notification read.
- **Problem button:** «عندك مشكلة؟» shows from arrival until 24 hours after finishing.
- **New request card and sheet:** time left, area, the price box, a short step bar, and grouped details with icons.
- **Motion:** pages slide in from the side and the page below moves a little, sheet content slides up and resizes smoothly, with no fading.

## [Saved Data] - 2026-11-06
- **Faster screens:** orders, wallet and notifications show the last saved copy at once, then the server's copy replaces it. Phone numbers, emails and exact places are not saved, and everything saved is cleared at sign out.
- **Server says what changed:** the live line now names the change (orders, requests, support or notifications), so only the screens that need it reload.
- **Images:** lawyer and account photos are saved on the phone with `cached_network_image`, approved by the owner.
- **Connection notice:** after 20 seconds without the live line, a small bar says the data may be old.

## [Orders Count] - 2026-11-06
- **Orders page:** «الطلبات الحالية» shows how many are running or waiting, and the details buttons on cards are now filled blue.

## [One Sheet Style] - 2026-11-06
- **Bottom sheets:** every sheet now uses `AppSheet` in `core/widgets/app_sheet.dart`, with a handle, the title and a dashed line. Its height follows its content on any phone, and only content taller than the screen moves inside. The map sheets follow the same style, and the map buttons move with their height.

## [Production Hardening] - 2026-11-05
- **Server:** three request workers, SSH by key only, tuned PostgreSQL and Nginx, seven indexes, and a daily local backup. Results are in `docs/PRODUCTION_REPORT.md`.

## [Orders Filter] - 2026-11-05
- **Orders page:** two buttons on top, «الطلبات الحالية» and «سجل الطلبات», for the client and the lawyer.
- **Request sheet:** before pricing, the lawyer sees the service, problem, details and address (area and governorate). The exact point stays hidden until payment.

## [One Orders Page] - 2026-11-05
- **Lawyer:** requests and order history are one page again, with new and running cards on top and a status list on each request. The bottom bar is back to 4 tabs.
- **Details:** order details are now a bottom sheet for both sides. In the lawyer's request sheet, «ابعت عرضك» switches to the price form, and sending closes the sheet.

## [Sound and Status] - 2026-11-05
- **Open app:** a change that used to notify now plays a sound and vibrates, with no device notification. With the app in the background, the device notification stays.
- **Lawyer offer page:** a status list follows the sent price.

## [Live Updates] - 2026-11-05
- **Open line:** the app keeps one line open to `GET /events`. When something changes for that person, PostgreSQL announces it after the save, and the open pages reload at once. Pages also check every 20 to 30 seconds in case the line drops, and the line reconnects by itself.
- **Lawyer offer page:** it moves to the order when the client chooses the offer, and goes back when the request closes.
- **Later:** with more than one server process, this already works across them, since each listens to PostgreSQL.

## [Fixed Service Sheet] - 2026-11-05
- **Map sheet:** the «محاميك حالاً» sheet now has one fixed height, can't be dragged or closed, and scrolls its content inside.
- **Choosing an offer:** the client now has 5 minutes after the offers round instead of 10. The sheet shows the time left, and the request is cancelled when it ends, with a notice to the client and the lawyers who offered.

## [Lawyer Requests Tab] - 2026-11-05
- **Tabs:** lawyers now have five tabs. «الاستقبال» holds new requests and offer results, and «السجل» holds orders.
- **Live cards:** the receive tab holds current requests only. A card shows when the price is awaited, sent or chosen, stays until payment, and refreshes every 5 seconds. Order cards show the current step for the lawyer.
- **Device notifications:** one order, ticket or request keeps one notification on Android, and the newest replaces the older.

## [Live Lawyer Location] - 2026-11-05
- **Android:** while a lawyer is available, the app sends the location about every minute or 100 meters, in the foreground or background, with a fixed notification. This replaces the 15-minute background check.
- **Getting ready:** pressing «متاح» shows steps for location, notifications and battery. Location and notifications are required, and battery exemption is a warning.
- **Server:** 10 silent minutes turn an available lawyer unavailable, except while a task is open.
- **Requests:** a request needs the client's real location, and the Cairo fallback no longer applies to it.

## [Price Offers] - 2026-11-05
- **Requests (approved by the owner):** a client request now goes to the nearest 5 available lawyers. Each lawyer can send one price inside the limits set in the control page, and can withdraw it. The client picks an offer, which creates an order at that price, and the commission comes from that price. Payment and everything after it stay the same.
- **Rounds:** with no offers after 2 minutes, the request moves to the next 5, up to 3 rounds. With offers, the client has 10 more minutes to choose. Migration `024` adds the requests and offers.
- **App:** the map is for viewing, «اطلب محامي» shows the price range, and offers appear on the same sheet. Lawyers get new requests at the top of the orders tab.
- **Kept for old app versions:** `POST /orders` and the random price, until those versions are gone.

## [Late Lawyers and Postponed Tasks] - 2026-11-05
- **Money (approved by the owner):** payment now sets an arrival deadline: road time from OSRM, or an estimate if it fails, plus 30 minutes. The lawyer gets a reminder 10 minutes before it ends, then the client is asked whether to wait or cancel. Cancelling refunds at once, no answer refunds after 2 hours, and waiting refunds 24 hours after payment if the lawyer never arrives. An open ticket stops these refunds.
- **After arrival:** money no longer moves by itself. It stays held until the lawyer finishes or the admin decides, so the old automatic payout at 24 hours is gone.
- **Postponing:** after arrival the lawyer can press «مؤجل» with a reason and a new date. A postponed order doesn't block new orders for the lawyer or the client.
- **Wording:** the far-away message now says «لازم تكون قريب من الموكل». Migration `023` adds the new fields, and the control page shows the new dates.

## [Engineering Review] - 2026-11-03
- **Accounts:** a suspended or rejected account can no longer lift its status through the sign-up code. Reset codes allow 5 wrong tries, and only the latest one counts. A new reset code waits 60 seconds. 10 failed sign-ins on one account stop it for 10 minutes. Changing the password ends all sessions. One refresh token renews once.
- **Privacy:** order details no longer send the other side's phone or email before payment, and the client no longer receives the lawyer's net amount.
- **Server:** production refuses to start on a missing or known `JWT_SECRET`, and the old default secrets left the code. The caller's address comes from the local Nginx only. One error handler hides technical wording, and production now writes warnings and errors to the log. A failed migration stops the start. The server finishes open requests before it stops, and sweep rounds no longer overlap.
- **Orders:** two requests at once can no longer book one lawyer or open two orders, and accept and reject can't both succeed.
- **Rules that drifted:** a review is reported once and edited within 7 days. A new lawyer stays unavailable until pressing the button. Videos are no longer accepted as HEIC images. `GET /orders` works for admins.
- **Structure:** `utils/http.ts` holds the shared sign-in check and error type, and `lifecycle/sweep.ts` holds the time-based steps, which ends a circular import. Removed `POST /lawyers/me/profile-photo` (no caller, and it trusted the file type the phone sent) and the `lint` script (its tool isn't installed).
- **Packages:** the API explorer moved to development only, so `/docs` is gone from production and `npm audit --omit=dev` went from 4 moderate warnings to 0.
- **Speed:** migration `022` adds 4 indexes. On 200,000 notifications in the in-memory database, clearing stale ones went from 16.7 ms to 0.9 ms and a sweep round from 13.2 ms to 7.2 ms. The app's periodic refresh now stops in the background, and order and notification lists build only the visible rows.
- **Control page:** the page now carries a Content-Security-Policy. All 12 menu pages opened with no violations.
- **Money (approved by the owner):** paying, cancelling, withdrawing, finishing and arriving now lock the order and check its state inside one transaction, so two presses at once can't charge or refund twice. Wallet payment also takes the same account lock as transfers. The money rules themselves did not change.

## [Map: Lawyers in the Visible Area] - 2026-11-04
- The map now loads the lawyers inside its visible area as the user moves it, and every lawyer stays a card with no grouping. The list shows the nearest 50, and the promo list the top rated 50 within 50 km.
- `GET /lawyers/nearby` accepts `north`, `south`, `east`, `west`, `limit` and `sort=rating`, and older apps keep the previous answer. Migration `022` adds the map index.

## [Control Page: Style Fix] - 2026-11-03
- Restored notice and chat message colours that the style cleanup removed by mistake, because the code builds those class names.

## [Control Page: Links and Speed] - 2026-11-03
- Every page, tab, filter and search now has its own link (`js/router.js`), so back, refresh and sharing a link work.
- Pages open from the last answer and refresh behind it, the current page stays on screen while the next loads, menu lists load on hover, and the private card no longer holds a page.
- A manual warning can now carry an order number. Long tables draw 50 rows at a time, and unused control page styles were removed.

## [Review Reports in the App] - 2026-11-03
- A lawyer can now report a comment from «تقييماتي» with a reason, and the report reaches «بلاغات التقييمات» on the control page.

## [Control Page: Style Files] - 2026-11-03
- Moved the latest control page styles into `css/lists.css` and `css/profile.css`, merged rules that overrode each other, and removed unused ones. Page headers now use three compact lines with smaller text, and their buttons sit directly on the header at a normal size.

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
