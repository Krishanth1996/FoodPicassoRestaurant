import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:foodie_restaurant/constants.dart';
import 'package:foodie_restaurant/services/helper.dart';
import 'package:foodie_restaurant/ui/container/ContainerScreen.dart';

class TermsAndCondition extends StatefulWidget {

  TermsAndCondition({Key? key,}) : super(key: key);

  @override
  State<TermsAndCondition> createState() => _TermsAndConditionState();
}

class _TermsAndConditionState extends State<TermsAndCondition> {
  String? termsAndCondition;

  @override
  void initState() {
    FirebaseFirestore.instance.collection(Setting).doc("termsAndConditions").get().then((value) {
      print(value['termsAndConditions']);
      setState(() {
        termsAndCondition = value['termsAndConditions'];
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode(context) ? Color(DARK_COLOR) : const Color(0XFFFDFEFE),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: termsAndCondition != null
              ? HtmlWidget(
                  // the first parameter (`html`) is required
                  '''
                  $termsAndCondition
                   ''',
                  onErrorBuilder: (context, element, error) => Text('$element error: $error'),
                  onLoadingBuilder: (context, element, loadingProgress) => const CircularProgressIndicator(),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
