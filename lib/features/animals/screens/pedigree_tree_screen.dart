import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/animal_model.dart';
import '../../../data/repositories/animal_repository.dart';
import '../../../shared/providers/providers.dart';
import 'add_edit_animal_screen.dart';
import '../../settings/screens/subscription_paywall_screen.dart';

class PedigreeTreeScreen extends ConsumerStatefulWidget {
  final Animal animal;

  const PedigreeTreeScreen({super.key, required this.animal});

  @override
  ConsumerState<PedigreeTreeScreen> createState() => _PedigreeTreeScreenState();
}

class _PedigreeTreeScreenState extends ConsumerState<PedigreeTreeScreen> {
  Map<String, dynamic>? _pedigreeData;
  final _transformationController = TransformationController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Default initial zoom and offset to frame the pedigree nicely
    _transformationController.value = Matrix4.translationValues(20.0, 45.0, 0.0)
      ..multiply(Matrix4.diagonal3Values(0.75, 0.75, 1.0));
    _loadPedigreeTree();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadPedigreeTree() async {
    setState(() {
      _isLoading = true;
    });
    final repo = ref.read(animalRepositoryProvider);
    final tree = await _buildPedigreeNode(repo, widget.animal, 1);
    if (mounted) {
      setState(() {
        _pedigreeData = tree;
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _buildPedigreeNode(
      AnimalRepository repo, Animal animal, int depth) async {
    if (depth > 3) return null;

    Map<String, dynamic>? sireNode;
    Animal? sire;
    if (animal.sireId != null) {
      sire = await repo.getAnimalById(animal.sireId!);
    } else {
      if (animal.sireRegNumber != null && animal.sireRegNumber!.isNotEmpty) {
        sire = await repo.getAnimalByNkrRegNumberCaseInsensitive(animal.sireRegNumber!);
      }
      if (sire == null && animal.sireName != null && animal.sireName!.isNotEmpty) {
        sire = await repo.getAnimalByNameCaseInsensitive(animal.sireName!);
      }
    }

    if (sire != null) {
      sireNode = await _buildPedigreeNode(repo, sire, depth + 1);
    } else if (animal.sireName != null || animal.sireRegNumber != null) {
      final mockSire = Animal(
        name: animal.sireName ?? 'Unknown Sire',
        nkrRegNumber: animal.sireRegNumber,
        sex: Sex.buck,
        status: AnimalStatus.ancestor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      sireNode = {'self': mockSire};
    }

    Map<String, dynamic>? damNode;
    Animal? dam;
    if (animal.damId != null) {
      dam = await repo.getAnimalById(animal.damId!);
    } else {
      if (animal.damRegNumber != null && animal.damRegNumber!.isNotEmpty) {
        dam = await repo.getAnimalByNkrRegNumberCaseInsensitive(animal.damRegNumber!);
      }
      if (dam == null && animal.damName != null && animal.damName!.isNotEmpty) {
        dam = await repo.getAnimalByNameCaseInsensitive(animal.damName!);
      }
    }

    if (dam != null) {
      damNode = await _buildPedigreeNode(repo, dam, depth + 1);
    } else if (animal.damName != null || animal.damRegNumber != null) {
      final mockDam = Animal(
        name: animal.damName ?? 'Unknown Dam',
        nkrRegNumber: animal.damRegNumber,
        sex: Sex.doe,
        status: AnimalStatus.ancestor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      damNode = {'self': mockDam};
    }

    return {
      'self': animal,
      'sire': sireNode,
      'dam': damNode,
    };
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.translationValues(20.0, 45.0, 0.0)
        ..multiply(Matrix4.diagonal3Values(0.75, 0.75, 1.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double nodeWidth = 200.0;
    const double nodeHeight = 75.0;
    const double columnSpacing = 55.0;
    const double rowSpacing = 16.0;

    const double canvasWidth = 3 * (nodeWidth + columnSpacing) - columnSpacing;
    const double canvasHeight = 4 * (nodeHeight + rowSpacing) - rowSpacing;

    Animal? getAnimalAtPath(List<String> path) {
      Map<String, dynamic>? current = _pedigreeData;
      for (final step in path) {
        if (current == null) return null;
        current = current[step] as Map<String, dynamic>?;
      }
      return current?['self'] as Animal?;
    }

    List<String> getPathForNode(int L, int i) {
      final path = <String>[];
      for (int step = L - 1; step >= 0; step--) {
        final bit = (i >> step) & 1;
        path.add(bit == 0 ? 'sire' : 'dam');
      }
      return path;
    }

    double getCenterLeafIndex(int L, int i) {
      final blockSize = 4 >> L;
      final startLeaf = i * blockSize;
      final endLeaf = startLeaf + blockSize - 1;
      return (startLeaf + endLeaf) / 2.0;
    }

    double getY(int L, int i) {
      return getCenterLeafIndex(L, i) * (nodeHeight + rowSpacing);
    }

    String getRoleLabel(int L, int i) {
      if (L == 0) return 'Target';
      if (L == 1) return i == 0 ? 'Sire' : 'Dam';
      if (L == 2) {
        final side = i < 2 ? 'Pat.' : 'Mat.';
        return i % 2 == 0 ? 'Grandsire ($side)' : 'Granddam ($side)';
      }
      final isMale = i % 2 == 0;
      if (L == 3) return isMale ? 'G-Grandsire' : 'G-Granddam';
      return isMale ? 'GG-Grandsire' : 'GG-Granddam';
    }

    Widget nodeCard(Animal? animal, int L, int i) {
      final role = getRoleLabel(L, i);
      final isMale = i % 2 == 0 || (L == 0 && animal?.sex == Sex.buck);

      if (animal == null) {
        return Container(
          width: nodeWidth,
          height: nodeHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border.all(
              color: isDark ? Colors.grey[850] ?? Colors.grey : Colors.grey.shade300,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 7.5,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unknown',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      }

      final isLinkable = animal.id != null;
      final isTarget = animal.id == widget.animal.id;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLinkable
              ? () async {
                  // Push the edit animal screen. If changes occur, refresh our tree on pop.
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditAnimalScreen(animal: animal),
                    ),
                  );
                  _loadPedigreeTree();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: nodeWidth,
            height: nodeHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? (isTarget
                      ? Colors.green[950]?.withValues(alpha: 0.5)
                      : (isMale ? Colors.blue[950]?.withValues(alpha: 0.5) : Colors.pink[950]?.withValues(alpha: 0.5)))
                  : (isTarget
                      ? Colors.green[50]
                      : (isMale ? Colors.blue[50] : Colors.pink[50])),
              border: Border.all(
                color: isTarget
                    ? (isDark ? Colors.green.shade700 : Colors.green.shade400)
                    : (isMale
                        ? (isDark ? Colors.blue.shade800 : Colors.blue.shade300)
                        : (isDark ? Colors.pink.shade800 : Colors.pink.shade300)),
                width: isTarget ? 2 : 1.2,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 7.5,
                        color: isTarget
                            ? (isDark ? Colors.green[300] : Colors.green[800])
                            : (isMale
                                ? (isDark ? Colors.blue[300] : Colors.blue[800])
                                : (isDark ? Colors.pink[300] : Colors.pink[800])),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isLinkable)
                      Icon(
                        Icons.open_in_new,
                        size: 9,
                        color: isTarget
                            ? (isDark ? Colors.green[300] : Colors.green[700])
                            : (isMale
                                ? (isDark ? Colors.blue[300] : Colors.blue[700])
                                : (isDark ? Colors.pink[300] : Colors.pink[700])),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  animal.name,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (animal.nkrRegNumber != null && animal.nkrRegNumber!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    '${animal.registry ?? 'Reg'}: ${animal.nkrRegNumber}',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final nodesList = <Widget>[];
    if (_pedigreeData != null) {
      for (int L = 0; L <= 2; L++) {
        final numNodes = 1 << L;
        for (int i = 0; i < numNodes; i++) {
          final path = getPathForNode(L, i);
          final animal = getAnimalAtPath(path);

          final x = L * (nodeWidth + columnSpacing);
          final y = getY(L, i);

          nodesList.add(
            Positioned(
              left: x,
              top: y,
              child: nodeCard(animal, L, i),
            ),
          );
        }
      }
    }

    final settings = ref.watch(settingsStateProvider);
    final isPremium = settings['is_premium'] == 'true';
    if (!isPremium) {
      return SubscriptionPaywallScreen(
        onDismiss: () => Navigator.pop(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.animal.name} Pedigree',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.animal.nkrRegNumber != null && widget.animal.nkrRegNumber!.isNotEmpty)
              Text(
                '${widget.animal.registry ?? 'Reg'}: ${widget.animal.nkrRegNumber}${widget.animal.secondRegNumber != null ? ' | ${widget.animal.secondRegistry ?? 'Reg 2'}: ${widget.animal.secondRegNumber}' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Reset View / Center',
            onPressed: _resetZoom,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Pedigree',
            onPressed: _loadPedigreeTree,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: isDark ? Colors.grey[950] : Colors.grey[50],
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: isDark ? Colors.green[900]?.withValues(alpha: 0.15) : Colors.green[800]?.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pinch, size: 14, color: isDark ? Colors.green[300] : Colors.green[800]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pinch to zoom. Drag to pan. Click nodes with ↗ to inspect or edit details.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.green[200] : Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(350),
                        minScale: 0.1,
                        maxScale: 2.0,
                        transformationController: _transformationController,
                        child: SizedBox(
                          width: canvasWidth,
                          height: canvasHeight,
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: Size(canvasWidth, canvasHeight),
                                painter: PedigreeConnectorPainter(
                                  nodeWidth: nodeWidth,
                                  nodeHeight: nodeHeight,
                                  columnSpacing: columnSpacing,
                                  rowSpacing: rowSpacing,
                                ),
                              ),
                              ...nodesList,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class PedigreeConnectorPainter extends CustomPainter {
  final double nodeWidth;
  final double nodeHeight;
  final double columnSpacing;
  final double rowSpacing;

  PedigreeConnectorPainter({
    required this.nodeWidth,
    required this.nodeHeight,
    required this.columnSpacing,
    required this.rowSpacing,
  });

  double _getCenterLeafIndex(int L, int i) {
    final blockSize = 4 >> L;
    final startLeaf = i * blockSize;
    final endLeaf = startLeaf + blockSize - 1;
    return (startLeaf + endLeaf) / 2.0;
  }

  double _getY(int L, int i) {
    return _getCenterLeafIndex(L, i) * (nodeHeight + rowSpacing);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    for (int L = 0; L < 2; L++) {
      final numNodes = 1 << L;
      for (int i = 0; i < numNodes; i++) {
        final xStart = L * (nodeWidth + columnSpacing) + nodeWidth;
        final yStart = _getY(L, i) + nodeHeight / 2.0;

        final xEnd = (L + 1) * (nodeWidth + columnSpacing);
        final ySire = _getY(L + 1, 2 * i) + nodeHeight / 2.0;
        final yDam = _getY(L + 1, 2 * i + 1) + nodeHeight / 2.0;

        final xMid = xStart + columnSpacing / 2.0;

        final path = Path()
          ..moveTo(xStart, yStart)
          ..lineTo(xMid, yStart)
          ..moveTo(xMid, ySire)
          ..lineTo(xMid, yDam)
          ..moveTo(xMid, ySire)
          ..lineTo(xEnd, ySire)
          ..moveTo(xMid, yDam)
          ..lineTo(xEnd, yDam);

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PedigreeConnectorPainter oldDelegate) {
    return oldDelegate.nodeWidth != nodeWidth ||
        oldDelegate.nodeHeight != nodeHeight ||
        oldDelegate.columnSpacing != columnSpacing ||
        oldDelegate.rowSpacing != rowSpacing;
  }
}
