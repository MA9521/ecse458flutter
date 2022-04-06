import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((value) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anesthesia GHG calculator',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  int _selectedBarIndex = 0;
  String _administrationTypeValue = '';
  String _propofolVolumeField = '';
  String _durationProcedureField = '';
  String _primaryGasTypeValue = 'sevo';
  String _primaryGasMAChField = '';
  //String _primaryGasFlowField = '';
  //String _nitrousOxideFlowField = '';
  String _syringeNumbersField = '';
  String _patientWeightField = '';
  final String _emptyResult = '\n\n\n\n';
  String _result = '\n\n\n\n';
  final TextEditingController _propofolVolumeController =
      TextEditingController(text: '');
  final TextEditingController _durationProcedureController =
      TextEditingController(text: '');
  // final TextEditingController _primaryGasFlowController =
  //     TextEditingController(text: '');
  // final TextEditingController _nitrousOxideFlowController =
  //     TextEditingController(text: '');
  final TextEditingController _primaryGasMAChController =
      TextEditingController(text: '');
  final TextEditingController _syringeNumbersController =
      TextEditingController(text: '');
  final TextEditingController _patientWeightController =
      TextEditingController(text: '');
  final TextStyle _textStyle = const TextStyle(fontSize: 18);
  double _distanceTravelled = 0.0;
  double _screenWidth = 0.0;
  double _animationWidth = 0.0;

  final Map _gases = {
    'sevo': ['Sevoflurane', 49.3115],
    'iso': ['Isoflurane', 23.0553],
    'desf': ['Desflurane', 37.6502]
  };

  bool _isZeroOrPositive(String str) {
    return double.tryParse(str)! >= 0;
  }

  void _clearResult() {
    if (_result != _emptyResult || _animationWidth != 0.0) {
      setState(() {
        _animationWidth = 0.0;
        _result = _emptyResult;
      });
    }
  }

  List neededBottlesAndWaste(double volumeNeeded) {
    int ceilVolume = (volumeNeeded / 10.0).ceil() * 10; //mutiple of 10
    int mL20 = 0;
    int mL50 = 0;
    int mL100 = 0;

    if (ceilVolume == 10) {
      mL20 = 1;
    } else if (ceilVolume == 30) {
      mL20 = 2;
    } else {
      int modulo100 = ceilVolume % 100;
      if (modulo100 == 10 ||
          modulo100 == 30 ||
          modulo100 == 50 ||
          modulo100 == 70 ||
          modulo100 == 90) {
        mL50 = 1;
        mL100 = ((ceilVolume - 50) / 100).floor();
        mL20 = ((ceilVolume - 50 - 100 * mL100) / 20).ceil();
      } else {
        mL100 = (ceilVolume / 100).floor();
        mL20 = ((ceilVolume - 100 * mL100) / 20).ceil();
      }
    }

    return [
      mL20,
      mL50,
      mL100,
      (20 * mL20 + 50 * mL50 + 100 * mL100).toDouble() - volumeNeeded
    ];
  }

  // return in kgco2eq .... volume in mL .... duration in minutes
  double getPropofolImpact(double volume,
      {bool isUsed = false, double duration = 0.0, int nbSyringes = 0}) {
    // LCA assesment minus electricty minus syringe..... 1MAC-h for 70 kg patient is 60 mL
    double ghgImpact = 0.00543166666 * volume + 0.6795 * nbSyringes;
    // https://wilburnmedicalusa.com/content/pdf/ABC-4100_General_Specifications_Sheet.pdf
    // 60*13.8*0.412/3600000.0 = .... convert to seconds, wattage , impact of natural gas electricity
    ghgImpact = isUsed ? ghgImpact + duration * 0.00009476 : ghgImpact;
    return ghgImpact;
  }

  double getGasImpact(
      String primaryGasTypeValue, double primaryGasMACh, double patientWeight) {
    return _gases[primaryGasTypeValue][1] *
        primaryGasMACh *
        patientWeight /
        70.0;
  }

  double convertKgCO2ToKmDriven(double ghgImpact) {
    return 5.57413600892 * ghgImpact;
  }

  void _onPressedCompute() {
    if (_administrationTypeValue == 'iv' &&
        _isZeroOrPositive(_durationProcedureField) &&
        _isZeroOrPositive(_propofolVolumeField) &&
        int.tryParse(_syringeNumbersField)! >= 0) {
      double propofolNeeded = double.tryParse(_propofolVolumeField)!;
      int syringesNumber = int.tryParse(_syringeNumbersField)!;
      List needBottlesAndWaste = neededBottlesAndWaste(propofolNeeded);
      int mL20 = needBottlesAndWaste[0];
      int mL50 = needBottlesAndWaste[1];
      int mL100 = needBottlesAndWaste[2];
      double propofolWasted = needBottlesAndWaste[3];

      double ghgUsed = getPropofolImpact(
        propofolNeeded,
        isUsed: true,
        duration: double.tryParse(_durationProcedureField)!,
        nbSyringes: syringesNumber,
      );

      double ghgWasted = getPropofolImpact(propofolWasted);
      double totalGhg = ghgUsed + ghgWasted;

      _distanceTravelled = convertKgCO2ToKmDriven(totalGhg);

      String neededBottlesSentence = '';
      if (mL20 != 0 || mL50 != 0 || mL100 != 0) {
        neededBottlesSentence =
            '\nYou will need aa$mL20*20mL vials, aa$mL50*50mL vials, aa$mL100*100mL vials, '
                .replaceAll(RegExp(r'aa0\*\d*mL vials, '), '')
                .replaceAll('aa', '');
        neededBottlesSentence = neededBottlesSentence.substring(
                0, neededBottlesSentence.lastIndexOf(', ')) +
            '.';
      }

      String neededPropofolSentence = _distanceTravelled != 0
          ? '\nThe $propofolNeeded mL of propofol used in $syringesNumber syringes are responsible for ${ghgUsed.toStringAsFixed(3)} kg CO\u2082-eq.'
          : '';

      String wastedPropofolSentence = propofolWasted != 0
          ? '\nThe $propofolWasted mL of propofol wasted are responsible for ${ghgWasted.toStringAsFixed(3)} kg CO\u2082-eq.'
          : '';
      String totalPropofolSentence = propofolWasted != 0
          ? '\nThe total propofol (${propofolNeeded + propofolWasted} mL) and $syringesNumber syringes are responsible for ${totalGhg.toStringAsFixed(3)} kg CO\u2082-eq.'
          : '';
      String drivenSentence = _distanceTravelled != 0
          ? ' This is equivalent to driving a gasoline car for ${_distanceTravelled.toStringAsFixed(3)} km.'
          : '';
      setState(() {
        _animationWidth = 2 * _screenWidth / 3 - 45;
        _result = neededBottlesSentence +
            neededPropofolSentence +
            wastedPropofolSentence +
            totalPropofolSentence +
            drivenSentence;
      });
    }
    if (_administrationTypeValue == 'inhale' &&
        _isZeroOrPositive(_primaryGasMAChField) &&
        _isZeroOrPositive(_patientWeightField)) {
      double ghgImpact = getGasImpact(
          _primaryGasTypeValue,
          double.tryParse(_primaryGasMAChField)!,
          double.tryParse(_patientWeightField)!);
      _distanceTravelled = convertKgCO2ToKmDriven(ghgImpact);
      setState(() {
        _animationWidth = 2 * _screenWidth / 3 - 45;
        _result = _distanceTravelled == 0
            ? ''
            : '\nThe  $_primaryGasMAChField MAC-h of ${_gases[_primaryGasTypeValue][0]} '
                'on a $_patientWeightField-kg patient '
                'is responsible for ${ghgImpact.toStringAsFixed(3)} kg CO\u2082-eq '
                'which is equivalent to driving a gasoline car for ${_distanceTravelled.toStringAsFixed(3)} km.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    _screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/background.jpg"),
                fit: BoxFit.fill,
              ),
            ),
          ),
          Center(
            // Center is a layout widget. It takes a single child and positions it
            // in the middle of the parent.
            child: _selectedBarIndex == 1
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text(
                        'A quick calculator to estimate the GHG emissions of anesthesia procedures.\n\nThis app was developed by Veduren Rajaratnam and Mostafa Abdelwahab under the suprevision of Dr. Thomas Hemmerling',
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const Text('Administration:     '),
                          DropdownButton<String>(
                            key: const ValueKey('administrationdropdown'),
                            value: _administrationTypeValue,
                            isDense: true,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(
                                  '',
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'iv',
                                child: Text(
                                  'IV (Propofol)',
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'inhale',
                                child: Text(
                                  'Inhalative',
                                ),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              setState(() {
                                _animationWidth = 0.0;
                                _administrationTypeValue = newValue!;
                                _result = _emptyResult;
                              });
                            },
                          ),
                        ],
                      ),
                      _administrationTypeValue == 'inhale'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                const Text('Primary Gas:          '),
                                DropdownButton<String>(
                                  value: _primaryGasTypeValue,
                                  //isDense: true,
                                  items: _gases.entries
                                      .map((e) => DropdownMenuItem<String>(
                                            value: e.key,
                                            child: Text(
                                              e.value[0],
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _animationWidth = 0.0;
                                      _primaryGasTypeValue = newValue!;
                                      _result = _emptyResult;
                                    });
                                  },
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      _administrationTypeValue == 'iv'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                const Text(
                                    'Duration of the procedure (minutes):     '),
                                SizedBox(
                                  height: 42,
                                  width: 50,
                                  child: TextField(
                                    key: const ValueKey('durationfield'),
                                    maxLines: 1,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (String value) {
                                      _durationProcedureField = value;
                                      _clearResult();
                                    },
                                    onSubmitted: (String value) {
                                      _durationProcedureField = value;
                                    },
                                    controller: _durationProcedureController,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      _administrationTypeValue == 'iv'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                const Text(
                                    'Volume of administered propofol (mL):     '),
                                SizedBox(
                                  height: 42,
                                  width: 50,
                                  child: TextField(
                                    key: const ValueKey('volumefield'),
                                    maxLines: 1,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (String value) {
                                      _propofolVolumeField = value;
                                      _clearResult();
                                    },
                                    onSubmitted: (String value) {
                                      _propofolVolumeField = value;
                                    },
                                    controller: _propofolVolumeController,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      _administrationTypeValue == 'iv'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                const Text('Number of syringes:        '),
                                SizedBox(
                                  height: 42,
                                  width: 50,
                                  child: TextField(
                                    key: const ValueKey('nbsyringesfield'),
                                    maxLines: 1,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(),
                                    onChanged: (String value) {
                                      _syringeNumbersField = value;
                                      _clearResult();
                                    },
                                    onSubmitted: (String value) {
                                      _syringeNumbersField = value;
                                    },
                                    controller: _syringeNumbersController,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      // _administrationTypeValue == 'inhale'
                      //     ? Row(
                      //         mainAxisAlignment: MainAxisAlignment.center,
                      //         crossAxisAlignment: CrossAxisAlignment.center,
                      //         children: <Widget>[
                      //           const Text('Primary Gas flow (L/min):     '),
                      //           SizedBox(
                      //             height: 42,
                      //             width: 50,
                      //             child: TextField(
                      //               maxLines: 1,
                      //               keyboardType:
                      //                   const TextInputType.numberWithOptions(
                      //                       decimal: true),
                      //               onChanged: (String value) {
                      //                 _primaryGasFlowField = value;
                      //                 _clearResult();
                      //               },
                      //               onSubmitted: (String value) {
                      //                 _primaryGasFlowField = value;
                      //               },
                      //               controller: _primaryGasFlowController,
                      //             ),
                      //           ),
                      //         ],
                      //       )
                      //     : const SizedBox.shrink(),
                      // _administrationTypeValue == 'inhale'
                      //     ? Row(
                      //         mainAxisAlignment: MainAxisAlignment.center,
                      //         crossAxisAlignment: CrossAxisAlignment.center,
                      //         children: <Widget>[
                      //           const Text('Nitrous Oxide flow (L/min):     '),
                      //           SizedBox(
                      //             height: 42,
                      //             width: 50,
                      //             child: TextField(
                      //               maxLines: 1,
                      //               keyboardType:
                      //                   const TextInputType.numberWithOptions(
                      //                       decimal: true),
                      //               onChanged: (String value) {
                      //                 _nitrousOxideFlowField = value;
                      //                 _clearResult();
                      //               },
                      //               onSubmitted: (String value) {
                      //                 _nitrousOxideFlowField = value;
                      //               },
                      //               controller: _nitrousOxideFlowController,
                      //             ),
                      //           ),
                      //         ],
                      //       )
                      //     : const SizedBox.shrink(),
                      _administrationTypeValue == 'inhale'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                const Text('MAC-h value:     '),
                                SizedBox(
                                  height: 42,
                                  width: 50,
                                  child: TextField(
                                    maxLines: 1,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (String value) {
                                      _primaryGasMAChField = value;
                                      _clearResult();
                                    },
                                    onSubmitted: (String value) {
                                      _primaryGasMAChField = value;
                                    },
                                    controller: _primaryGasMAChController,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      _administrationTypeValue == 'inhale'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                const Text('Patient weight (kg):     '),
                                SizedBox(
                                  height: 42,
                                  width: 50,
                                  child: TextField(
                                    maxLines: 1,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (String value) {
                                      _patientWeightField = value;
                                      _clearResult();
                                    },
                                    onSubmitted: (String value) {
                                      _patientWeightField = value;
                                    },
                                    controller: _patientWeightController,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      _administrationTypeValue != ''
                          ? ElevatedButton(
                              key: const ValueKey('computebutton'),
                              onPressed: _onPressedCompute,
                              child: const Text('Compute'),
                            )
                          : const SizedBox.shrink(),
                      _administrationTypeValue != ''
                          ? Text(
                              _result,
                              style: _textStyle,
                            )
                          : const SizedBox.shrink(),
                      SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: _screenWidth / 6,
                            ),
                            AnimatedContainer(
                              width: _animationWidth,
                              duration: const Duration(seconds: 6),
                              curve: Curves.linearToEaseOut,
                            ),
                            Visibility(
                              child: const Image(
                                image: AssetImage("assets/images/car.png"),
                                width: 45,
                              ),
                              visible: _administrationTypeValue != '' &&
                                  _distanceTravelled > 0 &&
                                  _result != _emptyResult,
                            ),
                          ],
                        ),
                      ),
                      _administrationTypeValue != '' &&
                              _distanceTravelled > 0 &&
                              _result != _emptyResult
                          ? SafeArea(
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: _screenWidth / 6,
                                    ),
                                    Text(
                                      '0km',
                                      style: _textStyle,
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_distanceTravelled.toStringAsFixed(3)}km',
                                      style: _textStyle,
                                    ),
                                    Container(
                                      width: _screenWidth / 6,
                                    ),
                                  ]),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate_outlined),
            label: 'Calculator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline_rounded),
            label: 'About',
          ),
        ],
        currentIndex: _selectedBarIndex,
        selectedItemColor: Colors.amber[800],
        onTap: (int index) {
          setState(() {
            _animationWidth = 0.0;
            _result = _emptyResult;
            _selectedBarIndex = index;
          });
        },
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
