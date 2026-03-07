const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize the Firebase Admin SDK inside the function
admin.initializeApp();

// Listens to new documents inside the 'notifications' collection
exports.sendEventNotification = functions.firestore
    .document('notifications/{docId}')
    .onCreate(async (snap, context) => {
        // Get the newly inserted document data
        const newValue = snap.data();
        
        // Construct the notification payload
        const payload = {
            notification: {
                title: newValue.title || 'New Event',
                body: newValue.body || 'Tap to check out the details!',
                // You can add an icon here if needed
                // icon: 'default', 
            },
            data: {
                eventId: newValue.eventId || '',
                eventName: newValue.eventName || newValue.title || '',
                type: newValue.type || 'event_notification',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            }
        };

        try {
            // Send the message to devices subscribed to the 'all_events' topic
            const response = await admin.messaging().sendToTopic(newValue.topic || 'all_events', payload);
            console.log('Successfully sent message:', response);
            return null;
        } catch (error) {
            console.error('Error sending message:', error);
            return null;
        }
    });
