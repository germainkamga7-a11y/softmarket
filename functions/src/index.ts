import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Région la plus proche du Cameroun
setGlobalOptions({ region: "europe-west1" });

// ─── Notification : nouveau message ──────────────────────────────────────────

export const onNewMessage = onDocumentCreated(
  "conversations/{convId}/messages/{msgId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const convId = event.params.convId;
    const senderId: string = message.sender_id;
    const text: string = message.text ?? "";
    const isProductCard = !text && message.product_ref;

    // Récupérer la conversation pour trouver le destinataire
    const convDoc = await db.collection("conversations").doc(convId).get();
    if (!convDoc.exists) return;

    const participants: string[] = convDoc.data()?.participants ?? [];
    const recipientId = participants.find((uid) => uid !== senderId);
    if (!recipientId) return;

    // Récupérer le token FCM du destinataire
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    const fcmToken: string | undefined = recipientDoc.data()?.fcm_token;
    if (!fcmToken) return;

    // Récupérer le nom de l'expéditeur
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName: string =
      senderDoc.data()?.username ?? "Utilisateur";

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
    } catch (err: unknown) {
      // Token invalide → on le nettoie pour ne plus envoyer
      const firebaseErr = err as { code?: string };
      if (
        firebaseErr.code === "messaging/registration-token-not-registered" ||
        firebaseErr.code === "messaging/invalid-registration-token"
      ) {
        await db
          .collection("users")
          .doc(recipientId)
          .update({ fcm_token: admin.firestore.FieldValue.delete() });
      }
    }
  }
);

// ─── Notification : nouveau produit ajouté ────────────────────────────────────

export const onNewProduct = onDocumentCreated(
  "produits/{produitId}",
  async (event) => {
    const produit = event.data?.data();
    if (!produit) return;

    const commerceId: string = produit.commerce_id;
    const nomProduit: string = produit.nom ?? "Nouveau produit";
    const prix: number = produit.prix ?? 0;

    // Récupérer les favoris pour notifier les utilisateurs qui ont mis cette boutique en favori
    const favoritesSnap = await db.collection("favorites").get();
    const tokens: string[] = [];

    for (const favDoc of favoritesSnap.docs) {
      const boutiqueIds: string[] = favDoc.data()?.boutique_ids ?? [];
      if (!boutiqueIds.includes(commerceId)) continue;

      const userDoc = await db.collection("users").doc(favDoc.id).get();
      const token: string | undefined = userDoc.data()?.fcm_token;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    // Récupérer le nom de la boutique
    const commerceDoc = await db
      .collection("commercants")
      .doc(commerceId)
      .get();
    const nomBoutique: string =
      commerceDoc.data()?.nom_boutique ?? "Une boutique";

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
  }
);

// ─── Notification : nouvelle commande → vendeur ───────────────────────────────

export const onNewOrder = onDocumentCreated(
  "commandes/{commandeId}",
  async (event) => {
    const order = event.data?.data();
    if (!order) return;

    const commandeId: string = event.params.commandeId;
    const buyerId: string = order.userId;
    const total: number = order.total ?? 0;
    const items: Array<{ commerceId: string; commerceNom: string; nom: string }> =
      order.items ?? [];

    if (items.length === 0) return;

    // Grouper par commerceId pour notifier chaque vendeur une seule fois
    const commerceIds = [...new Set(items.map((i) => i.commerceId))];

    // Récupérer le nom de l'acheteur
    const buyerDoc = await db.collection("users").doc(buyerId).get();
    const buyerName: string = buyerDoc.data()?.username ?? "Un client";

    for (const commerceId of commerceIds) {
      // Récupérer le commerçant
      const commerceDoc = await db.collection("commercants").doc(commerceId).get();
      if (!commerceDoc.exists) continue;

      const sellerId: string = commerceDoc.data()?.user_id;
      if (!sellerId || sellerId === buyerId) continue;

      // Token FCM du vendeur
      const sellerDoc = await db.collection("users").doc(sellerId).get();
      const fcmToken: string | undefined = sellerDoc.data()?.fcm_token;
      if (!fcmToken) continue;

      const nomBoutique: string = commerceDoc.data()?.nom_boutique ?? "votre boutique";
      const itemCount = items.filter((i) => i.commerceId === commerceId).length;
      const body = `${buyerName} — ${itemCount} article${itemCount > 1 ? "s" : ""} · ${total.toFixed(0)} FCFA`;

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: `🛒 Nouvelle commande sur ${nomBoutique}`,
            body,
          },
          data: {
            type: "order",
            order_id: commandeId,
            commerce_id: commerceId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "orders",
              sound: "default",
              priority: "high",
            },
          },
          apns: {
            payload: { aps: { sound: "default", badge: 1 } },
          },
        });
      } catch (err: unknown) {
        const firebaseErr = err as { code?: string };
        if (
          firebaseErr.code === "messaging/registration-token-not-registered" ||
          firebaseErr.code === "messaging/invalid-registration-token"
        ) {
          await db.collection("users").doc(sellerId).update({
            fcm_token: admin.firestore.FieldValue.delete(),
          });
        }
      }
    }
  }
);

// ─── Notification : changement de statut commande → acheteur ─────────────────

const STATUS_LABELS: Record<string, string> = {
  confirmee:    "✅ Commande confirmée",
  en_livraison: "🚚 En cours de livraison",
  livree:       "📦 Commande livrée !",
  annulee:      "❌ Commande annulée",
};

export const onOrderStatusChanged = onDocumentUpdated(
  "commandes/{commandeId}",
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;

    const oldStatut: string = before.statut;
    const newStatut: string = after.statut;

    // Ne déclencher que si le statut a réellement changé
    if (oldStatut === newStatut) return;

    const label = STATUS_LABELS[newStatut];
    if (!label) return;

    const buyerId: string = after.userId;
    const commandeId: string = event.params.commandeId;
    const total: number = after.total ?? 0;

    // Token FCM de l'acheteur
    const buyerDoc = await db.collection("users").doc(buyerId).get();
    const fcmToken: string | undefined = buyerDoc.data()?.fcm_token;
    if (!fcmToken) return;

    const items: Array<{ nom: string }> = after.items ?? [];
    const firstItem = items[0]?.nom ?? "votre commande";

    try {
      await messaging.send({
        token: fcmToken,
        notification: {
          title: label,
          body: `${firstItem}${items.length > 1 ? ` +${items.length - 1} autre(s)` : ""} · ${total.toFixed(0)} FCFA`,
        },
        data: {
          type: "order_status",
          order_id: commandeId,
          statut: newStatut,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "orders",
            sound: "default",
            priority: "high",
          },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      });
    } catch (err: unknown) {
      const firebaseErr = err as { code?: string };
      if (
        firebaseErr.code === "messaging/registration-token-not-registered" ||
        firebaseErr.code === "messaging/invalid-registration-token"
      ) {
        await db.collection("users").doc(buyerId).update({
          fcm_token: admin.firestore.FieldValue.delete(),
        });
      }
    }
  }
);

// ─── Nettoyage : suppression des tokens invalides ─────────────────────────────

export const cleanupStaleTokens = onDocumentCreated(
  // Déclenché automatiquement lors de l'ajout d'un nouveau rapport
  // (simple proxy pour avoir un trigger périodique sans Cloud Scheduler)
  "reports/{reportId}",
  async () => {
    // Rien à faire ici — le nettoyage se fait dans onNewMessage
    // Cette function sert de placeholder pour une future tâche planifiée
    return;
  }
);
