const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "com-example-hallc-93786",
});

const db = getFirestore();

const schedule = [
  {
    id: "sunday",
    dayAr: "الأحد",
    order: 1,
    lectures: [
      { subject: "الشعر", professor: "م.م نسرين عبد العباس", start: "08:30 AM", end: "10:00 AM" },
      { subject: "المحادثة", professor: "م.د خورشيد", start: "10:30 AM", end: "12:00 PM" }
    ]
  },
  {
    id: "monday",
    dayAr: "الاثنين",
    order: 2,
    lectures: [
      { subject: "الإرشاد", professor: "م.م سوزان صالح", start: "08:30 AM", end: "10:00 AM" },
      { subject: "عقائد", professor: "م.د صدر الدين القبانجي", start: "10:30 AM", end: "12:00 PM" },
      { subject: "طرائق التدريس", professor: "م.د علي تقي", start: "12:30 PM", end: "02:00 PM" }
    ]
  },
  {
    id: "tuesday",
    dayAr: "الثلاثاء",
    order: 3,
    lectures: [
      { subject: "المسرحية", professor: "م.م حسين علي هادي", start: "08:30 AM", end: "10:00 AM" },
      { subject: "علم اللغة", professor: "م.م بنين حميد", start: "10:30 AM", end: "12:00 PM" }
    ]
  },
  {
    id: "wednesday",
    dayAr: "الأربعاء",
    order: 4,
    lectures: [
      { subject: "النحو", professor: "م.م شيماء خوام", start: "08:30 AM", end: "10:00 AM" },
      { subject: "الكتابة الأكاديمية", professor: "م.م زيد علي عبد الرضا", start: "10:30 AM", end: "12:00 PM" },
      { subject: "الرواية", professor: "م.م علاء عبد الكاظم", start: "12:30 PM", end: "02:00 PM" }
    ]
  }
];

async function main() {
  for (const day of schedule) {
    await db.collection("schedules").doc(day.id).set({
      dayAr: day.dayAr,
      order: day.order,
      lectures: day.lectures
    });

    console.log("Created: " + day.dayAr);
  }

  console.log("ALL SCHEDULE DATA CREATED SUCCESSFULLY");
  process.exit(0);
}

main().catch((error) => {
  console.error("ERROR:", error);
  process.exit(1);
});