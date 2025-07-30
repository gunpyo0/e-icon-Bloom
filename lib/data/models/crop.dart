enum CropType { carrot, tomato, pumpkin }

enum CropStage { empty, planted, growing, mature }

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
  bool get canProgress =>
      stage == CropStage.planted || stage == CropStage.growing;
  bool get canHarvest => stage == CropStage.mature;

  Crop? get crop => cropType != null ? Crop.getCrop(cropType!) : null;

  GardenTile copyWith({int? x, int? y, CropStage? stage, CropType? cropType}) {
    return GardenTile(
      x: x ?? this.x,
      y: y ?? this.y,
      stage: stage ?? this.stage,
      cropType: cropType ?? this.cropType,
    );
  }

  factory GardenTile.fromJson(Map<String, dynamic> json, int x, int y) {
    final stageStr = json['stage'] as double?;
    final cropId = json['cropId'] as String?;

    CropStage stage = CropStage.empty;
    CropType? cropType;

    if (stageStr != null) {
      switch (stageStr) {
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

    return GardenTile(x: x, y: y, stage: stage, cropType: cropType);
  }
}

class Garden {
  final int size;
  final List<List<GardenTile>> tiles;
  final int playerCoins;

  const Garden({
    required this.size,
    required this.tiles,
    required this.playerCoins,
  });

  factory Garden.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int? ?? 3;
    final playerCoins = json['playerCoins'] as int? ?? 0;
    final tilesData = json['tiles'] as Map<String, dynamic>? ?? {};

    List<List<GardenTile>> tiles = List.generate(
      size,
      (y) => List.generate(size, (x) {
        final tileKey = '$x,$y';
        final tileData = tilesData[tileKey] as Map<String, dynamic>?;

        if (tileData != null) {
          return GardenTile.fromJson(tileData, x, y);
        } else {
          return GardenTile(x: x, y: y, stage: CropStage.empty);
        }
      }),
    );

    return Garden(size: size, tiles: tiles, playerCoins: playerCoins);
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
