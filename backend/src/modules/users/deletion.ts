import { promises as fs } from 'fs';
import path from 'path';
import { config } from '../../config/index.js';
import { Db, dbPool, withTransaction } from '../../database/index.js';
import { spendableBalance } from '../wallet/routes.js';

/// The account stays 30 days after the request, then its personal data goes (owner decision 2026-11-10).
/// Signing in during those days cancels the request.
export const DELETION_GRACE_DAYS = 30;

/// Why the account can't be deleted now, or null. Anything still running or any money still owed either way stops it
export async function deletionBlocker(db: Db, user: { id: string; role: string }): Promise<string | null> {
  const open = await db.query(
    `SELECT
       EXISTS (SELECT 1 FROM service_requests WHERE client_id = $1 AND status = 'OPEN') AS request,
       EXISTS (SELECT 1 FROM service_orders WHERE (client_id = $1 OR lawyer_id = $1) AND status IN ('PENDING', 'ACCEPTED', 'ACTIVE')) AS orders,
       EXISTS (SELECT 1 FROM consultations WHERE client_id = $1 AND status IN ('PAID', 'CONTACTING')) AS consultation,
       EXISTS (SELECT 1 FROM support_tickets WHERE user_id = $1 AND status <> 'CLOSED') AS ticket,
       EXISTS (SELECT 1 FROM service_orders WHERE lawyer_id = $1 AND payout_status IN ('HELD', 'FROZEN')) AS held`,
    [user.id]
  );
  const row = open.rows[0];
  if (row.request || row.orders) return 'عندك طلب لسه مفتوح. خلّصه أو ألغيه الأول';
  if (row.consultation) return 'عندك استشارة لسه شغالة. استنى لما تخلص';
  if (row.ticket) return 'عندك تذكرة دعم مفتوحة. استنى لما تتقفل';
  if (row.held) return 'عندك أتعاب لسه محجوزة. استنى لما تبقى متاحة وحوّلها';

  const balance = await spendableBalance(db, user.id, user.role);
  if (balance > 0) return `عندك رصيد ${balance} ج.م. حوّله الأول من المحفظة`;
  if (balance < 0) return `عليك مديونية ${-balance} ج.م. لازم تتسدد الأول`;
  return null;
}

/// Marks the request and signs the account out everywhere. Nothing is wiped yet
export async function requestDeletion(db: Db, userId: string): Promise<Date> {
  await db.query('UPDATE users SET deletion_requested_at = NOW(), updated_at = NOW() WHERE id = $1', [userId]);
  await db.query('UPDATE user_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL', [userId]);
  await db.query('DELETE FROM device_tokens WHERE user_id = $1', [userId]);
  await db.query('UPDATE lawyer_profiles SET is_available = FALSE WHERE user_id = $1', [userId]);
  return new Date(Date.now() + DELETION_GRACE_DAYS * 86_400_000);
}

async function removeFiles(dir: string, names: string[]) {
  for (const name of names) {
    await fs.rm(path.join(dir, path.basename(name)), { force: true }).catch(() => undefined);
  }
}

/// Wipes one account whose 30 days are over. Orders, payments, transfers and reviews stay for the books,
/// under a nameless account that can never sign in again. Returns false when something new stops it
export async function wipeAccount(userId: string): Promise<boolean> {
  const user = (await dbPool.query('SELECT id, role FROM users WHERE id = $1 AND deleted_at IS NULL', [userId])).rows[0];
  if (!user) return false;
  // Money that came in after the request (an admin decision, say) waits for the team instead of disappearing
  if (await deletionBlocker(dbPool, user)) return false;

  const files = await withTransaction(async (db) => {
    const photos = await db.query(
      `SELECT profile_photo_path AS p FROM users WHERE id = $1 AND profile_photo_path IS NOT NULL
       UNION ALL SELECT profile_photo_path FROM lawyer_profiles WHERE user_id = $1 AND profile_photo_path IS NOT NULL`,
      [userId]
    );
    const documents = await db.query(
      `DELETE FROM lawyer_documents WHERE lawyer_profile_id IN (SELECT id FROM lawyer_profiles WHERE user_id = $1) RETURNING storage_path`,
      [userId]
    );
    const pages = await db.query(
      'DELETE FROM consultation_pages WHERE consultation_id IN (SELECT id FROM consultations WHERE client_id = $1) RETURNING file_name',
      [userId]
    );
    const attachments = await db.query(
      `DELETE FROM ticket_attachments WHERE message_id IN (
         SELECT m.id FROM ticket_messages m JOIN support_tickets t ON t.id = m.ticket_id WHERE t.user_id = $1
       ) RETURNING file_name`,
      [userId]
    );

    for (const table of ['user_credentials', 'user_sessions', 'device_tokens', 'email_verifications', 'password_reset_requests', 'admin_login_codes', 'notifications']) {
      await db.query(`DELETE FROM ${table} WHERE user_id = $1`, [userId]);
    }
    // A nameless account: unique placeholders keep the phone and email columns unique, and suspended keeps it out of everything
    await db.query(
      `UPDATE users SET full_name = 'حساب محذوف', profile_photo_path = NULL,
         phone = 'deleted:' || substr(replace(id::text, '-', ''), 1, 22),
         email = 'deleted-' || id::text || '@deleted.invalid',
         status = 'suspended', suspended_until = NULL, deleted_at = NOW(), updated_at = NOW()
       WHERE id = $1`,
      [userId]
    );
    await db.query(
      `UPDATE lawyer_profiles SET full_name = 'محامي محذوف', profile_photo_path = NULL, syndicate_number = NULL, bio = NULL,
         latitude = NULL, longitude = NULL, is_available = FALSE, governorate = NULL, updated_at = NOW()
       WHERE user_id = $1`,
      [userId]
    );
    await db.query('UPDATE consultations SET details = $2 WHERE client_id = $1', [userId, 'اتمسحت مع الحساب']);

    return {
      photos: photos.rows.map((r) => String(r.p)),
      documents: documents.rows.map((r) => String(r.storage_path)),
      pages: pages.rows.map((r) => String(r.file_name)),
      attachments: attachments.rows.map((r) => String(r.file_name)),
    };
  });

  // The files go after the records, so a failed wipe never leaves records pointing at missing files
  await removeFiles(path.join(config.publicStoragePath, 'avatars'), files.photos);
  for (const doc of files.documents) await fs.rm(doc, { force: true }).catch(() => undefined);
  await removeFiles(path.join(config.privateStoragePath, 'consultations'), files.pages);
  await removeFiles(path.join(config.privateStoragePath, 'support'), files.attachments);
  return true;
}

/// Wipes every account whose 30 days are over. Runs with the hourly cleanup
export async function wipeDueAccounts() {
  const due = await dbPool.query(
    `SELECT id FROM users WHERE deletion_requested_at IS NOT NULL AND deleted_at IS NULL
       AND deletion_requested_at < NOW() - make_interval(days => $1)`,
    [DELETION_GRACE_DAYS]
  );
  for (const row of due.rows) {
    try {
      await wipeAccount(row.id);
    } catch (err) {
      console.error('[MyLawyer Backend] Account wipe failed:', row.id, err);
    }
  }
}
