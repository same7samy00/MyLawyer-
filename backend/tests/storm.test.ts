import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, call, sql, createUser } from './harness.js';
import { lawyerShare } from '../src/modules/lifecycle/service.js';

/// A storm: many clients and lawyers doing random things at the same moment (asking, pricing, choosing, paying,
/// arriving, cancelling, stepping down), while time jumps forward under them. Nobody follows the happy path.
/// Afterwards the rules that must hold whatever happened are checked: no server error, no lawyer booked twice,
/// and every pound accounted for. The dice are seeded, so a failure plays again exactly the same way.

const LAWYERS = 12;
const CLIENTS = 16;
const ROUNDS = 50;
const AT_ONCE = 16;

function dice(seed: number) {
  let state = seed >>> 0;
  return () => (state = (Math.imul(state, 1664525) + 1013904223) >>> 0) / 4294967296;
}

interface Person { id: string; token: string }
let lawyers: Person[] = [];
let clients: Person[] = [];

async function people() {
  if (lawyers.length > 0) return;
  for (let i = 0; i < LAWYERS; i++) {
    const id = await createUser(`0155500${String(i).padStart(4, '0')}`, 'lawyer');
    await sql(
      `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, urgent_status, latitude, longitude)
       VALUES ($1, $2, $3, 'approved'::lawyer_approval_status, TRUE, 'APPROVED', $4, $5)`,
      [id, `أ. عاصفة ${i}`, `ST${i}`, 30.05 + i * 0.003, 31.25 + (i % 4) * 0.004]
    );
    lawyers.push({ id, token: app.jwt.sign({ userId: id, role: 'lawyer' }) });
  }
  for (let i = 0; i < CLIENTS; i++) {
    const id = await createUser(`0166600${String(i).padStart(4, '0')}`, 'client');
    clients.push({ id, token: app.jwt.sign({ userId: id, role: 'client' }) });
  }
}

const one = async (text: string, params: any[]) => (await sql(text, params))[0];

