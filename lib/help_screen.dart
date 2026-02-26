import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─── Vsebina pomoči ──────────────────────────────────────
const _appVersion = '1.0.0';

const _intro =
    'Postnik je preprosta aplikacija za sledenje intermitentnega posta. '
    'Pomaga ti nastaviti cilj posta, odštevati preostali čas in beležiti '
    'zgodovino tvojih postov.';

const _sections = [
  _HelpSection(
    icon: Icons.timer,
    title: 'Timer',
    items: [
      'Velika številka prikazuje preostali čas do konca posta.',
      'Krožni obroč s gradientom (roza → vijolična → zelena) prikazuje napredek posta.',
      'Analogna številčnica z graduacijami obdaja obroč – brez oznak tam, kjer ni loka.',
      'Mejne točke vzdolž loka so barvno usklajene z gradientom obroča.',
      'Majhno besedilo spodaj kaže, koliko časa je že preteklo.',
      'Ko post zaključi, se v sredini prikaže ikona Postnika v zeleni barvi.',
    ],
  ),
  _HelpSection(
    icon: Icons.tune,
    title: 'Izbira dolžine posta',
    items: [
      'Nad gumbi je napis "Izberi čas" za lažjo orientacijo.',
      'Gumbi 8, 16 in 24 ur hitro nastavijo najpogostejše dolžine posta.',
      'Gumb "Nastavi čas" odpre kolesce za natančnejšo nastavitev po urah in minutah.',
      'Menjava dolžine med tekom timerja ni možna – najprej ustavi post.',
    ],
  ),
  _HelpSection(
    icon: Icons.play_arrow_rounded,
    title: 'Začni / Ustavi / Ponastavi',
    items: [
      '"Začni" (ikona ▶) zažene odštevanje.',
      '"Ustavi" (ikona ■) zaustavi post in ga takoj shrani v zgodovino – čas se ohrani, post je mogoče nadaljevati.',
      '"Ponastavi" (ikona ↺) ponastavi timer za nov post.',
      '"Znova" (ikona ▶) po zaključenem postu ponastavi timer za nov post.',
    ],
  ),
  _HelpSection(
    icon: Icons.history,
    title: 'Zgodovina',
    items: [
      'Prikaže vse pretekle poste, najnovejše na vrhu.',
      'Zelena kljukica = zaključen post (cilj dosežen).',
      'Vijolična pavza = nedokončan post (prekinjen pred ciljem).',
      'Krožni indikator poleg vsakega zapisa prikazuje, koliko cilja je bilo doseženo.',
      'Potegni navzdol za osvežitev seznama.',
      'Gumb koša (zgoraj desno) izbriše celotno zgodovino.',
    ],
  ),
  _HelpSection(
    icon: Icons.notifications_outlined,
    title: 'Obvestila',
    items: [
      'Ob zaključku posta dobiš obvestilo: "Post je zaključen. Čas je za zavesten obrok."',
      'V nastavitvah sta dve ločeni stikali: obvestila na zaslonu in zvočna obvestila.',
      'Zvočno obvestilo vključuje zvok in vibracijo; tiho obvestilo se prikaže brez zvoka.',
      'Obvestila delujejo tudi, ko je aplikacija v ozadju ali je zaslon zaklenjen.',
      'Ob prvem zagonu aplikacija zaprosi za dovoljenje za obvestila.',
    ],
  ),
  _HelpSection(
    icon: Icons.dark_mode_rounded,
    title: 'Tema',
    items: [
      'Stikalo za temo je v glavi aplikacije (zgoraj desno) – ikona lune ali sonca.',
      'Tapni stikalo za preklop med temno in svetlo temo.',
      'Izbrana tema se shrani in ostane aktivna ob naslednji uporabi.',
    ],
  ),
];

class _HelpSection {
  final IconData icon;
  final String title;
  final List<String> items;
  const _HelpSection(
      {required this.icon, required this.title, required this.items});
}

// ─── Help Screen ─────────────────────────────────────────
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _exportPdf(BuildContext context) async {
    try {
      await _buildAndSharePdf(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri izvozu PDF: $e')),
        );
      }
    }
  }

  // Zamenja Unicode simbole, ki jih Poppins ne podpira, z ASCII ekvivalenti
  static String _pdfSafe(String text) => text
      .replaceAll('▶', '-')
      .replaceAll('■', '-')
      .replaceAll('↺', '-');

  Future<void> _buildAndSharePdf(BuildContext context) async {
    final pdf = pw.Document();
    final accent = PdfColor.fromHex('#6C63FF');
    final grey = PdfColors.grey700;

    // Naloži Poppins fonte iz assetov – edina rešitev za šumnike v PDF-ju
    final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Postnik',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                )),
            pw.Text('Navodila za uporabo  •  v$_appVersion',
                style: pw.TextStyle(fontSize: 11, color: grey)),
            pw.Divider(color: PdfColors.grey300, thickness: 0.8),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (_) => [
          pw.Text(_intro,
              style: pw.TextStyle(fontSize: 12, color: grey, lineSpacing: 4)),
          pw.SizedBox(height: 20),
          for (final s in _sections) ...[
            pw.Text(s.title,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
            pw.SizedBox(height: 6),
            for (final item in s.items)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ',
                        style:
                            pw.TextStyle(color: accent, fontSize: 12)),
                    pw.Expanded(
                      child: pw.Text(_pdfSafe(item),
                          style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.black,
                              lineSpacing: 3)),
                    ),
                  ],
                ),
              ),
            pw.SizedBox(height: 14),
          ],
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            'Postnik  •  Različica $_appVersion\n'
            'Aplikacija za sledenje intermitentnega posta.',
            style: pw.TextStyle(fontSize: 10, color: grey),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'postnik-navodila.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0F0F1A) : const Color(0xFFF0EEFF);
    final cardBg = dark ? const Color(0xFF1A1A2E) : const Color(0xFFEDE9FF);
    final textColor = dark ? Colors.white : Colors.black87;
    final subtleColor = dark ? Colors.white54 : Colors.black54;
    const accent = Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Pomoč',
            style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(Icons.picture_as_pdf_outlined,
                  color: textColor.withValues(alpha: 0.6)),
              tooltip: 'Izvozi PDF',
              onPressed: () => _exportPdf(context),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Intro
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_intro,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sections
          for (final s in _sections) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  leading: Icon(s.icon, color: accent, size: 22),
                  title: Text(s.title,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  iconColor: subtleColor,
                  collapsedIconColor: subtleColor,
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: s.items
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.circle,
                                    size: 6,
                                    color: accent
                                        .withValues(alpha: 0.7)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(item,
                                      style: TextStyle(
                                          color: textColor
                                              .withValues(alpha: 0.85),
                                          fontSize: 13,
                                          height: 1.45)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],

          // PDF gumb
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _exportPdf(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB8AEFF), Color(0xFF6C63FF)],
                ),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('Prenesi navodila (PDF)',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
