import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bloom/data/models/crop.dart';

class FlameGardenGame extends FlameGame with TapCallbacks {
  Garden gardenData;
  final Function(int x, int y) onTileTapped;
  final Function(int x, int y, String actionType) onTileActionSelected;
  final Map<String, GardenTileComponent> tileComponents = {};
  ActionOverlay? currentOverlay;
  GardenTileComponent? selectedTile; // 현재 선택된 타일
  bool isOverlayActive = false; // 오버레이 활성 상태

  FlameGardenGame({
    required this.gardenData,
    required this.onTileTapped,
    required this.onTileActionSelected,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 배경 생성
    add(GradientBackground());
    
    // 정원 타일들 생성
    _createGardenTiles();
    
    // 주기적인 파티클 효과 추가
    _addAmbientParticles();
  }

  void _createGardenTiles() {
    // 화면 크기를 고려한 안전한 여백 설정
    final margin = 20.0;
    final availableWidth = size.x - (margin * 2);
    final availableHeight = size.y - (margin * 2);
    
    // 정사각형 그리드가 화면에 맞도록 크기 계산
    final maxSize = math.min(availableWidth, availableHeight);
    final tileSize = (maxSize - (gardenData.size + 1) * 4) / gardenData.size;
    
    // 중앙 정렬을 위한 시작 위치 계산
    final gridSize = tileSize * gardenData.size + (gardenData.size - 1) * 4;
    final startX = (size.x - gridSize) / 2;
    final startY = (size.y - gridSize) / 2;
    
    for (int y = 0; y < gardenData.size; y++) {
      for (int x = 0; x < gardenData.size; x++) {
        final tile = gardenData.getTile(x, y);
        final tileComponent = GardenTileComponent(
          tile: tile,
          tileSize: Vector2.all(tileSize),
          tilePosition: Vector2(
            startX + x * (tileSize + 4),
            startY + y * (tileSize + 4),
          ),
          onTapped: () => onTileTapped(x, y),
        );
        
        tileComponents['${x}_$y'] = tileComponent;
        add(tileComponent);
      }
    }
  }

  void _addAmbientParticles() {
    // 배경에 떠다니는 반짝임 파티클들
    add(TimerComponent(
      period: 2.0,
      repeat: true,
      onTick: () {
        final sparkle = SparkleParticle();
        sparkle.position = Vector2(
          math.Random().nextDouble() * size.x,
          math.Random().nextDouble() * size.y,
        );
        add(sparkle);
      },
    ));
    
    // 잔디 흔들림 효과 추가
    _addSwayingGrass();
  }
  
  void _addSwayingGrass() {
    final random = math.Random();
    
    // 타일 영역 계산 (타일 생성 로직과 동일)
    final margin = 20.0;
    final availableWidth = size.x - (margin * 2);
    final availableHeight = size.y - (margin * 2);
    final maxSize = math.min(availableWidth, availableHeight);
    final tileSize = (maxSize - (gardenData.size + 1) * 4) / gardenData.size;
    final gridSize = tileSize * gardenData.size + (gardenData.size - 1) * 4;
    final startX = (size.x - gridSize) / 2;
    final startY = (size.y - gridSize) / 2;
    final endX = startX + gridSize;
    final endY = startY + gridSize;
    
    // 타일 영역을 제외한 백그라운드에만 잔디 배치
    for (int i = 0; i < 30; i++) {
      Vector2? grassPosition;
      int attempts = 0;
      
      // 타일 영역 밖에서 위치 찾기
      while (grassPosition == null && attempts < 10) {
        final x = random.nextDouble() * size.x;
        final y = random.nextDouble() * size.y;
        
        // 타일 영역과 겹치지 않는지 확인
        if (x < startX - 10 || x > endX + 10 || y < startY - 10 || y > endY + 10) {
          grassPosition = Vector2(x, y);
        }
        attempts++;
      }
      
      if (grassPosition != null) {
        final grass = SwayingGrass();
        grass.position = grassPosition;
        add(grass);
      }
    }
  }

  void updateGarden(Garden newGardenData) {
    gardenData = newGardenData;
    
    // 타일 업데이트
    for (int y = 0; y < gardenData.size; y++) {
      for (int x = 0; x < gardenData.size; x++) {
        final tile = gardenData.getTile(x, y);
        final tileComponent = tileComponents['${x}_$y'];
        tileComponent?.updateTile(tile);
      }
    }
  }

  void addPlantingEffect(int x, int y) {
    final tileComponent = tileComponents['${x}_$y'];
    if (tileComponent != null) {
      final effect = PlantingEffect();
      effect.position = tileComponent.position + tileComponent.size / 2;
      add(effect);
      HapticFeedback.lightImpact();
    }
  }

  void addGrowthEffect(int x, int y) {
    final tileComponent = tileComponents['${x}_$y'];
    if (tileComponent != null) {
      final effect = GrowthEffect();
      effect.position = tileComponent.position + tileComponent.size / 2;
      add(effect);
      HapticFeedback.mediumImpact();
    }
  }

  void addHarvestEffect(int x, int y, {int? rewardPoints}) {
    final tileComponent = tileComponents['${x}_$y'];
    if (tileComponent != null) {
      final effect = HarvestEffect(rewardPoints: rewardPoints);
      effect.position = tileComponent.position + tileComponent.size / 2;
      add(effect);
      HapticFeedback.heavyImpact();
    }
  }

  void showActionOverlay(int x, int y, GardenTile tile) {
    hideActionOverlay();
    
    final tileComponent = tileComponents['${x}_$y'];
    if (tileComponent != null) {
      // 오버레이 활성화 및 선택된 타일 설정
      isOverlayActive = true;
      selectedTile = tileComponent;
      
      // 선택된 타일 하이라이트 활성화
      tileComponent.setSelected(true);
      
      currentOverlay = ActionOverlay(
        tile: tile,
        tilePosition: tileComponent.position,
        tileSize: tileComponent.size,
        onActionSelected: (actionType) {
          onTileActionSelected(x, y, actionType);
          hideActionOverlay();
        },
        onCancel: hideActionOverlay,
      );
      add(currentOverlay!);
      HapticFeedback.selectionClick();
    }
  }

  void hideActionOverlay() {
    if (currentOverlay != null) {
      currentOverlay!.removeFromParent();
      currentOverlay = null;
    }
    
    // 선택된 타일 하이라이트 해제
    if (selectedTile != null) {
      selectedTile!.setSelected(false);
      selectedTile = null;
    }
    
    // 오버레이 비활성화
    isOverlayActive = false;
  }

  // 타일이 클릭 가능한지 확인
  bool canTileBeClicked() {
    return !isOverlayActive;
  }

  @override
  bool onTapDown(TapDownEvent event) {
    // 오버레이가 있으면 제거
    if (currentOverlay != null) {
      hideActionOverlay();
      return true;
    }
    return true;
  }
}

class GradientBackground extends RectangleComponent with HasGameReference<FlameGardenGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;
    paint = Paint()
      ..color = const Color(0xFF90EE90) // Light green
      ..style = PaintingStyle.fill;
  }
}