describe('عاصفة: مئات العمليات العشوائية في نفس اللحظة', () => {
  for (const seed of [11, 2026, 77777]) {
    it(`بعد العاصفة: مفيش خطأ خادم، ولا محامي اتحجز مرتين، ولا جنيه ضاع (الزهر ${seed})`, async () => {
      await people();
      const roll = dice(seed);
      const pick = <T>(list: T[]) => list[Math.floor(roll() * list.length)];
      await sql(`UPDATE problem_prices SET min_price = 500, max_price = 1500, commission_percent = 30`);
      await sql(`UPDATE platform_settings SET tax_percent = 14`);
      await sql(
        `UPDATE lawyer_profiles SET is_available = TRUE, suspended_until = NULL, availability_off_reason = NULL, urgent_status = 'APPROVED',
           last_active_at = NOW(), last_location_updated_at = NOW(), wake_count = 0 WHERE user_id = ANY($1)`,
        [lawyers.map((lawyer) => lawyer.id)]
      );

      const answers = new Map<string, number>();
      const serverErrors: string[] = [];
      const send = async (name: string, method: string, url: string, token: string, payload: object = {}) => {
        const res = await call(method, url, token, payload);
        answers.set(`${name} ${res.status}`, (answers.get(`${name} ${res.status}`) ?? 0) + 1);
        if (res.status >= 500) serverErrors.push(`${name} ${method} ${url} -> ${res.status} ${JSON.stringify(res.body)}`);
        return res;
      };

      const clientActs = async (client: Person) => {
        const chance = roll();
        if (chance < 0.3) {
          return send('request', 'POST', '/requests', client.token, {
            problemType: PROBLEM, problemDescription: 'عاصفة', clientLat: 30.05 + roll() * 0.03, clientLon: 31.25 + roll() * 0.012,
          });
        }
        const order = await one(`SELECT id, status FROM service_orders WHERE client_id = $1 ORDER BY created_at DESC LIMIT 1`, [client.id]);
        const request = await one(`SELECT id FROM service_requests WHERE client_id = $1 AND status = 'OPEN' LIMIT 1`, [client.id]);
        if (chance < 0.5 && request) {
          const offers = (await send('follow', 'GET', `/requests/${request.id}`, client.token)).body.data?.offers ?? [];
          if (offers.length > 0) return send('choose', 'POST', `/requests/${request.id}/offers/${pick<any>(offers).id}/select`, client.token);
          return;
        }
        if (chance < 0.55 && request) return send('search-again', 'POST', `/requests/${request.id}/search`, client.token);
        if (chance < 0.58 && request) return send('cancel-request', 'POST', `/requests/${request.id}/cancel`, client.token);
        if (!order) return;
        if (chance < 0.8) return send('pay', 'POST', `/orders/${order.id}/confirm-payment`, client.token, roll() < 0.4 ? { method: 'wallet' } : {});
        if (chance < 0.85) return send('cancel-order', 'POST', `/orders/${order.id}/cancel`, client.token, { reason: 'عاصفة' });
        if (chance < 0.9) return send('confirm-arrival', 'POST', `/orders/${order.id}/confirm-arrival`, client.token);
        if (chance < 0.94) return send('keep-waiting', 'POST', `/orders/${order.id}/keep-waiting`, client.token);
        return send('review', 'POST', `/orders/${order.id}/review`, client.token, { rating: 1 + Math.floor(roll() * 5), comment: 'عاصفة' });
      };

      const lawyerActs = async (lawyer: Person) => {
        const chance = roll();
        if (chance < 0.4) {
          const asked = await one(
            `SELECT r.id, r.min_price, r.max_price FROM request_recipients rr JOIN service_requests r ON r.id = rr.request_id
             WHERE rr.lawyer_id = $1 AND r.status = 'OPEN' ORDER BY random() LIMIT 1`,
            [lawyer.id]
          );
          if (!asked) return;
          if (roll() < 0.1) return send('withdraw-offer', 'POST', `/requests/${asked.id}/offer/withdraw`, lawyer.token);
          const price = Number(asked.min_price) + Math.floor(roll() * (Number(asked.max_price) - Number(asked.min_price) + 1));
          return send('offer', 'POST', `/requests/${asked.id}/offer`, lawyer.token, { price });
        }
        if (chance < 0.5) {
          return send('location', 'POST', '/lawyers/me/location', lawyer.token, { latitude: 30.05 + roll() * 0.03, longitude: 31.25 + roll() * 0.012 });
        }
        const order = await one(
          `SELECT id, client_latitude, client_longitude, arrived_at FROM service_orders WHERE lawyer_id = $1 AND status = 'ACTIVE' ORDER BY random() LIMIT 1`,
          [lawyer.id]
        );
        if (!order) return;
        if (!order.arrived_at) {
          if (chance < 0.75) {
            return send('arrive', 'POST', `/orders/${order.id}/arrive`, lawyer.token, { latitude: Number(order.client_latitude), longitude: Number(order.client_longitude) });
          }
          if (chance < 0.85) return send('ask-arrival', 'POST', `/orders/${order.id}/ask-arrival`, lawyer.token);
          if (chance < 0.93) return send('position', 'POST', `/orders/${order.id}/position`, lawyer.token, { latitude: 30.05 + roll() * 0.03, longitude: 31.25 + roll() * 0.012 });
          return send('step-down', 'POST', `/orders/${order.id}/withdraw`, lawyer.token, { reason: 'عاصفة' });
        }
        if (chance < 0.85) return send('complete', 'POST', `/orders/${order.id}/complete`, lawyer.token);
        return send('postpone', 'POST', `/orders/${order.id}/postpone`, lawyer.token);
      };

      /// Time jumps: calls end, payment and arrival deadlines pass, held fees come due, then the sweep runs
      const timeJumps = async () => {
        if (roll() < 0.5) await sql(`UPDATE service_requests SET round_deadline = NOW() - INTERVAL '1 second' WHERE status = 'OPEN' AND random() < 0.5`);
        if (roll() < 0.2) await sql(`UPDATE service_orders SET payment_deadline = NOW() - INTERVAL '1 second' WHERE status = 'ACCEPTED' AND random() < 0.3`);
        if (roll() < 0.3) await sql(`UPDATE service_orders SET arrival_deadline = NOW() - INTERVAL '1 second' WHERE status = 'ACTIVE' AND arrived_at IS NULL AND random() < 0.3`);
        if (roll() < 0.2) await sql(`UPDATE service_orders SET delay_notified_at = NOW() - INTERVAL '6 minutes' WHERE delay_notified_at IS NOT NULL AND status = 'ACTIVE' AND random() < 0.5`);
        if (roll() < 0.2) await sql(`UPDATE service_orders SET hold_until = NOW() - INTERVAL '1 second' WHERE payout_status = 'HELD' AND random() < 0.5`);
        // The lawyers' phones keep saying «still here», so the storm is about orders and not about silence
        await sql(`UPDATE lawyer_profiles SET last_active_at = NOW(), last_location_updated_at = NOW() WHERE user_id = ANY($1)`, [lawyers.map((l) => l.id)]);
        await sweepLifecycle();
      };

      for (let round = 0; round < ROUNDS; round++) {
        const together: Promise<unknown>[] = [];
        for (let i = 0; i < AT_ONCE; i++) together.push(roll() < 0.5 ? clientActs(pick(clients)) : lawyerActs(pick(lawyers)));
        together.push(timeJumps());
        await Promise.all(together);
      }

      const total = [...answers.values()].reduce((sum, count) => sum + count, 0);
      const worked = [...answers].filter(([name]) => / 20[01]$/.test(name)).reduce((sum, [, count]) => sum + count, 0);
      console.log(`  seed ${seed}: ${total} requests, ${worked} accepted, ${total - worked} refused by the rules`);
      console.log('  ' + [...answers].sort().map(([name, count]) => `${name}×${count}`).join('  '));

      assert.deepEqual(serverErrors, [], 'no server error, whatever the order of events');
      // The storm must really have gone through the whole journey, or the checks below prove nothing
      for (const step of ['request 201', 'offer 201', 'choose 200', 'pay 200', 'arrive 200', 'complete 200']) {
        assert.ok((answers.get(step) ?? 0) > 0, `the storm never reached: ${step}`);
      }
      const everyone = [...clients, ...lawyers].map((person) => person.id);

      const doubleBooked = await sql(
        `SELECT lawyer_id, COUNT(*)::int AS tasks FROM service_orders
         WHERE lawyer_id = ANY($1) AND status IN ('PENDING', 'ACTIVE') AND postponed_at IS NULL GROUP BY lawyer_id HAVING COUNT(*) > 1`,
        [everyone]
      );
      assert.deepEqual(doubleBooked, [], 'a lawyer has one running task at a time');

      const tooManyPostponed = await sql(
        `SELECT lawyer_id FROM service_orders WHERE lawyer_id = ANY($1) AND status = 'ACTIVE' AND postponed_at IS NOT NULL GROUP BY lawyer_id HAVING COUNT(*) > 2`,
        [everyone]
      );
      assert.deepEqual(tooManyPostponed, [], 'a lawyer keeps at most two postponed tasks');

      const twoOpenRequests = await sql(
        `SELECT client_id FROM service_requests WHERE client_id = ANY($1) AND status = 'OPEN' GROUP BY client_id HAVING COUNT(*) > 1`,
        [everyone]
      );
      assert.deepEqual(twoOpenRequests, [], 'a client has one open request at a time');

      const twoOpenOrders = await sql(
        `SELECT client_id FROM service_orders WHERE client_id = ANY($1) AND status IN ('PENDING', 'ACCEPTED', 'ACTIVE') AND postponed_at IS NULL
         GROUP BY client_id HAVING COUNT(*) > 1`,
        [everyone]
      );
      assert.deepEqual(twoOpenOrders, [], 'a client has one open order at a time');

      const orders = await sql(
        `SELECT o.id, o.status, o.price, o.lawyer_amount, o.payout_amount, o.payout_status, o.paid_at, o.commission_percent, o.tax_percent,
                (SELECT COUNT(*)::int FROM payments p WHERE p.order_id = o.id) AS payments,
                (SELECT COALESCE(SUM(p.amount), 0) FROM payments p WHERE p.order_id = o.id) AS paid,
                (SELECT COUNT(*)::int FROM client_credits c WHERE c.order_id = o.id AND c.amount > 0) AS refunds,
                (SELECT COALESCE(SUM(c.amount), 0) FROM client_credits c WHERE c.order_id = o.id AND c.amount > 0) AS refunded
         FROM service_orders o WHERE o.client_id = ANY($1)`,
        [everyone]
      );
      for (const order of orders) {
        const label = `order ${order.id} (${order.status})`;
        assert.equal(Number(order.lawyer_amount), lawyerShare(Number(order.price), Number(order.commission_percent), Number(order.tax_percent)), `${label}: the lawyer's share follows the price`);
        if (!order.paid_at) {
          assert.equal(order.payments, 0, `${label}: never paid, so no payment line`);
          assert.equal(order.refunds, 0, `${label}: never paid, so nothing to give back`);
          continue;
        }
        assert.equal(order.payments, 1, `${label}: paid exactly once`);
        assert.equal(Number(order.paid), Number(order.price), `${label}: paid the full price`);
        if (order.status === 'ACTIVE') {
          assert.equal(order.refunds, 0, `${label}: still running, the money is held`);
        } else if (order.status === 'COMPLETED') {
          assert.equal(order.refunds, 0, `${label}: the lawyer earned it, so nothing goes back`);
          assert.equal(Number(order.payout_amount), Number(order.lawyer_amount), `${label}: the lawyer gets their share, no more and no less`);
        } else {
          assert.equal(order.refunds, 1, `${label}: paid and closed without the task, so the money goes back once`);
          assert.equal(Number(order.refunded), Number(order.price), `${label}: the whole price goes back`);
          assert.equal(order.payout_status, 'REFUNDED', `${label}: and the lawyer is not paid for it`);
        }
      }

      const overdrawn = await sql(
        `SELECT client_id, SUM(amount) AS balance FROM client_credits WHERE client_id = ANY($1) GROUP BY client_id HAVING SUM(amount) < 0`,
        [everyone]
      );
      assert.deepEqual(overdrawn, [], 'no balance goes below zero');

      await sql(`UPDATE platform_settings SET tax_percent = 0`);
    });
  }
});
