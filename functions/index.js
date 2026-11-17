/**
 * Pembersih akun yang belum memverifikasi email.
 *
 * Akun email/password dibuat oleh Firebase Auth sejak pendaftaran (syarat agar
 * link verifikasi bisa dikirim). Kalau pengguna tidak pernah memverifikasi,
 * akun tersebut jadi sampah di Authentication. Function ini menghapusnya
 * otomatis setelah 24 jam.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 */
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();

const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const PAGE_SIZE = 1000;

exports.purgeUnverifiedUsers = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'Asia/Jakarta',
    region: 'asia-southeast2',
  },
  async () => {
    const cutoff = Date.now() - MAX_AGE_MS;
    let nextPageToken;
    let deleted = 0;

    do {
      const result = await admin.auth().listUsers(PAGE_SIZE, nextPageToken);

      for (const user of result.users) {
        const isEmailPassword = user.providerData.some(
          (provider) => provider.providerId === 'password',
        );
        if (!isEmailPassword || user.emailVerified) continue;

        const createdAt = user.metadata?.creationTime
          ? Date.parse(user.metadata.creationTime)
          : NaN;
        if (!Number.isFinite(createdAt) || createdAt > cutoff) continue;

        try {
          await admin.auth().deleteUser(user.uid);
          deleted += 1;
        } catch (error) {
          console.error(`Gagal menghapus user ${user.uid}:`, error);
        }
      }

      nextPageToken = result.pageToken;
    } while (nextPageToken);

    console.log(`Selesai. ${deleted} akun belum terverifikasi dihapus.`);
  },
);
