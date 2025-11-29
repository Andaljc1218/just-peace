import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<String?> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String age,
    required String gender,
    required String contact,
  }) async {
    UserCredential? userCredential;
    
    // Step 1: Create Auth User
    try {
      print('🔵 Step 1: Creating Firebase Auth user for: $email');
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Step 1 SUCCESS: User created with UID: ${userCredential.user!.uid}');
    } on FirebaseAuthException catch (e) {
      print('❌ Step 1 FAILED: Auth error: ${e.code}');
      return _getErrorMessage(e.code);
    } catch (e) {
      print('❌ Step 1 FAILED: Unexpected error: $e');
      return 'Registration failed: $e';
    }

    // Step 2: Write to Firestore
    try {
      print('🔵 Step 2: Writing user data to Firestore...');
      
      final uid = userCredential.user!.uid;
      final userDoc = _firestore.collection('users').doc(uid);
      
      final userData = {
        'fullName': fullName,
        'email': email,
        'age': age,
        'gender': gender,
        'contact': contact,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      print('📦 Data to write: $userData');
      
      await userDoc.set(userData);
      
      print('✅ Step 2 SUCCESS: Firestore write completed');
      
      // Step 3: Verify
      print('🔵 Step 3: Verifying write...');
      final snapshot = await userDoc.get();
      
      if (snapshot.exists) {
        print('✅ Step 3 SUCCESS: Verified data exists: ${snapshot.data()}');
      } else {
        print('⚠️ Step 3 WARNING: Document not found after write');
      }
      
      return null; // Success
      
    } catch (e) {
      print('❌ Step 2/3 FAILED: Firestore error: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      // Delete the auth user if Firestore failed
      try {
        await userCredential.user?.delete();
        print('🗑️ Cleaned up auth user after Firestore failure');
      } catch (deleteError) {
        print('⚠️ Could not delete auth user: $deleteError');
      }
      
      return 'Failed to save user data: $e';
    }
  }

  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  Future<void> logoutUser() async {
    await _auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (currentUser == null) {
        print('❌ getUserData: No user logged in');
        return null;
      }

      print('🔵 getUserData: Fetching for UID: ${currentUser!.uid}');

      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        print('✅ getUserData: Found data: ${doc.data()}');
        return doc.data();
      } else {
        print('⚠️ getUserData: No document found');
        return null;
      }
    } catch (e) {
      print('❌ getUserData: Error: $e');
      return null;
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}