class GardenTileComponent extends RectangleComponent with TapCallbacks, HasGameReference<FlameGardenGame> {
  GardenTile tile;
  final VoidCallback onTapped;
  late final RectangleComponent highlight;
  late final TextComponent cropIcon;
  RectangleComponent? statusIndicator;
  late final CircleComponent selectionHighlight; // 선택 하이라이트
  bool isSelected = false;
  
  GardenTileComponent({
    required this.tile,
    required Vector2 tileSize,
    required Vector2 tilePosition,
    required this.onTapped,
  }) : super(size: tileSize, position: tilePosition);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 선택 하이라이트 (원형, 맨 아래 레이어) - 훨씬 더 밝게
    selectionHighlight = CircleComponent(
      radius: size.x / 2 + 12, // 타일보다 더 크게
      paint: Paint()
        ..color = Colors.white.withAlpha(230) // 153 -> 230으로 더 밝게
        ..style = PaintingStyle.fill,
      position: size / 2,
      anchor: Anchor.center,
    );
    selectionHighlight.opacity = 0;
    add(selectionHighlight);
    
    // 하이라이트 효과
    highlight = RectangleComponent(
      size: size,
      paint: Paint()
        ..color = Colors.white.withAlpha(76)
        ..style = PaintingStyle.fill,
    );
    highlight.opacity = 0;
    add(highlight);
    
