"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupStaleTokens = exports.onNewProduct = exports.onNewMessage = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// Région la plus proche du Cameroun
(0, v2_1.setGlobalOptions)({ region: "europe-west1" });
// ─── Notification : nouveau message ──────────────────────────────────────────
exports.onNewMessage = (0, firestore_1.onDocumentCreated)("conversations/{convId}/messages/{msgId}", async (event) => {
    const message = event.data?.data();
    if (!message)
        return;
    const convId = event.params.convId;
    const senderId = message.sender_id;
    const text = message.text ?? "";
    const isProductCard = !text && message.product_ref;
    // Récupérer la conversation pour trouver le destinataire
    const convDoc = await db.collection("conversations").doc(convId).get();
    if (!convDoc.exists)
        return;
    const participants = convDoc.data()?.participants ?? [];
    const recipientId = participants.find((uid) => uid !== senderId);
    if (!recipientId)
        return;
    // Récupérer le token FCM du destinataire
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    const fcmToken = recipientDoc.data()?.fcm_token;
    if (!fcmToken)
        return;
    // Récupérer le nom de l'expéditeur
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.data()?.username ?? "Utilisateur";
    // Corps de la notification
    const body = isProductCard
        ? "📦 A partagé un produit"
        : text.length > 100
            ? text.substring(0, 100) + "…"
            : text;
    try {
        await messaging.send({
            token: fcmToken,
            notification: {
                title: senderName,
                body,
            },
            data: {
                type: "message",
                sender_id: senderId,
                sender_name: senderName,
                conv_id: convId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "messages",
                    sound: "default",
                    priority: "high",
                },
            },
            apns: {
                payload: {
                    aps: { sound: "default", badge: 1 },
                },
            },
        });
    }
    catch (err) {
        // Token invalide → on le nettoie pour ne plus envoyer
        const firebaseErr = err;
        if (firebaseErr.code === "messaging/registration-token-not-registered" ||
            firebaseErr.code === "messaging/invalid-registration-token") {
            await db
                .collection("users")
                .doc(recipientId)
                .update({ fcm_token: admin.firestore.FieldValue.delete() });
        }
    }
});
// ─── Notification : nouveau produit ajouté ────────────────────────────────────
exports.onNewProduct = (0, firestore_1.onDocumentCreated)("produits/{produitId}", async (event) => {
    const produit = event.data?.data();
    if (!produit)
        return;
    const commerceId = produit.commerce_id;
    const nomProduit = produit.nom ?? "Nouveau produit";
    const prix = produit.prix ?? 0;
    // Récupérer les favoris pour notifier les utilisateurs qui ont mis cette boutique en favori
    const favoritesSnap = await db.collection("favorites").get();
    const tokens = [];
    for (const favDoc of favoritesSnap.docs) {
        const boutiqueIds = favDoc.data()?.boutique_ids ?? [];
        if (!boutiqueIds.includes(commerceId))
            continue;
        const userDoc = await db.collection("users").doc(favDoc.id).get();
        const token = userDoc.data()?.fcm_token;
        if (token)
            tokens.push(token);
    }
    if (tokens.length === 0)
        return;
    // Récupérer le nom de la boutique
    const commerceDoc = await db
        .collection("commercants")
        .doc(commerceId)
        .get();
    const nomBoutique = commerceDoc.data()?.nom_boutique ?? "Une boutique";
    // Envoyer en batch (max 500 tokens par sendEachForMulticast)
    const chunkSize = 500;
    for (let i = 0; i < tokens.length; i += chunkSize) {
        const chunk = tokens.slice(i, i + chunkSize);
        await messaging.sendEachForMulticast({
            tokens: chunk,
            notification: {
                title: `Nouveau chez ${nomBoutique}`,
                body: `${nomProduit} — ${prix.toFixed(0)} FCFA`,
            },
            data: {
                type: "product",
                commerce_id: commerceId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: { priority: "normal" },
        });
    }
});
// ─── Nettoyage : suppression des tokens invalides ─────────────────────────────
exports.cleanupStaleTokens = (0, firestore_1.onDocumentCreated)(
// Déclenché automatiquement lors de l'ajout d'un nouveau rapport
// (simple proxy pour avoir un trigger périodique sans Cloud Scheduler)
"reports/{reportId}", async () => {
    // Rien à faire ici — le nettoyage se fait dans onNewMessage
    // Cette function sert de placeholder pour une future tâche planifiée
    return;
});
//# sourceMappingURL=index.js.map