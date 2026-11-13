import 'dart:ui';

import 'package:flutter/material.dart';

/// App languages. Add one by adding a column to [_t] and an entry here.
const appLanguages = [
  (code: 'en', name: 'English', native: 'English'),
  (code: 'hi', name: 'Hindi', native: 'हिन्दी'),
  (code: 'te', name: 'Telugu', native: 'తెలుగు'),
];

/// The current language. Changing it redraws every screen in place.
final appLang = ValueNotifier<String>(_deviceDefault());

String _deviceDefault() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return appLanguages.any((l) => l.code == code) ? code : 'en';
}

/// Translate [key]; `{name}` placeholders are filled from [args]. Falls back to English.
String tr(String key, [Map<String, Object> args = const {}]) {
  var s = _t[key]?[appLang.value] ?? _t[key]?['en'] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Marks every widget dirty so text built with [tr] is redrawn without losing navigation.
void rebuildAll(BuildContext context) {
  void walk(Element e) {
    e.markNeedsBuild();
    e.visitChildren(walk);
  }

  (context as Element).visitChildren(walk);
}

const _t = <String, Map<String, String>>{
  // Language
  'lang.title': {'en': 'Language', 'hi': 'भाषा', 'te': 'భాష'},
  'lang.choose': {
    'en': 'Choose your language',
    'hi': 'अपनी भाषा चुनें',
    'te': 'మీ భాషను ఎంచుకోండి',
  },
  'lang.note': {
    'en': 'Names and details in the guide appear as the organisers wrote them.',
    'hi': 'मार्गदर्शिका में नाम और विवरण आयोजकों द्वारा लिखे अनुसार दिखते हैं।',
    'te': 'మార్గదర్శిలోని పేర్లు, వివరాలు నిర్వాహకులు రాసినట్లే కనిపిస్తాయి.',
  },

  // Sign in
  'signin.title': {'en': 'Sign in', 'hi': 'साइन इन करें', 'te': 'సైన్ ఇన్'},
  'signin.desc': {
    'en': 'Use your mobile number. New here? You can apply for membership after verifying.',
    'hi': 'अपने मोबाइल नंबर से साइन इन करें। नए हैं? सत्यापन के बाद सदस्यता के लिए आवेदन कर सकते हैं।',
    'te': 'మీ మొబైల్ నంబర్‌తో సైన్ ఇన్ చేయండి. కొత్తవారా? ధృవీకరణ తర్వాత సభ్యత్వానికి దరఖాస్తు చేయవచ్చు.',
  },
  'signin.mobile': {
    'en': 'Mobile number',
    'hi': 'मोबाइल नंबर',
    'te': 'మొబైల్ నంబర్',
  },
  'signin.send': {'en': 'Send code', 'hi': 'कोड भेजें', 'te': 'కోడ్ పంపండి'},
  'signin.sending': {
    'en': 'Sending…',
    'hi': 'भेज रहे हैं…',
    'te': 'పంపుతున్నాం…',
  },
  'signin.or': {'en': 'or', 'hi': 'या', 'te': 'లేదా'},
  'signin.google': {
    'en': 'Continue with Google',
    'hi': 'Google से जारी रखें',
    'te': 'Googleతో కొనసాగించండి',
  },
  'signin.nopass': {
    'en': 'No passwords. A 6-digit code is sent by SMS each time.',
    'hi': 'कोई पासवर्ड नहीं। हर बार SMS से 6 अंकों का कोड आता है।',
    'te': 'పాస్‌వర్డ్ అవసరం లేదు. ప్రతిసారీ SMS ద్వారా 6 అంకెల కోడ్ వస్తుంది.',
  },
  'signin.enter': {
    'en': 'Enter the code',
    'hi': 'कोड डालें',
    'te': 'కోడ్ నమోదు చేయండి',
  },
  'signin.sentTo': {
    'en': 'Sent to {to}',
    'hi': '{to} पर भेजा गया',
    'te': '{to}కి పంపాం',
  },
  'signin.verify': {
    'en': 'Verify and continue',
    'hi': 'सत्यापित करें और आगे बढ़ें',
    'te': 'ధృవీకరించి కొనసాగండి',
  },
  'signin.checking': {
    'en': 'Checking…',
    'hi': 'जाँच रहे हैं…',
    'te': 'తనిఖీ చేస్తున్నాం…',
  },
  'signin.other': {
    'en': 'Use a different number',
    'hi': 'दूसरा नंबर इस्तेमाल करें',
    'te': 'వేరే నంబర్ వాడండి',
  },
  'signin.googleLink': {
    'en': 'Google account {email} is new here. Verify your mobile number once to link it. Next time Google signs you straight in.',
    'hi': 'Google खाता {email} यहाँ नया है। इसे जोड़ने के लिए एक बार अपना मोबाइल नंबर सत्यापित करें। अगली बार Google से सीधे साइन इन होगा।',
    'te': 'Google ఖాతా {email} ఇక్కడ కొత్తది. దాన్ని జోడించడానికి ఒకసారి మీ మొబైల్ నంబర్‌ను ధృవీకరించండి. తర్వాతిసారి Googleతో నేరుగా సైన్ ఇన్ అవుతారు.',
  },

  // Navigation
  'nav.home': {'en': 'Home', 'hi': 'होम', 'te': 'హోమ్'},
  'nav.community': {'en': 'Community', 'hi': 'समुदाय', 'te': 'కమ్యూనిటీ'},
  'nav.pass': {'en': 'Pass', 'hi': 'पास', 'te': 'పాస్'},
  'nav.calendar': {'en': 'Calendar', 'hi': 'कैलेंडर', 'te': 'క్యాలెండర్'},
  'nav.me': {'en': 'Me', 'hi': 'मैं', 'te': 'నేను'},

  // Home
  'home.morning': {'en': 'Good morning', 'hi': 'सुप्रभात', 'te': 'శుభోదయం'},
  'home.afternoon': {
    'en': 'Good afternoon',
    'hi': 'नमस्कार',
    'te': 'శుభ మధ్యాహ్నం',
  },
  'home.evening': {
    'en': 'Good evening',
    'hi': 'शुभ संध्या',
    'te': 'శుభ సాయంత్రం',
  },
  'home.search': {
    'en': 'Find karyakartas, colleges…',
    'hi': 'कार्यकर्ता, कॉलेज खोजें…',
    'te': 'కార్యకర్తలు, కళాశాలలు వెతకండి…',
  },
  'home.forYou': {'en': 'For you', 'hi': 'आपके लिए', 'te': 'మీ కోసం'},
  'home.vibhags': {'en': 'Vibhags', 'hi': 'विभाग', 'te': 'విభాగాలు'},
  'home.circulars': {'en': 'Circulars', 'hi': 'परिपत्र', 'te': 'సర్క్యులర్లు'},
  'home.report': {
    'en': 'Report activity',
    'hi': 'गतिविधि भेजें',
    'te': 'కార్యక్రమం నివేదించండి',
  },
  'home.upcoming': {
    'en': 'Upcoming events',
    'hi': 'आने वाले कार्यक्रम',
    'te': 'రాబోయే కార్యక్రమాలు',
  },
  'home.seeAll': {'en': 'See all', 'hi': 'सभी देखें', 'te': 'అన్నీ చూడండి'},
  'home.nextUp': {'en': 'Next up', 'hi': 'अगला', 'te': 'తదుపరి'},
  'home.myCard': {'en': 'My card', 'hi': 'मेरा कार्ड', 'te': 'నా కార్డ్'},
  'home.dayitva': {'en': 'Dayitva', 'hi': 'दायित्व', 'te': 'బాధ్యతలు'},

  // Guide
  'guide.title': {
    'en': 'Conference guide',
    'hi': 'अधिवेशन मार्गदर्शिका',
    'te': 'సమావేశ మార్గదర్శి',
  },
  'guide.helpline': {'en': 'Helpline', 'hi': 'हेल्पलाइन', 'te': 'హెల్ప్‌లైన్'},
  'guide.skip': {'en': 'Skip', 'hi': 'छोड़ें', 'te': 'దాటవేయండి'},
  'guide.continue': {
    'en': 'Continue to app',
    'hi': 'ऐप पर जाएँ',
    'te': 'యాప్‌కి వెళ్ళండి',
  },
  'guide.everything': {
    'en': 'Everything you need',
    'hi': 'आपको जो चाहिए',
    'te': 'మీకు కావలసినవన్నీ',
  },
  'guide.whereStay': {
    'en': 'Where am I staying?',
    'hi': 'मैं कहाँ ठहरूँगा?',
    'te': 'నేను ఎక్కడ బస చేస్తాను?',
  },
  'guide.pickPrant': {
    'en': 'Pick your prant to see your stay and its lead',
    'hi': 'अपना प्रांत चुनें – निवास और प्रमुख देखें',
    'te': 'మీ ప్రాంతాన్ని ఎంచుకోండి – బస, బాధ్యులను చూడండి',
  },
  'guide.yourStay': {'en': 'YOUR STAY', 'hi': 'आपका निवास', 'te': 'మీ బస'},
  'guide.lead': {
    'en': 'Lead: {name}',
    'hi': 'प्रमुख: {name}',
    'te': 'బాధ్యులు: {name}',
  },
  'guide.bannerSub': {
    'en': 'Stay · transport · food · help, all in one place',
    'hi': 'निवास · यातायात · भोजन · सहायता, सब एक जगह',
    'te': 'బస · రవాణా · భోజనం · సహాయం, అన్నీ ఒకేచోట',
  },
  'guide.live': {
    'en': 'Day {n} · Live now',
    'hi': 'दिन {n} · अभी चल रहा है',
    'te': 'రోజు {n} · ఇప్పుడు జరుగుతోంది',
  },
  'guide.today': {'en': 'Today', 'hi': 'आज', 'te': 'ఈరోజు'},
  'guide.tomorrow': {'en': 'Tomorrow', 'hi': 'कल', 'te': 'రేపు'},
  'guide.inDays': {
    'en': 'in {n} days',
    'hi': '{n} दिन में',
    'te': '{n} రోజుల్లో',
  },

  'kind.stay': {'en': 'Accommodation', 'hi': 'निवास', 'te': 'బస'},
  'kind.arrival': {'en': 'Transport', 'hi': 'यातायात', 'te': 'రవాణా'},
  'kind.food': {'en': 'Food', 'hi': 'भोजन', 'te': 'భోజనం'},
  'kind.office': {'en': 'Offices', 'hi': 'कार्यालय', 'te': 'కార్యాలయాలు'},
  'kind.session': {'en': 'Sessions', 'hi': 'बैठक', 'te': 'సమావేశాలు'},
  'kind.exhibit': {'en': 'Exhibition', 'hi': 'प्रदर्शनी', 'te': 'ప్రదర్శన'},
  'kind.facility': {'en': 'Campus', 'hi': 'परिसर', 'te': 'ప్రాంగణం'},
  'kind.tourist': {
    'en': 'Tourist places',
    'hi': 'पर्यटन',
    'te': 'పర్యాటక ప్రదేశాలు',
  },
  'kind.emergency': {'en': 'Emergency', 'hi': 'आपातकाल', 'te': 'అత్యవసరం'},
  'kind.support': {'en': 'Support', 'hi': 'सहायता', 'te': 'సహాయం'},

  // Section screens
  'sec.places': {'en': '{n} places', 'hi': '{n} स्थान', 'te': '{n} ప్రదేశాలు'},
  'sec.prantsPlaces': {
    'en': '{p} prants · {n} places',
    'hi': '{p} प्रांत · {n} स्थान',
    'te': '{p} ప్రాంతాలు · {n} ప్రదేశాలు',
  },
  'sec.searchPrant': {
    'en': 'Search your prant: Delhi, Konkan, Kerala…',
    'hi': 'अपना प्रांत खोजें: दिल्ली, कोंकण, केरल…',
    'te': 'మీ ప్రాంతాన్ని వెతకండి: ఢిల్లీ, కొంకణ్, కేరళ…',
  },
  'sec.yourPrant': {
    'en': 'Your prant',
    'hi': 'आपका प्रांत',
    'te': 'మీ ప్రాంతం',
  },
  'sec.justArrived': {
    'en': 'Just arrived?',
    'hi': 'अभी पहुँचे?',
    'te': 'ఇప్పుడే చేరుకున్నారా?',
  },
  'sec.findNearest': {
    'en': 'Find the desk nearest to me',
    'hi': 'मेरे सबसे पास का डेस्क खोजें',
    'te': 'నాకు దగ్గరలోని డెస్క్ చూపించు',
  },
  'sec.nearestDesk': {
    'en': 'Nearest help desk',
    'hi': 'सबसे पास का सहायता डेस्क',
    'te': 'దగ్గరలోని సహాయ డెస్క్',
  },
  'sec.kmAway': {
    'en': '{km} km away',
    'hi': '{km} किमी दूर',
    'te': '{km} కి.మీ. దూరం',
  },
  'sec.nearestToYou': {
    'en': 'Nearest to you',
    'hi': 'आपके सबसे पास',
    'te': 'మీకు దగ్గరగా',
  },
  'sec.fromYou': {'en': 'from you', 'hi': 'आपसे', 'te': 'మీ నుండి'},
  'sec.lookFor': {
    'en': 'Look for: {x}',
    'hi': 'पहचान: {x}',
    'te': 'గుర్తు: {x}',
  },
  'sec.all': {'en': 'All', 'hi': 'सभी', 'te': 'అన్నీ'},
  'sec.kmToVenue': {
    'en': '{km} km to venue',
    'hi': 'स्थल तक {km} किमी',
    'te': 'వేదికకు {km} కి.మీ.',
  },
  'sec.empty': {
    'en': 'Nothing here yet. Pull down to refresh, or call the helpline.',
    'hi':
        'अभी यहाँ कुछ नहीं। नीचे खींचकर ताज़ा करें, या हेल्पलाइन पर कॉल करें।',
    'te': 'ఇక్కడ ఇంకా ఏమీ లేదు. కిందకు లాగి రిఫ్రెష్ చేయండి, లేదా హెల్ప్‌లైన్‌కు కాల్ చేయండి.',
  },
  'sec.locFail': {
    'en': 'Could not get your location. Allow location, or pick your station below.',
    'hi': 'आपकी लोकेशन नहीं मिली। लोकेशन की अनुमति दें, या नीचे अपना स्टेशन चुनें।',
    'te': 'మీ లొకేషన్ దొరకలేదు. లొకేషన్ అనుమతి ఇవ్వండి, లేదా కింద మీ స్టేషన్ ఎంచుకోండి.',
  },

  // Emergency
  'em.numbers': {
    'en': 'Emergency numbers',
    'hi': 'आपातकालीन नंबर',
    'te': 'అత్యవసర నంబర్లు',
  },
  'em.tapToCall': {
    'en': 'Tap to call. Then tell the nearest volunteer.',
    'hi': 'कॉल करने के लिए दबाएँ। फिर नज़दीकी स्वयंसेवक को बताएँ।',
    'te': 'కాల్ చేయడానికి నొక్కండి. తర్వాత దగ్గరలోని వాలంటీర్‌కు చెప్పండి.',
  },
  'em.byHall': {
    'en': 'Emergency leads by hall',
    'hi': 'हॉल के अनुसार आपातकालीन प्रमुख',
    'te': 'హాల్ వారీగా అత్యవసర బాధ్యులు',
  },
  'em.byHallSub': {
    'en': 'Go to the nearest one or call them – they know where the doctor and ambulance are.',
    'hi': 'सबसे पास वाले के पास जाएँ या कॉल करें – उन्हें पता है डॉक्टर और एम्बुलेंस कहाँ हैं।',
    'te': 'దగ్గరలోని వారి దగ్గరికి వెళ్ళండి లేదా కాల్ చేయండి – డాక్టర్, అంబులెన్స్ ఎక్కడ ఉన్నాయో వారికి తెలుసు.',
  },
  'em.call': {
    'en': 'Call {n}',
    'hi': '{n} पर कॉल करें',
    'te': '{n}కి కాల్ చేయండి',
  },

  // Detail
  'd.where': {'en': 'Where', 'hi': 'कहाँ', 'te': 'ఎక్కడ'},
  'd.lookFor': {'en': 'Look for', 'hi': 'पहचान', 'te': 'గుర్తు'},
  'd.note': {'en': 'Note', 'hi': 'ध्यान दें', 'te': 'గమనిక'},
  'd.timings': {'en': 'Timings', 'hi': 'समय', 'te': 'సమయం'},
  'd.toVenue': {'en': 'To the venue', 'hi': 'स्थल तक', 'te': 'వేదికకు'},
  'd.fromVenue': {'en': 'From the venue', 'hi': 'स्थल से', 'te': 'వేదిక నుండి'},
  'd.straight': {
    'en': '(straight line)',
    'hi': '(सीधी दूरी)',
    'te': '(సరళ రేఖ దూరం)',
  },
  'd.route': {
    'en': 'Route to venue',
    'hi': 'स्थल तक का रास्ता',
    'te': 'వేదికకు దారి',
  },
  'd.directions': {
    'en': 'Directions',
    'hi': 'रास्ता देखें',
    'te': 'దారి చూపించు',
  },
  'd.about': {'en': 'About', 'hi': 'जानकारी', 'te': 'వివరాలు'},
  'd.howVenue': {
    'en': 'How to reach the venue',
    'hi': 'स्थल तक कैसे पहुँचें',
    'te': 'వేదికకు ఎలా చేరాలి',
  },
  'd.howThere': {
    'en': 'How to get there',
    'hi': 'वहाँ कैसे पहुँचें',
    'te': 'అక్కడికి ఎలా వెళ్ళాలి',
  },
  'd.contact': {
    'en': 'Who to contact',
    'hi': 'किससे संपर्क करें',
    'te': 'ఎవరిని సంప్రదించాలి',
  },
  'd.leads': {
    'en': 'Lead members',
    'hi': 'प्रमुख कार्यकर्ता',
    'te': 'బాధ్యులు',
  },
  'd.lead': {'en': 'Lead', 'hi': 'प्रमुख', 'te': 'బాధ్యులు'},
  'd.call': {'en': 'Call', 'hi': 'कॉल करें', 'te': 'కాల్ చేయండి'},

  // Support
  'support.cardOpen': {
    'en': '{n} open · chat or check replies',
    'hi': '{n} खुले · चैट करें या जवाब देखें',
    'te': '{n} తెరిచి ఉన్నాయి · చాట్ చేయండి లేదా జవాబులు చూడండి',
  },
  'support.cardNone': {
    'en': 'Chat with the help desk or raise a ticket',
    'hi': 'हेल्प डेस्क से चैट करें या टिकट दर्ज करें',
    'te': 'హెల్ప్ డెస్క్‌తో చాట్ చేయండి లేదా టికెట్ నమోదు చేయండి',
  },
  'support.needHelp': {
    'en': 'Need help?',
    'hi': 'मदद चाहिए?',
    'te': 'సహాయం కావాలా?',
  },
  'support.signedOut': {
    'en': 'Call the helpline now, or sign in with your mobile number to chat with the help desk.',
    'hi': 'अभी हेल्पलाइन पर कॉल करें, या हेल्प डेस्क से चैट के लिए मोबाइल नंबर से साइन इन करें।',
    'te': 'ఇప్పుడే హెల్ప్‌లైన్‌కు కాల్ చేయండి, లేదా హెల్ప్ డెస్క్‌తో చాట్ చేయడానికి మొబైల్ నంబర్‌తో సైన్ ఇన్ చేయండి.',
  },
  'support.callHelpline': {
    'en': 'Call helpline {n}',
    'hi': 'हेल्पलाइन पर कॉल करें {n}',
    'te': 'హెల్ప్‌లైన్‌కు కాల్ చేయండి {n}',
  },
  'support.signIn': {
    'en': 'Sign in to chat',
    'hi': 'चैट के लिए साइन इन करें',
    'te': 'చాట్ కోసం సైన్ ఇన్ చేయండి',
  },
  'support.chat': {
    'en': 'Chat with the help desk',
    'hi': 'हेल्प डेस्क से चैट करें',
    'te': 'హెల్ప్ డెస్క్‌తో చాట్',
  },
  'support.chatSub': {
    'en': 'Quick questions – a volunteer replies here',
    'hi': 'छोटे सवाल – स्वयंसेवक यहीं जवाब देंगे',
    'te': 'చిన్న ప్రశ్నలు – వాలంటీర్ ఇక్కడే జవాబిస్తారు',
  },
  'support.ticket': {
    'en': 'Raise a ticket',
    'hi': 'टिकट दर्ज करें',
    'te': 'టికెట్ నమోదు చేయండి',
  },
  'support.ticketSub': {
    'en': 'Stay, food, transport, lost and found, medical',
    'hi': 'निवास, भोजन, यातायात, खोया-पाया, चिकित्सा',
    'te': 'బస, భోజనం, రవాణా, పోయినవి-దొరికినవి, వైద్యం',
  },
  'support.mine': {
    'en': 'My conversations',
    'hi': 'मेरी बातचीत',
    'te': 'నా సంభాషణలు',
  },
  'support.none': {
    'en': 'No conversations yet. Start a chat – the help desk is here for you.',
    'hi': 'अभी कोई बातचीत नहीं। चैट शुरू करें – हेल्प डेस्क आपके लिए है।',
    'te':
        'ఇంకా సంభాషణలు లేవు. చాట్ ప్రారంభించండి – హెల్ప్ డెస్క్ మీ కోసం ఉంది.',
  },
  'support.typeMsg': {
    'en': 'Type a message',
    'hi': 'संदेश लिखें',
    'te': 'సందేశం టైప్ చేయండి',
  },
  'support.send': {'en': 'Send', 'hi': 'भेजें', 'te': 'పంపండి'},
  'support.desk': {
    'en': 'Help desk',
    'hi': 'हेल्प डेस्क',
    'te': 'హెల్ప్ డెస్క్',
  },
  'support.you': {'en': 'You', 'hi': 'आप', 'te': 'మీరు'},
  'support.startHint': {
    'en': 'Ask anything – which bus, where is my block, I lost something…',
    'hi': 'कुछ भी पूछें – कौन सी बस, मेरा ब्लॉक कहाँ है, कुछ खो गया…',
    'te': 'ఏదైనా అడగండి – ఏ బస్సు, నా బ్లాక్ ఎక్కడ, ఏదైనా పోయింది…',
  },
  'support.waiting': {
    'en': 'Sent. A volunteer will reply here soon.',
    'hi': 'भेज दिया। स्वयंसेवक जल्द यहीं जवाब देंगे।',
    'te': 'పంపాం. వాలంటీర్ త్వరలో ఇక్కడే జవాబిస్తారు.',
  },
  'support.what': {
    'en': 'What do you need?',
    'hi': 'आपको क्या चाहिए?',
    'te': 'మీకు ఏమి కావాలి?',
  },
  'support.where': {
    'en': 'Where are you? (optional)',
    'hi': 'आप कहाँ हैं? (वैकल्पिक)',
    'te': 'మీరు ఎక్కడ ఉన్నారు? (ఐచ్ఛికం)',
  },
  'support.submit': {
    'en': 'Send to the help desk',
    'hi': 'हेल्प डेस्क को भेजें',
    'te': 'హెల్ప్ డెస్క్‌కి పంపండి',
  },
  'support.medical': {
    'en': 'For a medical emergency call 108 now. This also alerts the event team.',
    'hi': 'चिकित्सा आपात स्थिति में अभी 108 पर कॉल करें। इससे कार्यक्रम टीम को भी सूचना जाती है।',
    'te': 'వైద్య అత్యవసరమైతే వెంటనే 108కి కాల్ చేయండి. ఇది కార్యక్రమ బృందానికి కూడా తెలియజేస్తుంది.',
  },
  'support.status.open': {'en': 'New', 'hi': 'नया', 'te': 'కొత్తది'},
  'support.status.in_progress': {
    'en': 'Being handled',
    'hi': 'देखा जा रहा है',
    'te': 'పరిశీలనలో ఉంది',
  },
  'support.status.resolved': {
    'en': 'Resolved',
    'hi': 'हल हो गया',
    'te': 'పరిష్కరించబడింది',
  },
  'support.status.closed': {'en': 'Closed', 'hi': 'बंद', 'te': 'ముగిసింది'},
  'cat.chat': {'en': 'Chat', 'hi': 'चैट', 'te': 'చాట్'},
  'cat.medical': {'en': 'Medical', 'hi': 'चिकित्सा', 'te': 'వైద్యం'},
  'cat.registration': {
    'en': 'Registration or pass',
    'hi': 'पंजीकरण या पास',
    'te': 'నమోదు లేదా పాస్',
  },
  'cat.stay': {'en': 'Stay', 'hi': 'निवास', 'te': 'బస'},
  'cat.food': {'en': 'Food', 'hi': 'भोजन', 'te': 'భోజనం'},
  'cat.transport': {'en': 'Transport', 'hi': 'यातायात', 'te': 'రవాణా'},
  'cat.venue': {
    'en': 'Venue or directions',
    'hi': 'स्थान या रास्ता',
    'te': 'వేదిక లేదా దారి',
  },
  'cat.lost': {
    'en': 'Lost and found',
    'hi': 'खोया-पाया',
    'te': 'పోయినవి-దొరికినవి',
  },
  'cat.other': {'en': 'Something else', 'hi': 'कुछ और', 'te': 'ఇంకేదైనా'},
};

/// Root of the app, so a language change can redraw everything.
final appRootKey = GlobalKey();

/// Bottom sheet listing each language in its own script.
Future<void> showLanguagePicker(
  BuildContext context, {
  required Future<void> Function(String code) save,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('lang.choose'),
              style: const TextStyle(
                fontFamily: 'Anek',
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            for (final l in appLanguages)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: appLang.value == l.code
                      ? const Color(0xFFFFEFE2)
                      : const Color(0xFFF1F2F5),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      appLang.value = l.code;
                      Navigator.pop(ctx);
                      final root = appRootKey.currentContext;
                      if (root != null) rebuildAll(root);
                      save(l.code);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.native,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  l.name,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7080),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (appLang.value == l.code)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFFE3620C),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Text(
              tr('lang.note'),
              style: const TextStyle(color: Color(0xFF6B7080), fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Small globe pill that opens the picker: "EN", "हि", "తె".
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, required this.save, this.light = false});
  final Future<void> Function(String code) save;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final short = {'en': 'EN', 'hi': 'हि', 'te': 'తె'}[appLang.value] ?? 'EN';
    return Tooltip(
      message: tr('lang.title'),
      child: Material(
        color: light ? Colors.white.withValues(alpha: 0.18) : Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showLanguagePicker(context, save: save),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 18,
                  color: light ? Colors.white : const Color(0xFF14161F),
                ),
                const SizedBox(width: 6),
                Text(
                  short,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: light ? Colors.white : const Color(0xFF14161F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keys missing a language: used by the tests so no screen shows half-translated text.
List<String> missingTranslations() => [
  for (final e in _t.entries)
    for (final l in appLanguages)
      if ((e.value[l.code] ?? '').isEmpty) '${e.key}:${l.code}',
];