    // 작물 아이콘 (더 작고 깔끔하게)
    cropIcon = TextComponent(
      text: _getTileIcon(),
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: _getIconSize(),
          color: _getIconColor(),
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(cropIcon);
    
    _updateAppearance();
    _updateStatusIndicator();
  }

  void updateTile(GardenTile newTile) {
    tile = newTile;
    cropIcon.text = _getTileIcon();
    
    // 텍스트 스타일 업데이트
    cropIcon.textRenderer = TextPaint(
      style: TextStyle(
        fontSize: _getIconSize(),
        color: _getIconColor(),
        fontWeight: FontWeight.bold,
      ),
    );
    
    _updateAppearance();
    _updateStatusIndicator();
    
    // 성장 애니메이션
    if (tile.stage != CropStage.empty) {
      cropIcon.add(
        ScaleEffect.to(
          Vector2.all(1.2),
          EffectController(duration: 0.3, reverseDuration: 0.3),
        ),
      );
    }
  }

  String _getTileIcon() {
    switch (tile.stage) {
      case CropStage.empty:
        return '+';
      case CropStage.planted:
        return '●';
      case CropStage.growing:
        return '▲';
      case CropStage.mature:
        return '★';
    }
  }

  double _getIconSize() {
    final baseSize = size.x * 0.4; // 타일 크기의 40%
    switch (tile.stage) {
      case CropStage.empty:
        return baseSize * 0.8;
      case CropStage.planted:
        return baseSize * 0.6;
      case CropStage.growing:
        return baseSize * 0.8;
      case CropStage.mature:
        return baseSize;
    }
  }

  Color _getIconColor() {
    switch (tile.stage) {
      case CropStage.empty:
        return Colors.brown.shade600;
      case CropStage.planted:
        return Colors.green.shade400;
      case CropStage.growing:
        return Colors.green.shade600;
      case CropStage.mature:
        return Colors.amber.shade600;
    }
  }

  void _updateAppearance() {
    final baseColor = _getTileColor();
    paint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
  }

  @override
  void render(Canvas canvas) {
    // 둥근 모서리 타일 그리기
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, paint);
    
