/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

if (getApps().length === 0) initializeApp();
const db = getFirestore();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

const SCHEDULE_DAYS = new Map([
  ['الأحد', 'Sunday'],
  ['الاثنين', 'Monday'],
  ['الثلاثاء', 'Tuesday'],
  ['الأربعاء', 'Wednesday'],
]);

function scheduleHall(value) {
  const hall = String(value || '').trim().toUpperCase();
  return ['A', 'B', 'C', 'D'].includes(hall) ? hall : '';
}

exports.saveTeacherScheduleLecture = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in as a teacher first.');

  const teacherSnapshot = await db.collection('teachers').doc(uid).get();
  const teacher = teacherSnapshot.data();
  if (!teacherSnapshot.exists || String(teacher?.role || '').toLowerCase() !== 'teacher') {
    throw new HttpsError('permission-denied', 'A verified teacher account is required.');
  }

  const department = String(teacher.department || '').trim();
  const stage = String(teacher.stage || '').trim();
  if (!department || !stage) {
    throw new HttpsError('failed-precondition', 'The teacher profile must include department and stage.');
  }

  const input = request.data || {};
  const dayAr = String(input.dayAr || '').trim();
  const subject = String(input.subject || '').trim();
  const start = String(input.start || '').trim();
  const end = String(input.end || '').trim();
  const group = String(input.group || '').trim().toUpperCase();
  const rawHalls = Array.isArray(input.audienceHalls) ? input.audienceHalls : [];
  const audienceHalls = [...new Set(rawHalls.map(scheduleHall))];
  if (!SCHEDULE_DAYS.has(dayAr) || !subject || !start || !end) {
    throw new HttpsError('invalid-argument', 'Day, subject, start time and end time are required.');
  }
  if (group === 'ALL') {
    if (audienceHalls.length !== 4 || !['A', 'B', 'C', 'D'].every((hall) => audienceHalls.includes(hall))) {
      throw new HttpsError('invalid-argument', 'All-halls targeting must include A, B, C and D exactly.');
    }
  } else if (!scheduleHall(group) || audienceHalls.length !== 1 || audienceHalls[0] !== group) {
    throw new HttpsError('invalid-argument', 'Select one valid hall or all four halls.');
  }

  const professor = String(teacher.name || '').trim();
  const documentId = String(input.documentId || '').trim();
  const nowFields = {
    dayAr,
    day: SCHEDULE_DAYS.get(dayAr),
    subject,
    teacher: professor,
    professor,
    startTime: start,
    endTime: end,
    start,
    end,
    teacherId: uid,
    department,
    stage,
    group,
    audienceHalls,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (documentId) {
    const ref = db.collection('schedules').doc(documentId);
    const existing = await ref.get();
    if (!existing.exists || existing.data()?.teacherId !== uid) {
      throw new HttpsError('permission-denied', 'You can only edit lectures created by your own teacher account.');
    }
    await ref.update(nowFields);
    return {documentId, operation: 'updated'};
  }

  const created = await db.collection('schedules').add({
    ...nowFields,
    createdAt: FieldValue.serverTimestamp(),
  });
  return {documentId: created.id, operation: 'created'};
});
