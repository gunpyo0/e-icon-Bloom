const {setGlobalOptions} = require("firebase-functions");
const {onCall} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

setGlobalOptions({ maxInstances: 10 });

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Get user's league information with correct ranking
exports.getMyLeague = onCall({region: "asia-northeast3"}, async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new Error("Authentication required");
    }

    logger.info(`Getting league info for user: ${uid}`);

    // Find leagues where user is a member
    const leaguesSnapshot = await db.collection("leagues").get();
    
    for (const leagueDoc of leaguesSnapshot.docs) {
      const leagueId = leagueDoc.id;
      const leagueData = leagueDoc.data();
      
      // Check if user is member of this league
      const memberDoc = await db
        .collection("leagues")
        .doc(leagueId)
        .collection("members")
        .doc(uid)
        .get();
      
      if (memberDoc.exists) {
        // Get all members ordered by points (descending)
        const membersSnapshot = await db
          .collection("leagues")
          .doc(leagueId)
          .collection("members")
          .orderBy("point", "desc")
          .get();
        
        // Calculate actual rank and member count
        let rank = 1;
        let actualMemberCount = 0;
        
        membersSnapshot.docs.forEach((doc, index) => {
          const memberData = doc.data();
          // Only count valid members (with displayName)
          if (memberData.displayName && memberData.displayName.trim() !== "") {
            actualMemberCount++;
            if (doc.id === uid) {
              rank = actualMemberCount; // Use actual rank based on valid members
            }
          }
        });
        
        logger.info(`User found in league ${leagueId}, rank: ${rank}, members: ${actualMemberCount}`);
        
        return {
          leagueId: leagueId,
          league: {
            ...leagueData,
            memberCount: actualMemberCount // Use actual member count
          },
          rank: rank,
          memberCount: actualMemberCount
        };
      }
    }
    
    // User not in any league
    logger.info(`User ${uid} not found in any league`);
    return {
      leagueId: null,
      league: null,
      rank: null,
      memberCount: 0
    };
    
  } catch (error) {
    logger.error("Error getting league info:", error);
    throw new Error(`Failed to get league info: ${error.message}`);
  }
});

// Get user profile
exports.getMyProfile = onCall({region: "asia-northeast3"}, async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new Error("Authentication required");
    }

    // Return basic profile - can be extended later
    return {
      uid: uid,
      displayName: request.auth.token.name || "User",
      email: request.auth.token.email || "",
      totalPoints: 0,
      eduPoints: 0,
      jobPoints: 0,
      completedLessons: 0
    };
    
  } catch (error) {
    logger.error("Error getting profile:", error);
    throw new Error(`Failed to get profile: ${error.message}`);
  }
});

// Get user garden
exports.getMyGarden = onCall({region: "asia-northeast3"}, async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new Error("Authentication required");
    }

    logger.info(`Getting garden for user: ${uid}`);

    // Return basic garden structure - can be extended later
    return {
      size: 3,
      point: 100,
      tiles: {
        // Empty garden by default
        "0,0": { stage: 0 }, // 0 = empty
        "0,1": { stage: 0 },
        "0,2": { stage: 0 },
        "1,0": { stage: 0 },
        "1,1": { stage: 0 },
        "1,2": { stage: 0 },
        "2,0": { stage: 0 },
        "2,1": { stage: 0 },
        "2,2": { stage: 0 }
      }
    };
    
  } catch (error) {
    logger.error("Error getting garden:", error);
    throw new Error(`Failed to get garden: ${error.message}`);
  }
});

// Add points to user
exports.addPoints = onCall({region: "asia-northeast3"}, async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new Error("Authentication required");
    }

    const { amount } = request.data;
    if (!amount || typeof amount !== 'number' || amount <= 0) {
      throw new Error("Invalid amount");
    }

    logger.info(`Adding ${amount} points to user: ${uid}`);

    // For now, just return success - can be extended to update Firestore
    return {
      success: true,
      message: `Added ${amount} points successfully`,
      newBalance: amount // This would be the actual balance from database
    };
    
  } catch (error) {
    logger.error("Error adding points:", error);
    throw new Error(`Failed to add points: ${error.message}`);
  }
});

// Delete all posts (for debugging)
exports.deleteAllPosts = onCall({region: "asia-northeast3"}, async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new Error("Authentication required");
    }

    logger.info(`Deleting all posts requested by user: ${uid}`);

    // Get all posts
    const postsSnapshot = await db.collection("posts").get();
    
    // Delete all posts in batch
    const batch = db.batch();
    postsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    
    logger.info(`Deleted ${postsSnapshot.docs.length} posts`);

    return {
      success: true,
      message: `Deleted ${postsSnapshot.docs.length} posts successfully`,
      deletedCount: postsSnapshot.docs.length
    };
    
  } catch (error) {
    logger.error("Error deleting all posts:", error);
    throw new Error(`Failed to delete posts: ${error.message}`);
  }
});