    // 그림자 효과
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(51)
      ..style = PaintingStyle.fill;
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.x, size.y), 
      const Radius.circular(8)
    );
    canvas.drawRRect(shadowRect, shadowPaint);
    canvas.drawRRect(rrect, paint);
  }

  void _updateStatusIndicator() {
    // 기존 상태 표시기 제거
    if (statusIndicator != null) {
      statusIndicator!.removeFromParent();
      statusIndicator = null;
    }
    
    // 새 상태 표시기 추가
    if (tile.canProgress || tile.canHarvest) {
      statusIndicator = RectangleComponent(
        size: Vector2.all(8),
        position: Vector2(size.x - 12, 4),
        paint: Paint()
          ..color = tile.canHarvest ? Colors.yellow : Colors.blue
          ..style = PaintingStyle.fill,
      );
      add(statusIndicator!);
      
      // 깜박이는 효과
      statusIndicator!.add(
        OpacityEffect.fadeOut(
          EffectController(
            duration: 1,
            reverseDuration: 1,
            infinite: true,
          ),
        ),
      );
    }
  }

  Color _getTileColor() {
    switch (tile.stage) {
      case CropStage.empty:
        return const Color(0xFF8BC34A);
      case CropStage.planted:
        return const Color(0xFF66BB6A);
      case CropStage.growing:
        return const Color(0xFF4CAF50);
      case CropStage.mature:
        return const Color(0xFF388E3C);
    }
  }

  // 선택 상태 설정 (오버레이 배경에서 하이라이트 처리하므로 비움)
  void setSelected(bool selected) {
    isSelected = selected;
    // 오버레이 배경에서 선택된 타일 하이라이트를 처리함
  }

  @override
  bool onTapDown(TapDownEvent event) {
    final game = this.game;
    
    // 오버레이가 활성화된 상태면 클릭 무시
    if (!game.canTileBeClicked()) {
      return false;
    }
    
    // 게임에 액션 오버레이 표시 요청
    for (final entry in game.tileComponents.entries) {
      if (entry.value == this) {
        final coords = entry.key.split('_');
        final x = int.parse(coords[0]);
        final y = int.parse(coords[1]);
        game.showActionOverlay(x, y, tile);
        break;
      }
    }
    
    // 탭 피드백 애니메이션 (선택되지 않은 상태에서만)
    if (!isSelected) {
      add(
        ScaleEffect.to(
          Vector2.all(0.95),
          EffectController(duration: 0.1, reverseDuration: 0.1),
        ),
      );
      
      // 하이라이트 효과
      highlight.add(
        OpacityEffect.to(
          1.0,
          EffectController(duration: 0.1, reverseDuration: 0.3),
        ),
      );
    }
    
    return true;
  }
}

class SparkleParticle extends CircleComponent {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    radius = math.Random().nextDouble() * 3 + 1;
    paint = Paint()
      ..color = Colors.white.withAlpha(178)
      ..style = PaintingStyle.fill;
    
    // 반짝임 효과
    add(
      OpacityEffect.fadeOut(
        EffectController(
          duration: 2 + math.Random().nextDouble() * 2,
        ),
      ),
    );
    
    // 위로 떠오르는 효과
    add(
      MoveEffect.to(
        position + Vector2(0, -50 - math.Random().nextDouble() * 50),
        EffectController(duration: 3),
      ),
    );
    
    // 자동 제거
    add(TimerComponent(
      period: 5.0,
      removeOnFinish: true,
      onTick: () {
        removeFromParent();
      },
    ));
  }
}

class PlantingEffect extends PositionComponent {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 씨앗 심기 파티클들
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2) / 8;
      final particle = CircleComponent(
        radius: 2,
        paint: Paint()..color = Colors.brown.withAlpha(204),
      );
      
      particle.position = Vector2.zero();
      add(particle);
      
      particle.add(
        MoveEffect.to(
          Vector2(
            math.cos(angle) * 20,
            math.sin(angle) * 20,
          ),
          EffectController(duration: 0.5),
        ),
      );
      
      particle.add(
        OpacityEffect.fadeOut(
          EffectController(duration: 0.8),
        ),
      );
    }
    
    add(TimerComponent(
      period: 1.0,
      removeOnFinish: true,
      onTick: () {
        removeFromParent();
      },
    ));
  }
}

class GrowthEffect extends PositionComponent {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 성장 파티클들 (초록색)
    for (int i = 0; i < 12; i++) {
      final particle = CircleComponent(
        radius: math.Random().nextDouble() * 3 + 1,
        paint: Paint()..color = Colors.green.withAlpha(178),
      );
      
      final angle = math.Random().nextDouble() * math.pi * 2;
      final distance = math.Random().nextDouble() * 30 + 10;
      
      particle.position = Vector2.zero();
      add(particle);
      
      particle.add(
        MoveEffect.to(
          Vector2(
            math.cos(angle) * distance,
            math.sin(angle) * distance - 20,
          ),
          EffectController(duration: 1.0),
        ),
      );
      
      particle.add(
        OpacityEffect.fadeOut(
          EffectController(duration: 1.2),
        ),
      );
    }
    
