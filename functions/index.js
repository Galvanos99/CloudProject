const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });

admin.initializeApp();

exports.getImage = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const fileName = req.query.name; // Nazwa pliku przekazana jako parametr w URL
    const bucket = admin.storage().bucket();
    try {
      const file = bucket.file(`IMAGES/OG/${fileName}`); // Ścieżka do pliku w Storage
      const [metadata] = await file.getMetadata(); // Pobranie metadanych pliku
      const signedUrl = await file.getSignedUrl({
        action: "read",
        expires: "03-17-2025", // Data wygaśnięcia dostępu
      });
      res.redirect(signedUrl[0]); // Przekierowanie do URL-a obrazu
    } catch (error) {
      res.status(500).send(`Error fetching the image: ${error.message}`);
    }
  });
});
