const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

setGlobalOptions({maxInstances: 10});
if (getApps().length === 0) initializeApp();

const db = getFirestore();
const SCHEDULE_DAYS = new Map([
  ["الأحد", "Sunday"],
  ["الاثنين", "Monday"],
  ["الثلاثاء", "Tuesday"],
  ["الأربعاء", "Wednesday"],
]);

/**
 * Normalize a hall selection, returning an empty string for invalid values.
 * @param {string} value Hall identifier.
 * @return {string} A valid hall identifier or an empty string.
 */
function scheduleHall(value) {
  const hall = String(value || "").trim().toUpperCase();
  return ["A", "B", "C", "D"].includes(hall) ? hall : "";
}

/**
 * Convert a 12-hour or 24-hour clock value to minutes after midnight.
 * @param {string} value Time value.
 * @return {?number} Minutes after midnight, or null for invalid input.
 */
function timeToMinutes(value) {
  const text = String(value || "").trim().toUpperCase();
  const match12 = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/.exec(text);
  if (match12) {
    let hour = Number(match12[1]);
    const minute = Number(match12[2]);
    if (hour < 1 || hour > 12 || minute > 59) return null;
    if (hour === 12) hour = 0;
    if (match12[3] === "PM") hour += 12;
    return hour * 60 + minute;
  }
  const match24 = /^(\d{1,2}):(\d{2})$/.exec(text);
  if (!match24) return null;
  const hour = Number(match24[1]);
  const minute = Number(match24[2]);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

exports.saveTeacherScheduleLecture = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError(
        "unauthenticated", "Sign in as a teacher first.");
  }

  const teacherSnapshot = await db.collection("teachers").doc(uid).get();
  const teacher = teacherSnapshot.exists ? teacherSnapshot.data() : null;
  const role = String((teacher && teacher.role) || "").toLowerCase();
  if (!teacherSnapshot.exists || role !== "teacher") {
    throw new HttpsError(
        "permission-denied", "A verified teacher account is required.");
  }

  const department = String(teacher.department || "").trim();
  const stage = String(teacher.stage || "").trim();
  if (!department || !stage) {
    throw new HttpsError(
        "failed-precondition",
        "The teacher profile must include department and stage.");
  }

  const input = request.data || {};
  const dayAr = String(input.dayAr || "").trim();
  const subject = String(input.subject || "").trim();
  const start = String(input.start || "").trim();
  const end = String(input.end || "").trim();
  const group = String(input.group || "").trim().toUpperCase();
  const rawHalls = Array.isArray(input.audienceHalls) ?
    input.audienceHalls : [];
  const audienceHalls = [...new Set(rawHalls.map(scheduleHall))];

  const startMinutes = timeToMinutes(start);
  const endMinutes = timeToMinutes(end);
  if (!SCHEDULE_DAYS.has(dayAr) || !subject ||
      startMinutes === null || endMinutes === null ||
      startMinutes >= endMinutes) {
    throw new HttpsError(
        "invalid-argument",
        "Provide a valid day, subject and time range.");
  }

  if (group === "ALL") {
    const allHalls = ["A", "B", "C", "D"];
    const complete = audienceHalls.length === 4 &&
      allHalls.every((hall) => audienceHalls.includes(hall));
    if (!complete) {
      throw new HttpsError(
          "invalid-argument",
          "All-halls targeting must include A, B, C and D.");
    }
  } else if (
    !scheduleHall(group) ||
    audienceHalls.length !== 1 ||
    audienceHalls[0] !== group
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Select one valid hall or all four halls.");
  }

  const professor = String(teacher.name || "").trim();
  const documentId = String(input.documentId || "").trim();
  const lectureFields = {
    dayAr: dayAr,
    day: SCHEDULE_DAYS.get(dayAr),
    subject: subject,
    teacher: professor,
    professor: professor,
    startTime: start,
    endTime: end,
    start: start,
    end: end,
    teacherId: uid,
    department: department,
    stage: stage,
    group: group,
    audienceHalls: audienceHalls,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (documentId) {
    const ref = db.collection("schedules").doc(documentId);
    const existing = await ref.get();
    const existingData = existing.exists ? existing.data() : null;
    if (!existing.exists || !existingData ||
        existingData.teacherId !== uid) {
      throw new HttpsError(
          "permission-denied",
          "You can only edit your own teacher lectures.");
    }
    await ref.update(lectureFields);
    return {documentId: documentId, operation: "updated"};
  }

  const created = await db.collection("schedules").add({
    ...lectureFields,
    createdAt: FieldValue.serverTimestamp(),
  });
  return {documentId: created.id, operation: "created"};
});

// Independent Firestore preparation routes; existing exports stay unchanged.
Object.assign(exports, require("./preparation_notifications"));
