enum CropType {
  carrot,
  tomato,
  pumpkin,
}

enum CropStage {
  empty,
  planted,
  growing,
  mature,
}

class Crop {
  final CropType type;
  final List<int> cost;
  final int reward;
  final String displayName;
  final String icon;

  const Crop({
    required this.type,
    required this.cost,
    required this.reward,
    required this.displayName,
    required this.icon,
  });

  static const Map<CropType, Crop> crops = {
    CropType.carrot: Crop(
      type: CropType.carrot,
      cost: [3, 4, 5],
      reward: 15,
      displayName: '당근',
      icon: '🥕',
    ),
    CropType.tomato: Crop(
      type: CropType.tomato,
      cost: [5, 6, 8],
      reward: 25,
      displayName: '토마토',
      icon: '🍅',
    ),
    CropType.pumpkin: Crop(
      type: CropType.pumpkin,
      cost: [7, 9, 12],
      reward: 35,
      displayName: '호박',
      icon: '🎃',
    ),
  };

  static Crop? getCrop(CropType type) => crops[type];
  static Crop? getCropById(String cropId) {
    switch (cropId) {
      case 'carrot':
        return crops[CropType.carrot];
      case 'tomato':
        return crops[CropType.tomato];
      case 'pumpkin':
        return crops[CropType.pumpkin];
      default:
        return null;
    }
  }

  String get id => type.name;
  
  int getCostForStage(CropStage stage) {
    switch (stage) {
      case CropStage.planted:
        return cost[0];
      case CropStage.growing:
        return cost[1];
      case CropStage.mature:
        return cost[2];
      default:
        return 0;
    }
  }
}

class GardenTile {
  final int x;
  final int y;
  final CropStage stage;
  final CropType? cropType;

  const GardenTile({
    required this.x,
    required this.y,
    required this.stage,
    this.cropType,
  });

  bool get isEmpty => stage == CropStage.empty;
  bool get canPlant => stage == CropStage.empty;
  bool get canProgress => stage == CropStage.planted || stage == CropStage.growing;
  bool get canHarvest => stage == CropStage.mature;

  Crop? get crop => cropType != null ? Crop.getCrop(cropType!) : null;

  GardenTile copyWith({
    int? x,
    int? y,
    CropStage? stage,
    CropType? cropType,
  }) {
    return GardenTile(
      x: x ?? this.x,
      y: y ?? this.y,
      stage: stage ?? this.stage,
      cropType: cropType ?? this.cropType,
    );
  }

  factory GardenTile.fromJson(Map<String, dynamic> json, int x, int y) {
    final stageValue = json['stage'];
    final cropId = json['cropId'] as String?;
    
    CropStage stage = CropStage.empty;
    CropType? cropType;

    // stage가 숫자 또는 문자열일 수 있음
    if (stageValue != null) {
      if (stageValue is int) {
        switch (stageValue) {
          case 0:
            stage = CropStage.empty;
            break;
          case 1:
            stage = CropStage.planted;
            break;
          case 2:
            stage = CropStage.growing;
            break;
          case 3:
            stage = CropStage.mature;
            break;
          default:
            stage = CropStage.empty;
        }
      } else if (stageValue is String) {
        switch (stageValue) {
          case 'empty':
            stage = CropStage.empty;
            break;
          case 'planted':
            stage = CropStage.planted;
            break;
          case 'growing':
            stage = CropStage.growing;  
            break;
          case 'mature':
            stage = CropStage.mature;
            break;
          default:
            stage = CropStage.empty;
        }
      }
    }

    if (cropId != null) {
      switch (cropId) {
        case 'carrot':
          cropType = CropType.carrot;
          break;
        case 'tomato':
          cropType = CropType.tomato;
          break;
        case 'pumpkin':
          cropType = CropType.pumpkin;
          break;
      }
    }

    return GardenTile(
      x: x,
      y: y,
      stage: stage,
      cropType: cropType,
    );
  }
}

class Garden {
  final int size;
  final List<List<GardenTile>> tiles;
  final int playerPoints;

  const Garden({
    required this.size,
    required this.tiles,
    required this.playerPoints,
  });

  factory Garden.fromJson(Map<String, dynamic> json) {
    print('=== Garden.fromJson DEBUG ===');
    print('Raw JSON: $json');
    print('size field: ${json['size']} (type: ${json['size'].runtimeType})');
    print('point field: ${json['point']} (type: ${json['point'].runtimeType})');
    
    // 안전한 타입 변환
    final size = _safeInt(json['size']) ?? 3;
    final playerPoints = _safeInt(json['point']) ?? 0;
    final tilesData = json['tiles'] as Map<String, dynamic>? ?? {};
    
    print('Converted size: $size, points: $playerPoints');
    print('=============================');

    List<List<GardenTile>> tiles = List.generate(
      size,
      (y) => List.generate(
        size,
        (x) {
          final tileKey = '$x,$y';
          final tileData = tilesData[tileKey] as Map<String, dynamic>?;
          
          if (tileData != null) {
            return GardenTile.fromJson(tileData, x, y);
          } else {
            return GardenTile(x: x, y: y, stage: CropStage.empty);
          }
        },
      ),
    );

    return Garden(
      size: size,
      tiles: tiles,
      playerPoints: playerPoints,
    );
  }

  GardenTile getTile(int x, int y) {
    if (x < 0 || x >= size || y < 0 || y >= size) {
      return GardenTile(x: x, y: y, stage: CropStage.empty);
    }
    return tiles[y][x];
  }
}

const LEAGUE_TO_SIZE = [3, 3, 4, 5, 6];

int getGardenSizeForLeague(int leagueLevel) {
  if (leagueLevel < 0 || leagueLevel >= LEAGUE_TO_SIZE.length) {
    return LEAGUE_TO_SIZE[0];
  }
  return LEAGUE_TO_SIZE[leagueLevel];
}

// 안전한 int 변환 헬퍼 함수
int? _safeInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}