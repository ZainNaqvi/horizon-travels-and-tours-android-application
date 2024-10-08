// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import '../../exports.dart';

class DbHelper {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

// for the provider
  Future<UserCredentials> getUserDetails() async {
    User currentUser = _auth.currentUser!;

    DocumentSnapshot snapshot = await _firebaseFirestore.collection("user").doc(currentUser.uid).get().catchError(
          // ignore: body_might_complete_normally_catch_error
          (onError) {},
        );

    return UserCredentials.fromSnap(snapshot);
  }

  Future<String> createUser(
    BuildContext context, {
    required String name,
    required String imageUrl,
    required String email,
    required String password,
    required String role,
  }) async {
    String res = "Some error Occured";
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      UserCredentials userData = UserCredentials(role: role, email: email, uid: userCredential.user!.uid, name: name, imageUrl: imageUrl);
      // Sending - Email -  Verification
      await sendVerification(context);
      await _firebaseFirestore.collection("user").doc(userCredential.user!.uid).set(
            userData.toJson(),
          );
      res = "success";
    } on FirebaseAuthException catch (err) {
      if (err.code == 'weak-password') {
        showToast("The password provided is too weak.", context);
      } else if (err.code == 'email-already-in-use') {
        showToast("The account already exists for that email.", context);
      } else if (err.code == 'timeout') {
        showToast('The operation has timed out.', context);
      }
    }
    return res;
  }

  Future<String> sendVerification(BuildContext context) async {
    String res = "Some error occured";
    try {
      _auth.currentUser!.sendEmailVerification();
      showToast(
        "Account created successfully. A verification code has been sent to your email. Please verify your email to log in. Thank you.",
        context,
        toastGravity: ToastGravity.TOP,
      );

      res = "success";
    } on FirebaseException {
      showToast("Some error occured", context);
    }
    return res;
  }

  Future<String> userLogin(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    String res = "Some error occured.";
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (!_auth.currentUser!.emailVerified) {
        await _auth.currentUser!.sendEmailVerification();

        showToast("Please verify the email first.", context);
      } else {
        res = "success";
      }
    } on FirebaseAuthException catch (err) {
      if (err.code == 'user-not-found') {
        showToast("There is no user record corresponding to this identifier", context);
      } else if (err.code == "wrong-password") {
        showToast("Invalid Creaditials", context);
      } else if (err.code == 'timeout') {
        showToast('The operation has timed out.', context);
      } else {
        showToast(err.code, context);
      }
    } catch (err) {
      showToast("Some error occured", context);
    }
    return res;
  }

  Future<String> forgotPassword(BuildContext context, {required String email}) async {
    String res = "An error occurred";
    try {
      await _auth.sendPasswordResetEmail(email: email);
      showToast('A password reset email has been sent to your email address.', context);
      res = 'success';
    } on FirebaseException {
      showToast("An error occurred, please try again.", context);
    }
    return res;
  }

  Future<String> signInWithGoogle(BuildContext context) async {
    String res = "An error occurred";

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      UserCredentials userData = UserCredentials(
        role: 'user',
        email: userCredential.user?.email,
        uid: userCredential.user!.uid,
        name: userCredential.user!.displayName,
        imageUrl: userCredential.user!.photoURL ?? '',
      );

      await _firebaseFirestore.collection('user').doc(userCredential.user?.uid).set(userData.toJson());

      showToast("User signed in: ${userCredential.user?.email}", context);
      return 'success';
    } catch (error) {
      log("Error signing in: $error");
    }
    return res;
  }

  Future<String> createBooking({
    required String placeId,
    required String placeName,
    required String duration,
  }) async {
    String res = "Some error occurred";
    try {
      // Get current user ID
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return "User not logged in";
      }
      String userId = currentUser.uid;

      Booking booking = Booking(
        userId: userId,
        placeId: placeId,
        placeName: placeName,
        duration: duration,
        createdAt: DateTime.now(),
        status: 'Pending',
      );

      await _firebaseFirestore.collection("booking").add(booking.toJson());

      res = '''Your booking request has been sent to the admin. Our team will review your request and get back to you via your provided contact details (email or phone number). If the admin approves your booking, you will receive a notification.

You can cancel your booking request at any time. Thank you!''';
    } catch (e) {
      log("Error creating booking: $e");
      res = e.toString();
    }

    return res;
  }

  Future<List<Booking>> getUserBookingDetails() async {
    List<Booking> bookings = [];

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("User not logged in");
      }
      String userId = currentUser.uid;

      QuerySnapshot snapshot = await _firebaseFirestore.collection("booking").where("userId", isEqualTo: userId).get();

      for (var doc in snapshot.docs) {
        bookings.add(Booking.fromJson(doc.data() as Map<String, dynamic>));
      }
    } catch (e) {
      log("Error retrieving user bookings: $e");
    }

    return bookings;
  }

  Future<Place?> getPlaceById(String placeId) async {
    try {
      DocumentSnapshot snapshot = await _firebaseFirestore.collection("places").doc(placeId).get();

      if (snapshot.exists) {
        return Place.fromJson(snapshot.data() as Map<String, dynamic>);
      } else {
        log("Place with ID $placeId not found.");
      }
    } catch (e) {
      log("Error fetching place: $e");
    }
    return null;
  }

  Future<String> signOut() async {
    String res = "Some error Occured";
    try {
      await _auth.signOut();
      res = "success";
    } catch (e) {
      res = e.toString();
    }
    return res;
  }
}
