const admin = require('firebase-admin');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

rl.question('Enter the path to your service account JSON file (or press Enter to use application default): ', async (keyFilename) => {
  rl.close();

  if (keyFilename && keyFilename.trim() !== '') {
    admin.initializeApp({
      credential: admin.credential.cert(keyFilename.trim())
    });
  } else {
    try {
      admin.initializeApp({
        projectId: 'attendance-checker-9f22b'
      });
    } catch (e) {
      console.log('No project specified, using GOOGLE_APPLICATION_CREDENTIALS...');
      process.exit(1);
    }
  }

  const db = admin.firestore();
  const sourceCollection = 'folders';
  const targetCollection = 'students';

  console.log(`\nStarting migration: ${sourceCollection} -> ${targetCollection}`);
  console.log('Fetching documents from source collection...\n');

  async function migrateCollection() {
    try {
      const sourceSnapshot = await db.collection(sourceCollection).get();

      if (sourceSnapshot.empty) {
        console.log('No documents found in source collection.');
        return;
      }

      console.log(`Found ${sourceSnapshot.size} folder documents.\n`);

      let copiedCount = 0;

      for (let i = 0; i < sourceSnapshot.docs.length; i += 500) {
        const batch = db.batch();
        const batchDocs = sourceSnapshot.docs.slice(i, i + 500);

        for (const doc of batchDocs) {
          const folder = doc.data();
          const embeddedStudents = folder.students || [];

          let createdAt;
          if (typeof folder.createdAt === 'string') {
            createdAt = new Date(folder.createdAt);
          } else if (folder.createdAt && typeof folder.createdAt.toDate === 'function') {
            createdAt = folder.createdAt.toDate();
          } else {
            createdAt = admin.firestore.FieldValue.serverTimestamp();
          }

          for (const rawStudent of embeddedStudents) {
            const student = typeof rawStudent === 'string'
              ? JSON.parse(rawStudent)
              : rawStudent;

            if (!student || !student.id) continue;

            const studentRef = db.collection(targetCollection).doc(student.id);
            batch.set(studentRef, {
              ...student,
              folderId: doc.id,
              ownerId: folder.ownerId || '',
              createdAt: createdAt,
            });
          }
        }

        await batch.commit();
        copiedCount += batchDocs.length;
        console.log(`Processed ${copiedCount}/${sourceSnapshot.size} folders...`);
      }

      console.log(`\n✅ Migration complete!`);
      console.log(`   - Folders processed: ${copiedCount}`);
      console.log(`   - Students written to: ${targetCollection}`);
      console.log(`   - Folder documents were left unchanged (the app still reads them).`);
      console.log(`\n⚠️  Note: Check Firebase Console to verify the migration was successful.`);
    } catch (error) {
      console.error('\n❌ Migration failed:', error.message);
      process.exit(1);
    }
  }

  migrateCollection();
});