    add(TimerComponent(
      period: 1.5,
      removeOnFinish: true,
      onTick: () {
        removeFromParent();
      },
    ));
  }
}

class HarvestEffect extends PositionComponent {
  final int? rewardPoints;
  
  HarvestEffect({this.rewardPoints});
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 수확 파티클들 (황금색)
    for (int i = 0; i < 15; i++) {
      final particle = CircleComponent(
        radius: math.Random().nextDouble() * 4 + 2,
        paint: Paint()..color = Colors.amber.withAlpha(229),
      );
      
      final angle = math.Random().nextDouble() * math.pi * 2;
      final distance = math.Random().nextDouble() * 40 + 20;
      
      particle.position = Vector2.zero();
      add(particle);
      
      particle.add(
        MoveEffect.to(
          Vector2(
            math.cos(angle) * distance,
            math.sin(angle) * distance - 30,
          ),
          EffectController(duration: 1.5),
        ),
      );
      
      particle.add(
        OpacityEffect.fadeOut(
          EffectController(duration: 1.8),
        ),
      );
      
      // 회전 효과
      particle.add(
        RotateEffect.by(
          math.pi * 4,
          EffectController(duration: 1.5),
        ),
      );
    }
    
    // 보상 텍스트 (백엔드에서 받은 실제 포인트 표시)
    if (rewardPoints != null && rewardPoints! > 0) {
      final successText = TextComponent(
        text: '+$rewardPoints Points!',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2),
            ],
          ),
        ),
        anchor: Anchor.center,
      );
      add(successText);
      
      successText.add(
        MoveEffect.to(
          Vector2(0, -40),
          EffectController(duration: 1.5),
        ),
      );
      
      successText.add(
        OpacityEffect.fadeOut(
          EffectController(duration: 1.5),
        ),
      );
    }
    
    add(TimerComponent(
      period: 2.0,
      removeOnFinish: true,
      onTick: () {
        removeFromParent();
      },
    ));
  }
}

class ActionOverlay extends PositionComponent with HasGameReference<FlameGardenGame> {
  final GardenTile tile;
  final Vector2 tilePosition;
  final Vector2 tileSize;
  final Function(String actionType) onActionSelected;
  final VoidCallback onCancel;
  final List<ActionButton> buttons = [];
  late final RectangleComponent background;

