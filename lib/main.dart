import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:foodie_restaurant/constants.dart';
import 'package:foodie_restaurant/model/User.dart';
import 'package:foodie_restaurant/model/VendorModel.dart';
import 'package:foodie_restaurant/services/FirebaseHelper.dart';
import 'package:foodie_restaurant/services/helper.dart';
import 'package:foodie_restaurant/ui/auth/AuthScreen.dart';
import 'package:foodie_restaurant/ui/container/ContainerScreen.dart';
import 'package:foodie_restaurant/ui/onBoarding/OnBoardingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  runApp(
    EasyLocalization(
        supportedLocales: [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: Locale('en'),
        useFallbackTranslations: true,
        saveLocale: false,
        useOnlyLangCode: true,
        child: MyApp()),
  );
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Future<void> setupInteractedMessage(BuildContext context) async {
    initialize(context);
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Message also contained a notification: ${initialMessage.notification!.body}');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message data 1 : ${message.data}');
        display(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('On message app');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        display(message);
      }
    });
  }

  Future<void> initialize(BuildContext context) async {
    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      importance: Importance.high,
    );

    await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  final audioPlayer = AudioPlayer(playerId: "playerId");

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      //user offline
      audioPlayer.dispose();
    } else if (state == AppLifecycleState.resumed) {

    }
  }

  void display(RemoteMessage message) async {
    print(message.notification!.title);
    print(message.notification!.body);
    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const NotificationDetails notificationDetails = NotificationDetails(
          android: AndroidNotificationDetails(
        "01",
        "foodie_restaurant",
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ));

      await FlutterLocalNotificationsPlugin().show(
        id,
        message.notification!.title,
        message.notification!.body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
  }

  static User? currentUser;
  late StreamSubscription tokenStream;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey(debugLabel: 'Main Navigator');

  // Set default `_initialized` and `_error` state to false
  bool _initialized = false, isColorLoad = false;
  bool _error = false, isDineIn = false;

  late VendorModel vendor;

  // Define an async function to initialize FlutterFire
  void initializeFlutterFire() async {
    try {
      FirebaseFirestore.instance.collection(Setting).doc("globalSettings").get().then((dineinresult) {
        if (dineinresult.exists && dineinresult.data() != null && dineinresult.data()!.containsKey("website_color")) {
          COLOR_PRIMARY = int.parse(dineinresult.data()!["website_color"].replaceFirst("#", "0xff"));

          setState(() {
            isColorLoad = true;
          });
        }
      });
      FirebaseFirestore.instance.collection(Setting).doc("DineinForRestaurant").get().then((dineinresult) {
        if (dineinresult.exists) {
          isDineInEnable = dineinresult.data()!["isEnabled"];
        }
      });

      await FirebaseFirestore.instance.collection(Setting).doc("googleMapKey").get().then((value) {
        print(value.data());
        GOOGLE_API_KEY = value.data()!['key'].toString();
      });


      /// database with it's new token
      tokenStream = FireStoreUtils.firebaseMessaging.onTokenRefresh.listen((event) {
        if (currentUser != null) {
          print('token========= $event');
          currentUser!.fcmToken = event;
          FireStoreUtils.updateCurrentUser(currentUser!);
          vendor.fcmToken = currentUser!.fcmToken;
          FireStoreUtils.updateVendor(vendor);
        }
      });

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      setState(() {
        _error = true;
        print(e.toString() + "==========ERROR");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if initialization failed
    if (_error) {
      return MaterialApp(
          home: Scaffold(
        body: Container(
          color: Colors.white,
          child: Center(
              child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 25,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to initialise firebase!'.tr(),
                style: TextStyle(color: Colors.red, fontSize: 25),
              ),
            ],
          )),
        ),
      ));
    }

    // Show a loader until FlutterFire is initialized
    if (!_initialized || !isColorLoad) {
      return Container(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      return MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          title: 'Restaurant Dashboard'.tr(),
          theme: ThemeData(
              appBarTheme: AppBarTheme(
                  centerTitle: true, color: Colors.transparent, elevation: 0, actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)), iconTheme: IconThemeData(color: Color(COLOR_PRIMARY))),
              bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.white),
              primaryColor: Color(COLOR_PRIMARY),
              brightness: Brightness.light),
          darkTheme: ThemeData(
              appBarTheme: AppBarTheme(
                centerTitle: true,
                color: Colors.transparent,
                elevation: 0,
                actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
              ),
              bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.grey.shade900),
              primaryColor: Color(COLOR_PRIMARY),
              brightness: Brightness.dark),
          debugShowCheckedModeBanner: false,
          color: Color(COLOR_PRIMARY),
          home: OnBoarding(isDineIn));
    }
  }

  @override
  void initState() {
    setupInteractedMessage(context);
    initializeFlutterFire();

    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    tokenStream.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ignore: must_be_immutable
class OnBoarding extends StatefulWidget {
  bool isDineIn;

  OnBoarding(this.isDineIn);

  @override
  State createState() {
    return OnBoardingState();
  }
}

class OnBoardingState extends State<OnBoarding> {
  Future hasFinishedOnBoarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool finishedOnBoarding = (prefs.getBool(FINISHED_ON_BOARDING) ?? false);
    print("click redirect");
    if (finishedOnBoarding) {
      auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        User? user = await FireStoreUtils.getCurrentUser(firebaseUser.uid);
        if (user != null && user.role == USER_ROLE_VENDOR) {
          if (user.active == true) {
            user.active = true;
            user.role = USER_ROLE_VENDOR;
            FireStoreUtils.firebaseMessaging.getToken().then((value) async {
              user.fcmToken = value!;
              await FireStoreUtils.firestore.collection(USERS).doc(user.userID).update({"fcmToken": user.fcmToken});
              // FireStoreUtils.updateCurrentUser(currentUser!);

              if (user.vendorID.isNotEmpty) {
                await FireStoreUtils.firestore.collection(VENDORS).doc(user.vendorID).update({"fcmToken": value});
              }
            });
            // await FireStoreUtils.updateCurrentUser(user);
            MyAppState.currentUser = user;
            pushReplacement(
                context,
                new ContainerScreen(
                  user: user,
                  isDineInReq: widget.isDineIn,
                ));
          } else {
            user.lastOnlineTimestamp = Timestamp.now();
            await FireStoreUtils.firestore.collection(USERS).doc(user.userID).update({"fcmToken": ""});
            if (user.vendorID.isNotEmpty) {
              await FireStoreUtils.firestore.collection(VENDORS).doc(user.vendorID).update({"fcmToken": ""});
            }
            // await FireStoreUtils.updateCurrentUser(user);
            await auth.FirebaseAuth.instance.signOut();
            await FacebookAuth.instance.logOut();
            MyAppState.currentUser = null;
            pushReplacement(context, new AuthScreen());
          }
        } else {
          pushReplacement(context, new AuthScreen());
        }
      } else {
        pushReplacement(context, new AuthScreen());
      }
    } else {
      pushReplacement(context, new OnBoardingScreen());
    }
  }

  @override
  void initState() {
    super.initState();
    hasFinishedOnBoarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
