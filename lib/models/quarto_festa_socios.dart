// lib/models/quarto_festa_socios.dart
//
// Catálogo fixo dos quartos do Villamor Prime para o módulo Hospedagem →
// "Festa dos Sócios". É o mapa físico do resort (estático); a alocação de
// quem fica em cada quarto entra numa etapa posterior (via Firestore).
//
// Cores aproximadas da legenda do mapa oficial; ajustáveis sem impacto lógico.
import 'package:flutter/material.dart';

enum CategoriaQuarto {
  luxo,
  studioRoom,
  duplex,
  triplo,
  master,
  comfortTerreo,
  comfort1Andar,
  comfort2Andar,
  suiteVillamor,
  suiteDuplex,
}

extension CategoriaQuartoX on CategoriaQuarto {
  String get label {
    switch (this) {
      case CategoriaQuarto.luxo:
        return 'Luxo';
      case CategoriaQuarto.studioRoom:
        return 'Studio Room';
      case CategoriaQuarto.duplex:
        return 'Duplex';
      case CategoriaQuarto.triplo:
        return 'Triplo';
      case CategoriaQuarto.master:
        return 'Master';
      case CategoriaQuarto.comfortTerreo:
        return 'Comfort Térreo';
      case CategoriaQuarto.comfort1Andar:
        return 'Comfort 1º Andar';
      case CategoriaQuarto.comfort2Andar:
        return 'Comfort 2º Andar';
      case CategoriaQuarto.suiteVillamor:
        return 'Suíte Villamor';
      case CategoriaQuarto.suiteDuplex:
        return 'Suíte Duplex';
    }
  }

  Color get cor {
    switch (this) {
      case CategoriaQuarto.luxo:
        return const Color(0xFF1CA9E3);
      case CategoriaQuarto.studioRoom:
        return const Color(0xFFD2641B);
      case CategoriaQuarto.duplex:
        return const Color(0xFFF2D024);
      case CategoriaQuarto.triplo:
        return const Color(0xFF1FA64A);
      case CategoriaQuarto.master:
        return const Color(0xFF9BA21E);
      case CategoriaQuarto.comfortTerreo:
        return const Color(0xFF3E3D6B);
      case CategoriaQuarto.comfort1Andar:
        return const Color(0xFF74D818);
      case CategoriaQuarto.comfort2Andar:
        return const Color(0xFF463C57);
      case CategoriaQuarto.suiteVillamor:
        return const Color(0xFFC73B73);
      case CategoriaQuarto.suiteDuplex:
        return const Color(0xFF8334D6);
    }
  }

  /// Cor de texto legível sobre [cor] (claro/escuro por luminância).
  Color get corTexto =>
      cor.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
}

class QuartoFestaSocios {
  final String numero;
  final CategoriaQuarto categoria;
  const QuartoFestaSocios(this.numero, this.categoria);
}

/// Mapa físico do resort (≈88 quartos). O número 113 não existe no mapa.
const List<QuartoFestaSocios> quartosFestaSocios = [
  // ── Linha superior ────────────────────────────────────────────────────────
  QuartoFestaSocios('52', CategoriaQuarto.luxo),
  QuartoFestaSocios('53', CategoriaQuarto.luxo),
  QuartoFestaSocios('54', CategoriaQuarto.luxo),
  QuartoFestaSocios('55', CategoriaQuarto.luxo),
  QuartoFestaSocios('56', CategoriaQuarto.luxo),
  QuartoFestaSocios('57', CategoriaQuarto.luxo),
  QuartoFestaSocios('71', CategoriaQuarto.studioRoom),
  QuartoFestaSocios('72', CategoriaQuarto.studioRoom),
  QuartoFestaSocios('73', CategoriaQuarto.studioRoom),
  QuartoFestaSocios('58', CategoriaQuarto.luxo),
  QuartoFestaSocios('59', CategoriaQuarto.luxo),
  // ── Rooftop (colunas 144–170) ──────────────────────────────────────────────
  QuartoFestaSocios('144', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('145', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('146', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('147', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('148', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('149', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('150', CategoriaQuarto.suiteDuplex),
  QuartoFestaSocios('151', CategoriaQuarto.suiteDuplex),
  QuartoFestaSocios('152', CategoriaQuarto.suiteDuplex),
  QuartoFestaSocios('153', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('154', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('155', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('156', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('157', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('158', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('159', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('160', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('161', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('162', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('163', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('164', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('165', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('166', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('167', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('168', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('169', CategoriaQuarto.comfort2Andar),
  QuartoFestaSocios('170', CategoriaQuarto.comfort2Andar),
  // ── Próximo ao Ôfuro ───────────────────────────────────────────────────────
  QuartoFestaSocios('141', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('142', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('143', CategoriaQuarto.suiteVillamor),
  // ── Bloco direito (121–140) ────────────────────────────────────────────────
  // 121-130 reclassificados como Comfort (eram exibidos como Master).
  QuartoFestaSocios('121', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('122', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('123', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('124', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('125', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('131', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('132', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('133', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('134', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('135', CategoriaQuarto.suiteVillamor),
  QuartoFestaSocios('126', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('127', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('128', CategoriaQuarto.duplex),
  QuartoFestaSocios('129', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('130', CategoriaQuarto.comfortTerreo),
  QuartoFestaSocios('136', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('137', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('138', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('139', CategoriaQuarto.comfort1Andar),
  QuartoFestaSocios('140', CategoriaQuarto.comfort1Andar),
  // ── Coluna esquerda (Massagem/Restaurante) ─────────────────────────────────
  QuartoFestaSocios('204', CategoriaQuarto.master),
  QuartoFestaSocios('116', CategoriaQuarto.luxo),
  QuartoFestaSocios('203', CategoriaQuarto.master),
  QuartoFestaSocios('202', CategoriaQuarto.master),
  QuartoFestaSocios('201', CategoriaQuarto.master),
  // ── Centro ─────────────────────────────────────────────────────────────────
  QuartoFestaSocios('51', CategoriaQuarto.luxo),
  // ── Coluna direita (Banho Romano/Sauna) ────────────────────────────────────
  QuartoFestaSocios('205', CategoriaQuarto.master),
  QuartoFestaSocios('206', CategoriaQuarto.master),
  QuartoFestaSocios('207', CategoriaQuarto.master),
  QuartoFestaSocios('117', CategoriaQuarto.luxo),
  QuartoFestaSocios('208', CategoriaQuarto.master),
  QuartoFestaSocios('209', CategoriaQuarto.master),
  QuartoFestaSocios('210', CategoriaQuarto.master),
  // ── Linha inferior (junto à Recepção) ──────────────────────────────────────
  QuartoFestaSocios('115', CategoriaQuarto.luxo),
  QuartoFestaSocios('114', CategoriaQuarto.luxo),
  QuartoFestaSocios('112', CategoriaQuarto.luxo),
  QuartoFestaSocios('111', CategoriaQuarto.luxo),
  QuartoFestaSocios('110', CategoriaQuarto.luxo),
  QuartoFestaSocios('109', CategoriaQuarto.luxo),
  QuartoFestaSocios('108', CategoriaQuarto.luxo),
  QuartoFestaSocios('107', CategoriaQuarto.luxo),
  QuartoFestaSocios('106', CategoriaQuarto.luxo),
  QuartoFestaSocios('105', CategoriaQuarto.triplo),
  QuartoFestaSocios('104', CategoriaQuarto.luxo),
  QuartoFestaSocios('103', CategoriaQuarto.luxo),
  QuartoFestaSocios('102', CategoriaQuarto.luxo),
  QuartoFestaSocios('101', CategoriaQuarto.triplo),
];
