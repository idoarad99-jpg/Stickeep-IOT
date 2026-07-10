const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();

// Shared secret the ESP32 sends in an `x-device-key` header. Set with:
//   firebase functions:secrets:set DEVICE_API_KEY
// Give the same value to Ido to hardcode into the firmware. This is not
// real per-device auth — it's a lightweight "you're a Stickeep seat unit,
// not a stranger on the internet" check, since the ESP32 has no Firebase
// Auth capability at all.
const DEVICE_API_KEY = defineSecret('DEVICE_API_KEY');

const db = admin.firestore();
const rtdb = admin.database();

// NFC UIDs can come back from different reader libraries as "04:80:7D:CA"
// or "04 80 7D CA" or "04807DCA" — normalize before comparing.
function normalizeCardId(raw) {
  return String(raw || '').replace(/[:\s-]/g, '').toUpperCase();
}

/**
 * POST body: { "seatId": "SEAT_T2_1", "cardId": "04:80:7D:CA:C5:78:80" }
 * Header:    x-device-key: <DEVICE_API_KEY>
 *
 * Confirms arrival for the seat's currently active reservation if the
 * scanned NFC card matches the reservation's registered card, mirroring
 * what the app's QR-based arrival flow already does in
 * lib/screens/student/scanner_screen.dart — this is the same operation,
 * triggered by a physical NFC tap instead of a phone camera scan.
 */
exports.confirmNfcArrival = onRequest(
  { secrets: [DEVICE_API_KEY], cors: false },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    const providedKey = req.get('x-device-key');
    if (!providedKey || providedKey !== DEVICE_API_KEY.value()) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { seatId, cardId } = req.body || {};
    if (!seatId || !cardId) {
      res.status(400).json({ error: 'seatId and cardId are required' });
      return;
    }

    const scannedCard = normalizeCardId(cardId);

    try {
      const seatRef = db.collection('seats').doc(seatId);
      const seatSnap = await seatRef.get();

      if (!seatSnap.exists) {
        res.status(404).json({ error: 'Unknown seat' });
        return;
      }

      const seat = seatSnap.data();

      if (seat.status !== 'reserved') {
        res
          .status(409)
          .json({ error: 'No active reservation awaiting arrival for this seat' });
        return;
      }

      const expectedCard = normalizeCardId(seat.nfcSerialNumber);
      if (!expectedCard || expectedCard !== scannedCard) {
        // Signal a declined attempt so the UI's "✗ Access denied" badge
        // (already built in reservation_card.dart) can light up live —
        // best-effort only, we don't know which reservation without a
        // match, so this can't be more specific than the seat's current one.
        const reservationId = seat.reservationId;
        if (reservationId) {
          await markNfcStatus(reservationId, 'declined').catch(() => {});
        }
        res.status(403).json({ error: 'Card does not match the reserved student' });
        return;
      }

      const reservationId = seat.reservationId;
      if (!reservationId) {
        res.status(409).json({ error: 'Seat has no linked reservation' });
        return;
      }

      const reservationRef = db.collection('reservations').doc(reservationId);
      const reservationSnap = await reservationRef.get();
      if (!reservationSnap.exists) {
        res.status(404).json({ error: 'Reservation not found' });
        return;
      }
      const reservation = reservationSnap.data();
      const uid = reservation.userId;

      const now = admin.firestore.FieldValue.serverTimestamp();

      await Promise.all([
        seatRef.update({ status: 'occupied', updatedAt: now }),
        seatRef.collection('reservations').doc(reservationId).update({ status: 'occupied' }),
        reservationRef.update({ status: 'occupied' }),
        // Hardware-facing signal, same path booking.dart/cancel_reservation.dart use.
        rtdb.ref(`seats/${seatId}`).update({ status: 'occupied' }),
        markNfcStatus(reservationId, 'approved', uid),
      ]);

      let studentName = '';
      try {
        const studentSnap = await db.collection('students').doc(uid).get();
        studentName = studentSnap.data()?.name || '';
      } catch (e) {
        // best-effort only, not worth failing the whole request over
      }

      res.status(200).json({ success: true, studentName });
    } catch (err) {
      console.error('confirmNfcArrival failed', err);
      res.status(500).json({ error: 'Internal error' });
    }
  }
);

/**
 * GET ?seatId=SEAT_T2_1
 * Header: x-device-key: <DEVICE_API_KEY>
 *
 * Read-proxy for the seat display's polling loop (FirebaseManager.ino's
 * updateReservationsFromFirebase). Not required today — the direct
 * Firestore read at seats/{seatId}/reservations is world-readable — this
 * exists so that read can eventually be locked back down to
 * "signed-in users only" with zero public exception, once the firmware
 * is switched to call this endpoint instead of hitting Firestore directly.
 *
 * DO NOT tighten the seats/{seatId}/reservations Firestore rule until
 * Ido's firmware has actually been redeployed to call this endpoint —
 * doing so first will break every seat display again, the same way the
 * original rules deploy did on 2026-07-09.
 *
 * Returns a flat, already-unwrapped array (unlike Firestore's verbose
 * REST format with fields.stringValue everywhere), so the firmware's JSON
 * parsing gets simpler too, not just more secure.
 */
exports.getSeatReservations = onRequest(
  { secrets: [DEVICE_API_KEY], cors: false },
  async (req, res) => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    const providedKey = req.get('x-device-key');
    if (!providedKey || providedKey !== DEVICE_API_KEY.value()) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const seatId = req.query.seatId;
    if (!seatId) {
      res.status(400).json({ error: 'seatId is required' });
      return;
    }

    try {
      const snap = await db.collection('seats').doc(seatId).collection('reservations').get();
      const reservations = snap.docs.map((doc) => {
        const data = doc.data();
        return {
          qrToken: data.qrToken || doc.id,
          date: data.date || '',
          startTime: data.startTime || '',
          endTime: data.endTime || '',
          status: data.status || '',
          studentNumber: data.studentNumber || '',
        };
      });
      res.status(200).json({ reservations });
    } catch (err) {
      console.error('getSeatReservations failed', err);
      res.status(500).json({ error: 'Internal error' });
    }
  }
);

// Finds the RTDB reservation entry (keyed by push-id, not the Firestore
// reservationId) via its qr_token field, and sets nfc_status on it — the
// exact field lib/widgets/reservation_card.dart's live badge listens to.
async function markNfcStatus(reservationId, status, knownUid) {
  let uid = knownUid;
  if (!uid) {
    const reservationSnap = await db.collection('reservations').doc(reservationId).get();
    uid = reservationSnap.data()?.userId;
  }
  if (!uid) return;

  const userReservationsSnap = await rtdb.ref(`reservations/${uid}`).get();
  if (!userReservationsSnap.exists()) return;

  const entries = userReservationsSnap.val();
  const matchKey = Object.keys(entries).find(
    (key) => entries[key].qr_token === reservationId
  );
  if (matchKey) {
    await rtdb.ref(`reservations/${uid}/${matchKey}`).update({ nfc_status: status });
  }
}
