const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "com-example-hallc-93786",
});

const db = getFirestore();

const preparations = [
  {
    id: "poetry",
    subject: "الشعر",
    professor: "م.م نسرين عبد العباس",
  },
  {
    id: "conversation",
    subject: "المحادثة",
    professor: "م.د خورشيد",
  },
  {
    id: "guidance",
    subject: "الإرشاد",
    professor: "م.م سوزان صالح",
  },
  {
    id: "creeds",
    subject: "عقائد",
    professor: "م.د صدر الدين القبانجي",
  },
  {
    id: "teaching_methods",
    subject: "طرائق التدريس",
    professor: "م.د علي تقي",
  },
  {
    id: "drama",
    subject: "المسرحية",
    professor: "م.م حسين علي هادي",
  },
  {
    id: "linguistics",
    subject: "علم اللغة",
    professor: "م.م بنين حميد",
  },
  {
    id: "grammar",
    subject: "النحو",
    professor: "م.م شيماء خوام",
  },
  {
    id: "academic_writing",
    subject: "الكتابة الأكاديمية",
    professor: "م.م زيد علي عبد الرضا",
  },
  {
    id: "novel",
    subject: "الرواية",
    professor: "م.م علاء عبد الكاظم",
  },
];

async function main() {
  for (const item of preparations) {
    await db.collection("preparations").doc(item.id).set({
      subject: item.subject,
      professor: item.professor,
      content: "",
      updatedAt: new Date(),
    });

    console.log("Created: " + item.subject);
  }

  console.log("ALL PREPARATIONS DATA CREATED SUCCESSFULLY");
  process.exit(0);
}

main().catch((error) => {
  console.error("ERROR:", error);
  process.exit(1);
});