  ActionOverlay({
    required this.tile,
    required this.tilePosition,
    required this.tileSize,
    required this.onActionSelected,
    required this.onCancel,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 반투명 배경 (전체 화면)
    background = RectangleComponent(
      size: game.size,
      paint: Paint()
        ..color = Colors.black.withAlpha(50)
        ..style = PaintingStyle.fill,
    );
    add(background);
    
    // 액션 버튼들 생성
    _createActionButtons();
    
    // 등장 애니메이션 (중심에서 바깥으로 확산)
    scale = Vector2.zero();
    add(ScaleEffect.to(
      Vector2.all(1.0),
      EffectController(duration: 0.4, curve: Curves.elasticOut),
    ));
    
    // 페이드 인 효과 (배경에만 적용)
    background.opacity = 0;
    background.add(OpacityEffect.to(
      0.5,
      EffectController(duration: 0.3, curve: Curves.easeOut),
    ));
  }

  void _createActionButtons() {
    final actions = _getAvailableActions();
    final buttonSize = 72.0;
    
    // 타일 중심점 계산
    final centerX = tilePosition.x + tileSize.x / 2;
    final centerY = tilePosition.y + tileSize.y / 2;
    
    // 일관성 있는 원형 배치
    final radius = 85.0;
    final margin = 20.0;
    
    // 기본 원형 배치로 시작
    final basePositions = <Vector2>[];
    for (int i = 0; i < actions.length; i++) {
      final angle = (i * 2 * math.pi) / actions.length - math.pi / 2;
      final buttonX = centerX + math.cos(angle) * radius - buttonSize / 2;
      final buttonY = centerY + math.sin(angle) * radius - buttonSize / 2;
      basePositions.add(Vector2(buttonX, buttonY));
    }
    
    // 전체 버튼 그룹이 화면을 벗어나는지 체크하고 중심점 조정
    final adjustedCenter = _adjustCenterForSafety(
      Vector2(centerX, centerY), 
      basePositions, 
      buttonSize, 
      margin
    );
    
    // 조정된 중심점으로 최종 버튼 위치 계산
    for (int i = 0; i < actions.length; i++) {
      final angle = (i * 2 * math.pi) / actions.length - math.pi / 2;
      final buttonX = adjustedCenter.x + math.cos(angle) * radius - buttonSize / 2;
      final buttonY = adjustedCenter.y + math.sin(angle) * radius - buttonSize / 2;
      
      final button = ActionButton(
        actionType: actions[i]['type'],
        icon: actions[i]['icon'],
        label: actions[i]['label'],
        color: actions[i]['color'],
        size: Vector2.all(buttonSize),
        position: Vector2(buttonX, buttonY),
        onPressed: () => onActionSelected(actions[i]['type']),
        delayIndex: i,
      );
      
      buttons.add(button);
      add(button);
    }
    
    // 취소 버튼 (조정된 중심에 배치)
    final cancelSize = buttonSize * 0.7;
    final cancelButton = ActionButton(
      actionType: 'cancel',
      icon: '×',
      label: 'Cancel',
      color: Colors.grey.shade600,
      size: Vector2.all(cancelSize),
      position: Vector2(
        adjustedCenter.x - cancelSize / 2,
        adjustedCenter.y - cancelSize / 2,
      ),
      onPressed: onCancel,
      delayIndex: actions.length,
    );
    add(cancelButton);
  }

  // 버튼 그룹 전체가 화면 안에 들어오도록 중심점 조정
  Vector2 _adjustCenterForSafety(Vector2 originalCenter, List<Vector2> positions, double buttonSize, double margin) {
    var adjustedCenter = originalCenter;
    
    // 모든 버튼 위치의 경계 계산
    var minX = positions.map((p) => p.x).reduce(math.min);
    var maxX = positions.map((p) => p.x + buttonSize).reduce(math.max);
    var minY = positions.map((p) => p.y).reduce(math.min);
    var maxY = positions.map((p) => p.y + buttonSize).reduce(math.max);
    
    // X축 조정
    if (minX < margin) {
      adjustedCenter = Vector2(adjustedCenter.x + (margin - minX), adjustedCenter.y);
    } else if (maxX > game.size.x - margin) {
      adjustedCenter = Vector2(adjustedCenter.x - (maxX - (game.size.x - margin)), adjustedCenter.y);
    }
    
    // Y축 조정
    if (minY < margin) {
      adjustedCenter = Vector2(adjustedCenter.x, adjustedCenter.y + (margin - minY));
    } else if (maxY > game.size.y - margin) {
      adjustedCenter = Vector2(adjustedCenter.x, adjustedCenter.y - (maxY - (game.size.y - margin)));
    }
    
    return adjustedCenter;
  }

  List<Map<String, dynamic>> _getAvailableActions() {
    final actions = <Map<String, dynamic>>[];
    
    if (tile.canPlant) {
      actions.add({
        'type': 'plant',
        'icon': '🌱',
        'label': 'Plant',
        'color': Colors.green.shade400,
      });
    }
    
    if (tile.canProgress) {
      actions.add({
        'type': 'progress',
        'icon': '💧',
        'label': 'Grow',
        'color': Colors.blue.shade400,
      });
    }
    
    if (tile.canHarvest) {
      actions.add({
        'type': 'harvest',
        'icon': '⭐',
        'label': 'Harvest',
        'color': Colors.amber.shade400,
      });
    }
    
    return actions;
  }
}

class ActionButton extends RectangleComponent with TapCallbacks {
  final String actionType;
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final int delayIndex;
  late final TextComponent iconComponent;
  late final TextComponent labelComponent;

