import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar.events',
  ],
  );

  // Sign in with Google
  Future<Map<String, dynamic>?> signInWithGoogle() async {
  try {
    await _googleSignIn.signOut(); 
    
    final googleUser = await _googleSignIn.signIn();

    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    return {
      'user': userCredential.user,
      'accessToken': googleAuth.accessToken,
    };
  } catch (e) {
    print("Google sign-in error: $e");
    return null;
  }
}

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Current user
  User? get currentUser => _auth.currentUser;
}