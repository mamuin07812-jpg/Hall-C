const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

const db = getFirestore();
const HALLS = ["A", "B", "C", "D"];
const VALID_STAGES = new Set(["first stage", "second stage", "third stage", "fourth stage"]);

function clean(value) {
  return String(value == null ? "" : value).trim();
}

function norm(value) {
  return clean(value).toLowerCase().replace(/\\s+/g, " ");
}

function department(value) {
  const v = norm(value);
  if (v.includes("english") || v.includes("اللغة الانكليزية") ||
      v.includes("اللغة الإنجليزية") || v.includes("اللغة الانجليزية") ||
      v.includes("اللغة الإنكليزية")) return "english language department";
  return v;
}

function stage(value) {
  const v = norm(value);
  const aliases = {
    "1": "first stage", "first": "first stage", "first stage": "first stage",
    "2": "second stage", "second": "second stage", "second stage": "second stage",
    "3": "third stage", "third": "third stage", "third stage": "third stage",
    "4": "fourth stage", "fourth": "fourth stage", "fourth stage": "fourth stage",
    "المرحلة الأولى": "first stage", "المرحلة الاولى": "first stage",
    "المرحلة الثانية": "second stage", "المرحلة الثانيه": "second stage",
    "المرحلة الثالثة": "third stage", "المرحلة الثالثه": "third stage",
    "المرحلة الرابعة": "fourth stage", "المرحلة الرابعه": "fourth stage",
  };
  return aliases[v] || v;
}

function hall(value) {
  const v = clean(value).toUpperCase();
  return HALLS.includes(v) ? v : "";
}

async function docs(collection) {
  const snapshot = await db.collection(collection).get();
  return snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
}

async function resolveAudience(data) {
  const subject = clean(data.subject);
  if (!subject) return null;

  if (clean(data.teacherId)) {
    const teacherId = clean(data.teacherId);
    const teacherDoc = await db.collection("teachers").doc(teacherId).get();
    if (!teacherDoc.exists) return null;
    const teacher = teacherDoc.data();
    if (norm(teacher.role) !== "teacher" || norm(teacher.status) !== "approved" ||
        teacher.blocked === true) return null;

    const dep = department(data.department || teacher.department);
    const profileDep = department(teacher.department);
    const selectedSubject = norm(teacher.subject || teacher.specialization);
    const selectedStage = stage(data.stage || teacher.stage);
    if (!dep || dep !== profileDep || !selectedSubject || norm(subject) !== selectedSubject ||
        !VALID_STAGES.has(selectedStage) ||
        (stage(teacher.stage) && stage(teacher.stage) !== selectedStage)) return null;
    if ((clean(data.lastEditorUid) && clean(data.lastEditorUid) !== teacherId) ||
        (clean(data.lastEditorType) && norm(data.lastEditorType) !== "teacher")) return null;

    const group = clean(data.group).toUpperCase();
    let targetHalls;
    if (group === "ALL") {
      const audience = Array.isArray(data.audienceHalls) ? data.audienceHalls.map(hall) : [];
      const visible = Array.isArray(data.visibleToHalls) ? data.visibleToHalls.map(hall) : [];
      if (audience.length === 0 && visible.length === 0) {
        targetHalls = [...HALLS];
      } else if (audience.length === 4 && HALLS.every((h) => audience.includes(h)) &&
          visible.length === 4 && HALLS.every((h) => visible.includes(h))) {
        targetHalls = [...HALLS];
      } else {
        return null;
      }
    } else {
      const selectedHall = hall(group);
      const audience = Array.isArray(data.audienceHalls) ? data.audienceHalls.map(hall) : [];
      const visible = Array.isArray(data.visibleToHalls) ? data.visibleToHalls.map(hall) : [];
      if (!selectedHall) return null;
      if (audience.length && (audience.length !== 1 || audience[0] !== selectedHall)) return null;
      if (visible.length && (visible.length !== 1 || visible[0] !== selectedHall)) return null;
      if (audience.length !== visible.length) return null;
      targetHalls = [selectedHall];
    }
    return {kind: "teacher", department: dep, stage: selectedStage, halls: targetHalls};
  }

  if (norm(data.creatorType) !== "representative" || !clean(data.creatorUid)) return null;
  const uid = clean(data.creatorUid);
  if ((clean(data.lastEditorUid) && clean(data.lastEditorUid) !== uid) ||
      (clean(data.lastEditorType) && norm(data.lastEditorType) !== "representative")) return null;
  const reps = await docs("representatives");
  const rep = reps.find((item) => clean(item.uid || item.id) === uid);
  if (!rep || rep.active !== true || rep.blocked === true) return null;
  const repHall = hall(rep.hall);
  const dep = department(data.department);
  const selectedStage = stage(data.stage);
  if (!repHall || !dep || !VALID_STAGES.has(selectedStage) ||
      clean(data.group).toUpperCase() !== repHall) return null;
  const audience = Array.isArray(data.audienceHalls) ? data.audienceHalls.map(hall) : [];
  const visible = Array.isArray(data.visibleToHalls) ? data.visibleToHalls.map(hall) : [];
  if (audience.length !== 1 || audience[0] !== repHall ||
      visible.length !== 1 || visible[0] !== repHall) return null;

  const schedules = await docs("schedules");
  const allowedSubjects = new Set();
  for (const row of schedules) {
    if (hall(row.group) !== repHall || department(row.department) !== dep ||
        stage(row.stage) !== selectedStage) continue;
    if (clean(row.subject)) allowedSubjects.add(norm(row.subject));
    for (const day of Array.isArray(row.days) ? row.days : []) {
      for (const lecture of Array.isArray(day && day.lectures) ? day.lectures : []) {
        if (clean(lecture.subject)) allowedSubjects.add(norm(lecture.subject));
      }
    }
  }
  if (!allowedSubjects.has(norm(subject))) return null;
  return {kind: "representative", department: dep, stage: selectedStage, halls: [repHall]};
}