  ActionButton({
    required this.actionType,
    required this.icon,
    required this.label,
    required this.color,
    required Vector2 size,
    required Vector2 position,
    required this.onPressed,
    this.delayIndex = 0,
  }) : super(size: size, position: position);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 버튼 배경
    paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // 아이콘 (더 크고 명확하게)
    iconComponent = TextComponent(
      text: icon,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: size.x * 0.35, // 아이콘 크기 조정
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2 - 6), // 위치 조정
    );
    add(iconComponent);
    
    // 라벨 (더 읽기 쉽게)
    labelComponent = TextComponent(
      text: label,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 12, // 폰트 크기 증가
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [
            const Shadow(
              color: Colors.black54,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y - 8), // 위치 조정
    );
    add(labelComponent);
    
    // 순차 등장 애니메이션 (지연 적용)
    scale = Vector2.zero();
    opacity = 0;
    
    final delay = delayIndex * 0.1; // 0.1초씩 지연
    add(TimerComponent(
      period: delay,
      removeOnFinish: true,
      onTick: () {
        // 스케일 애니메이션
        add(ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(
            duration: 0.5,
            curve: Curves.elasticOut,
          ),
        ));
        
        // 페이드 인 애니메이션
        add(OpacityEffect.to(
          1.0,
          EffectController(duration: 0.3),
        ));
      },
    ));
  }

  @override
  void render(Canvas canvas) {
    // 둥근 버튼 그리기
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.x / 2));
    
    // 더 진한 그림자 (깊이감 강화)
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(102)
      ..style = PaintingStyle.fill;
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.x, size.y),
      Radius.circular(size.x / 2),
    );
    canvas.drawRRect(shadowRect, shadowPaint);
    
    // 버튼 배경 (그라데이션 효과)
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.5),
      radius: 1.2,
      colors: [
        color.withAlpha(255),
        color.withAlpha(204),
      ],
    );
    final gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, gradientPaint);
    
    // 하이라이트 (더 자연스럽게)
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(76)
      ..style = PaintingStyle.fill;
    final highlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y / 2.5),
      Radius.circular(size.x / 2),
    );
    canvas.drawRRect(highlightRect, highlightPaint);
    
    // 테두리 (선명도 향상)
    final borderPaint = Paint()
      ..color = Colors.white.withAlpha(127)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool onTapDown(TapDownEvent event) {
    // 탭 애니메이션
    add(ScaleEffect.to(
      Vector2.all(0.9),
      EffectController(duration: 0.1, reverseDuration: 0.1),
    ));
    
    // 리플 효과
    final rippleEffect = CircleComponent(
      radius: 0,
      paint: Paint()
        ..color = Colors.white.withAlpha(102)
        ..style = PaintingStyle.fill,
      position: size / 2,
      anchor: Anchor.center,
    );
    add(rippleEffect);
    
    rippleEffect.add(ScaleEffect.to(
      Vector2.all(2.0),
      EffectController(duration: 0.3),
    ));
    
    rippleEffect.add(OpacityEffect.fadeOut(
      EffectController(duration: 0.3),
    ));
    
    // 0.15초 후 콜백 실행
    add(TimerComponent(
      period: 0.15,
      removeOnFinish: true,
      onTick: () {
        onPressed();
        HapticFeedback.lightImpact();
      },
    ));
    
    return true;
  }
}

