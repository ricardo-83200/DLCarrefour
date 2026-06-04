import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const CarrefourCityApp());

class ProduitScanne {
  final String ean;
  final String nom;
  final String marque;
  final String? urlImage;
  final DateTime dlc;

  ProduitScanne({
    required this.ean,
    required this.nom,
    required this.marque,
    this.urlImage,
    required this.dlc,
  });
}

class CarrefourCityApp extends StatelessWidget {
  const CarrefourCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carrefour City DLC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00387B),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF00387B),
          elevation: 0,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<ProduitScanne> _historiqueGlobal = <ProduitScanne>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Color(0xFF00387B), shape: BoxShape.circle),
              child: const Icon(Icons.apps, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('CARREFOUR CITY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 18)),
          ],
        ),
        centerTitle: true,
      ),
      body: _currentIndex == 0 
          ? PageScanner(onSave: (p) => setState(() => _historiqueGlobal.insert(0, p)))
          : PageHistorique(liste: _historiqueGlobal),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF00387B),
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Mes DLC'),
        ],
      ),
    );
  }
}

class PageScanner extends StatefulWidget {
  final Function(ProduitScanne) onSave;
  const PageScanner({super.key, required this.onSave});

  @override
  State<PageScanner> createState() => _PageScannerState();
}

class _PageScannerState extends State<PageScanner> {
  String? codeEanScanne;
  bool enChargement = false;
  
  String? nomProduit;
  String? marqueProduit;
  String? urlImageProduit;
  DateTime _dateSelectionnee = DateTime.now().add(const Duration(days: 3));

  final TextEditingController _eanController = TextEditingController();

  Future<void> _ouvrirScannerMobile() async {
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      if (!mounted) return;
      final codeBipe = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const EcranCameraUnique()),
      );

      if (codeBipe != null && codeBipe.isNotEmpty) {
        setState(() {
          codeEanScanne = codeBipe;
        });
        rechercherProduit(codeBipe);
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission caméra requise pour le scan.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> rechercherProduit(String barcode) async {
    setState(() => enChargement = true);
    final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          setState(() {
            nomProduit = product['product_name_fr'] ?? product['product_name'] ?? 'Produit inconnu';
            marqueProduit = product['brands'] ?? 'Marque inconnue';
            urlImageProduit = product['image_front_thumb_url'];
          });
        } else {
          setState(() {
            nomProduit = 'Produit inconnu';
            marqueProduit = 'Manuel';
            urlImageProduit = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        nomProduit = 'Erreur réseau';
        marqueProduit = '-';
      });
    } finally {
      setState(() => enChargement = false);
    }
  }

  void _ouvrirSaisieManuelle() {
    _eanController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrer le code EAN'),
        content: TextField(controller: _eanController, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (_eanController.text.isNotEmpty) {
                Navigator.pop(context);
                setState(() => codeEanScanne = _eanController.text);
                rechercherProduit(_eanController.text);
              }
            },
            child: const Text('Valider'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00387B).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00387B).withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 60, color: Color(0xFF00387B)),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00387B)),
                    onPressed: _ouvrirScannerMobile,
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text('OUVRIR LE SCANNER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: _ouvrirSaisieManuelle,
                    child: const Text('Taper le code à la main', style: TextStyle(color: Colors.grey)),
                  )
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: enChargement
                ? const Center(child: CircularProgressIndicator())
                : codeEanScanne == null
                    ? const Center(child: Text('Prêt pour le scan en rayon', style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            if (urlImageProduit != null) Image.network(urlImageProduit!, height: 80),
                            Text(nomProduit ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            Text('EAN: $codeEanScanne', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const Divider(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sélectionner la DLC :'),
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _dateSelectionnee,
                                      firstDate: DateTime.now().subtract(const Duration(days: 10)),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) setState(() => _dateSelectionnee = picked);
                                  },
                                  child: Text(DateFormat('dd/MM/yyyy').format(_dateSelectionnee)),
                                )
                              ],
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                              onPressed: () {
                                widget.onSave(ProduitScanne(
                                  ean: codeEanScanne!,
                                  nom: nomProduit ?? 'Inconnu',
                                  marque: marqueProduit ?? 'Inconnu',
                                  urlImage: urlImageProduit,
                                  dlc: _dateSelectionnee,
                                ));
                                setState(() => codeEanScanne = null);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Produit enregistré !'), backgroundColor: Colors.green),
                                );
                              },
                              child: const Text('VALIDER ET ENREGISTRER', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      ),
          ),
        )
      ],
    );
  }
}

// Nouvel écran de caméra utilisant le package qr_code_scanner autonome
class EcranCameraUnique extends StatefulWidget {
  const EcranCameraUnique({super.key});

  @override
  State<EcranCameraUnique> createState() => _EcranCameraUniqueState();
}

class _EcranCameraUniqueState extends State<EcranCameraUnique> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  // Indispensable sur Android pour que la caméra redémarre correctement au changement de fenêtre
  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: const Color(0xFF00387B),
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 250,
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    // On force l'appareil photo à s'activer
    controller.resumeCamera();
    
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && scanData.code!.isNotEmpty) {
        controller.dispose();
        Navigator.pop(context, scanData.code); // Renvoie le code barre et ferme l'écran
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

class PageHistorique extends StatefulWidget {
  final List<ProduitScanne> liste;
  const PageHistorique({super.key, required this.liste});

  @override
  State<PageHistorique> createState() => _PageHistoriqueState();
}

class _PageHistoriqueState extends State<PageHistorique> {
  String _recherche = "";

  @override
  Widget build(BuildContext context) {
    final filtres = widget.liste.where((p) {
      final query = _recherche.toLowerCase();
      return p.nom.toLowerCase().contains(query) || p.ean.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (v) => setState(() => _recherche = v),
            decoration: const InputDecoration(hintText: 'Rechercher...', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: filtres.isEmpty
              ? const Center(child: Text('Aucun produit enregistré.'))
              : ListView.builder(
                  itemCount: filtres.length,
                  itemBuilder: (context, index) {
                    final p = filtres[index];
                    return ListTile(
                      title: Text(p.nom),
                      subtitle: Text('EAN: ${p.ean}'),
                      trailing: Text(DateFormat('dd/MM/yy').format(p.dlc), style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}