async function claimDelivery(eventId) {
  const ref = db.collection("_preparationNotificationDeliveries").doc(eventId);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const current = snapshot.exists ? snapshot.data() : {};
    if (current.status === "sent") return {claimed: false, ref};
    if (current.status === "processing" && current.leaseUntil &&
        current.leaseUntil.toMillis() > Date.now()) return {claimed: false, ref};
    tx.set(ref, {
      status: "processing",
      attempts: Number(current.attempts || 0) + 1,
      leaseUntil: Timestamp.fromMillis(Date.now() + 4 * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {claimed: true, ref};
  });
}

exports.notifyTeacherPreparationOnCreate = onDocumentCreated({
  document: "preparations/{preparationId}",
  retry: true,
  maxInstances: 5,
}, async (event) => deliverPreparation(event, "teacher"));

exports.notifyRepresentativePreparationOnCreate = onDocumentCreated({
  document: "preparations/{preparationId}",
  retry: true,
  maxInstances: 5,
}, async (event) => deliverPreparation(event, "representative"));

async function deliverPreparation(event, expectedKind) {
  const data = event.data && event.data.data();
  if (!data) return;
  const audience = await resolveAudience(data);
  if (!audience || audience.kind !== expectedKind) return;

  const eventId = event.params.preparationId + "-" + expectedKind + "-created";
  const claim = await claimDelivery(eventId);
  if (!claim.claimed) return;

  try {
    const students = await docs("students");
    const recipientUids = new Set(students.filter((student) =>
      norm(student.role) === "student" && student.blocked !== true &&
      department(student.department) === audience.department &&
      stage(student.stage) === audience.stage &&
      audience.halls.includes(hall(student.group))
    ).map((student) => clean(student.uid || student.id)).filter(Boolean));

    const tokenDocs = await docs("notification_tokens");
    const tokenByValue = new Map();
    for (const record of tokenDocs) {
      const uid = clean(record.uid);
      const token = clean(record.token);
      if (!uid || !token || norm(record.platform) !== "android" ||
          !recipientUids.has(uid)) continue;
      tokenByValue.set(token, {uid, token});
    }
    const tokens = [...tokenByValue.keys()];
    if (!tokens.length) {
      await claim.ref.set({
        status: "no_tokens",
        recipientCount: recipientUids.size,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }

    const subject = clean(data.subject);
    const message = {
      notification: {
        title: "Schoolivia UN",
        body: "تمت إضافة تحضير مادة: " + subject,
      },
      data: {
        type: "preparation",
        documentId: event.params.preparationId,
        eventType: "created",
        eventId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "classroom_hub_notifications_v2",
          tag: eventId,
        },
      },
    };

    let sent = 0;
    let failed = 0;
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const result = await getMessaging().sendEachForMulticast({...message, tokens: batch});
      sent += result.successCount;
      failed += result.failureCount;
      if (result.failureCount > 0) {
        const retryable = result.responses.some((response) =>
          !response.success && response.error &&
          !String(response.error.code || "").includes("registration-token-not-registered") &&
          !String(response.error.code || "").includes("invalid-registration-token")
        );
        if (retryable) throw new Error("Transient FCM delivery failure; retry requested.");
      }
    }

    await claim.ref.set({
      status: "sent",
      recipientCount: recipientUids.size,
      tokenCount: tokens.length,
      acceptedCount: sent,
      failedCount: failed,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    console.log("Preparation notification delivery completed", {
      eventId, route: expectedKind, recipientCount: recipientUids.size,
      tokenCount: tokens.length, acceptedCount: sent, failedCount: failed,
    });
  } catch (error) {
    await claim.ref.set({
      status: "failed",
      lastError: String(error && error.message || error).slice(0, 500),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    throw error;
  }
}
