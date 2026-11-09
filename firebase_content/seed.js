/**
 * Mengisi materi dan kuis Ruang Belajar ke Firestore.
 *
 * Pemakaian:
 *   1. cd firebase_content && npm install
 *   2. Firebase Console > Project settings > Service accounts > Generate new private key
 *      Simpan sebagai serviceAccountKey.json di folder ini (JANGAN di-commit ke Git).
 *   3. node seed.js            -> tulis/ perbarui semua konten
 *      node seed.js --dry-run  -> hanya validasi, tidak menulis
 *
 * Skrip aman dijalankan berulang kali: dokumen ditulis dengan ID tetap (merge: false),
 * sehingga hasilnya selalu sama dengan isi content.json.
 */
const fs = require('fs');
const path = require('path');

const DRY_RUN = process.argv.includes('--dry-run');
const content = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'content.json'), 'utf8'),
);

function validate({ levels, modules }) {
  const errors = [];
  const levelIds = new Set(levels.map((l) => l.id));
  const moduleIds = new Set();

  for (const m of modules) {
    if (moduleIds.has(m.id)) errors.push(`ID modul ganda: ${m.id}`);
    moduleIds.add(m.id);
    if (!levelIds.has(m.levelId)) errors.push(`${m.id}: levelId tidak dikenal`);
    if (!m.title || !m.description) errors.push(`${m.id}: title/description kosong`);
    if (!Array.isArray(m.sections) || m.sections.length === 0) {
      errors.push(`${m.id}: sections kosong`);
    }
    const qs = (m.quiz && m.quiz.questions) || [];
    if (qs.length === 0) errors.push(`${m.id}: kuis tidak punya soal`);
    qs.forEach((q, i) => {
      if (!Array.isArray(q.options) || q.options.length < 2) {
        errors.push(`${m.id} soal ${i + 1}: pilihan kurang dari 2`);
      } else if (
        !Number.isInteger(q.correctIndex) ||
        q.correctIndex < 0 ||
        q.correctIndex >= q.options.length
      ) {
        errors.push(`${m.id} soal ${i + 1}: correctIndex di luar rentang`);
      }
    });
  }
  return errors;
}

async function main() {
  const errors = validate(content);
  if (errors.length) {
    console.error('Validasi gagal:\n- ' + errors.join('\n- '));
    process.exit(1);
  }
  console.log(
    `Validasi OK: ${content.levels.length} level, ${content.modules.length} modul.`,
  );
  if (DRY_RUN) return;

  const admin = require('firebase-admin');
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    console.error('serviceAccountKey.json tidak ditemukan di folder ini.');
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  const db = admin.firestore();

  const batch = db.batch();
  for (const { id, ...level } of content.levels) {
    batch.set(db.collection('belajar_levels').doc(id), level);
  }
  for (const { id, ...mod } of content.modules) {
    batch.set(db.collection('belajar_modules').doc(id), mod);
  }
  await batch.commit();
  console.log('Selesai: konten berhasil ditulis ke Firestore.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