class SwayingGrass extends PositionComponent {
  late final Component grassBlade;
  final math.Random random = math.Random();
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 잔디 높이와 너비 랜덤 설정
    final grassHeight = 12.0 + random.nextDouble() * 16.0;
    final grassWidth = 3.0 + random.nextDouble() * 2.0;
    
    // 잔디 모양을 더 자연스럽게 만들기
    grassBlade = GrassBlade(
      bladeSize: Vector2(grassWidth, grassHeight),
      color: Color.lerp(
        Colors.green.shade300,
        Colors.green.shade600,
        random.nextDouble(),
      )!.withAlpha(200),
    );
    
    add(grassBlade);
    
    // 바람 흔들림 애니메이션
    _startSwayingAnimation();
  }
  
  void _startSwayingAnimation() {
    // 각 잔디마다 다른 속도와 강도로 흔들림
    final swayDuration = 2.0 + random.nextDouble() * 2.0;
    final swayAngle = 0.1 + random.nextDouble() * 0.2;
    final delay = random.nextDouble() * 2.0;
    
    // 지연 후 애니메이션 시작
    add(TimerComponent(
      period: delay,
      removeOnFinish: true,
      onTick: () {
        // 좌우 흔들림 애니메이션
        grassBlade.add(
          RotateEffect.by(
            swayAngle,
            EffectController(
              duration: swayDuration,
              reverseDuration: swayDuration,
              infinite: true,
              curve: Curves.easeInOut,
            ),
          ),
        );
        
        // 가끔 더 강한 바람 효과
        add(TimerComponent(
          period: 5.0 + random.nextDouble() * 10.0,
          repeat: true,
          onTick: () {
            if (random.nextDouble() < 0.3) {
              grassBlade.add(
                RotateEffect.by(
                  swayAngle * 2,
                  EffectController(
                    duration: 0.5,
                    reverseDuration: 1.0,
                    curve: Curves.elasticOut,
                  ),
                ),
              );
            }
          },
        ));
      },
    ));
  }
}

class GrassBlade extends PositionComponent {
  final Vector2 bladeSize;
  final Color color;
  
  GrassBlade({
    required this.bladeSize,
    required this.color,
  }) : super(size: bladeSize, anchor: Anchor.bottomCenter);
  
  @override
  void render(Canvas canvas) {
    // 잔디 잎 모양을 Path로 그리기 (더 자연스럽게)
    final path = Path();
    final width = bladeSize.x;
    final height = bladeSize.y;
    
    // 잔디 잎 모양 (아래에서 위로 가면서 좁아짐)
    path.moveTo(-width / 2, 0); // 시작점 (아래 왼쪽)
    path.quadraticBezierTo(
      -width / 3, -height * 0.3, // 제어점
      -width / 4, -height * 0.6, // 중간점
    );
    path.quadraticBezierTo(
      -width / 8, -height * 0.8, // 제어점
      0, -height, // 끝점 (위 중앙)
    );
    path.quadraticBezierTo(
      width / 8, -height * 0.8, // 제어점
      width / 4, -height * 0.6, // 중간점
    );
    path.quadraticBezierTo(
      width / 3, -height * 0.3, // 제어점
      width / 2, 0, // 끝점 (아래 오른쪽)
    );
    path.close();
    
    // 그라데이션 효과
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withAlpha(255),
          color.withAlpha(180),
          color.withAlpha(120),
        ],
      ).createShader(Rect.fromLTWH(-width/2, -height, width, height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, paint);
    
    // 잔디 중간에 선 그리기 (더 리얼하게)
    final centerLinePaint = Paint()
      ..color = color.withAlpha(100)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    final centerPath = Path();
    centerPath.moveTo(0, 0);
    centerPath.quadraticBezierTo(
      width / 16, -height * 0.5,
      0, -height * 0.9,
    );
    
    canvas.drawPath(centerPath, centerLinePaint);
  }
}

