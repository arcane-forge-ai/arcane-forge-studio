import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/image_generation_provider.dart';
import '../../../models/image_generation_models.dart';
import '../../../responsive.dart';

class ParametersPanelWidget extends StatelessWidget {
  final ImageAsset? selectedAsset;
  final List<ImageAsset> availableAssets;
  final String selectedModel;
  final String selectedModelFallbackValue;
  final String selectedSampler;
  final String selectedScheduler;
  final bool isSeedLocked;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController stepsController;
  final TextEditingController cfgController;
  final TextEditingController seedController;
  final TextEditingController batchCountController;
  final Function(ImageAsset?) onAssetChanged;
  final Function(String) onModelChanged;
  final Function(String) onSamplerChanged;
  final Function(String) onSchedulerChanged;
  final VoidCallback onSeedLockToggle;
  final VoidCallback onRandomizeSeed;
  final VoidCallback onCreateAsset;
  final VoidCallback onViewAssetMetadata;
  final VoidCallback onAskForModelRecommendation;

  const ParametersPanelWidget({
    Key? key,
    required this.selectedAsset,
    required this.availableAssets,
    required this.selectedModel,
    required this.selectedModelFallbackValue,
    required this.selectedSampler,
    required this.selectedScheduler,
    required this.isSeedLocked,
    required this.widthController,
    required this.heightController,
    required this.stepsController,
    required this.cfgController,
    required this.seedController,
    required this.batchCountController,
    required this.onAssetChanged,
    required this.onModelChanged,
    required this.onSamplerChanged,
    required this.onSchedulerChanged,
    required this.onSeedLockToggle,
    required this.onRandomizeSeed,
    required this.onCreateAsset,
    required this.onViewAssetMetadata,
    required this.onAskForModelRecommendation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generation Parameters',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildAssetSelection(context),
            const SizedBox(height: 20),
            _buildModelSelection(context),
            const SizedBox(height: 20),
            _buildDimensionsSection(context),
            const SizedBox(height: 20),
            _buildQualitySection(context),
            const SizedBox(height: 20),
            _buildSeedSection(context),
            const SizedBox(height: 20),
            _buildBatchSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Target Asset',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreateAsset,
              icon: const Icon(Icons.add, color: Colors.blue, size: 16),
              label: const Text(
                'New Asset',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            if (selectedAsset != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onViewAssetMetadata,
                icon: const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                tooltip: 'View Asset Metadata',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Color(0xFF404040)),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3A3A3A)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedAsset == null
                  ? Colors.red.withOpacity(0.5)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF404040)
                      : Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ImageAsset?>(
              value: selectedAsset,
              hint: Text(
                'Select an asset...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A)
                  : Colors.grey.shade200,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: [
                const DropdownMenuItem<ImageAsset?>(
                  value: null,
                  child: Text(
                    'Select an asset...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ...availableAssets.map((asset) {
                  return DropdownMenuItem<ImageAsset?>(
                    value: asset,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          asset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (asset.description.isNotEmpty)
                          Text(
                            asset.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: onAssetChanged,
            ),
          ),
        ),
        if (selectedAsset != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: Colors.blue.withOpacity(0.7),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAsset!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (selectedAsset!.description.isNotEmpty)
                        Text(
                          selectedAsset!.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${selectedAsset!.generations.length} images',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (selectedAsset == null) ...[
          const SizedBox(height: 4),
          const Text(
            'Please select an asset to organize your generated images',
            style: TextStyle(
              color: Colors.red,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelSelection(BuildContext context) {
    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        List<String> models;
        bool useA1111Models = provider.currentBackendName == 'Automatic1111' &&
            provider.isA1111ServerReachable &&
            provider.a1111Checkpoints.isNotEmpty;

        if (useA1111Models) {
          models = provider.a1111Checkpoints.map((c) => c.title).toList();
        } else {
          models = provider.availableModels;
        }

        List<String> loras;
        String loraDropdownLabel;
        bool useA1111Loras = provider.currentBackendName == 'Automatic1111' &&
            provider.isA1111ServerReachable &&
            provider.a1111Loras.isNotEmpty;

        if (useA1111Loras) {
          loras = provider.a1111Loras.map((l) => l.name).toList();
          loraDropdownLabel = 'Click on a LoRA to add to prompt';
        } else {
          loras = provider.availableLoras;
          loraDropdownLabel = loras.isEmpty ? 'No LoRAs found' : 'Click on a LoRA to add to prompt';
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDropdownWithLabel(
                    context,
                    "Model",
                    selectedModel,
                    models.isNotEmpty ? models : [selectedModel],
                    (value) {
                      if (value != null && value != selectedModel) {
                        onModelChanged(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: provider.isLoadingA1111Models
                      ? null
                      : () async {
                          if (provider.currentBackendName == 'Automatic1111') {
                            await provider.refreshA1111Models();
                          } else {
                            await provider.refreshAvailableModels();
                          }
                        },
                  icon: provider.isLoadingA1111Models
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Colors.white54),
                  tooltip: 'Refresh Models',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildLoraDropdown(
                    context,
                    loraDropdownLabel,
                    loras,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: provider.isLoadingA1111Models
                      ? null
                      : () async {
                          if (provider.currentBackendName == 'Automatic1111') {
                            await provider.refreshA1111Models();
                          } else {
                            await provider.refreshAvailableLoras();
                          }
                        },
                  icon: provider.isLoadingA1111Models
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Colors.white54),
                  tooltip: 'Refresh LoRAs',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAskForModelRecommendation,
                icon: const Icon(Icons.psychology, color: Colors.white, size: 18),
                label: const Text(
                  'Ask AI for Model & LoRA Recommendations',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (provider.currentBackendName == 'Automatic1111' && !provider.isA1111ServerReachable)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A1111 server not reachable. Using local model list.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLoraDropdown(BuildContext context, String label, List<String> loras) {
    // This requires access to positive prompt controller, which we need to handle via callback
    return _buildDropdownWithLabel(
      context,
      "LoRA",
      label,
      [label] + loras,
      (value) {
        // LoRA adding logic will be handled in parent
        // We'll need to expose this via callback
      },
    );
  }

  Widget _buildDimensionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dimensions',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNumberField(context, 'Width', widthController),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberField(context, 'Height', heightController),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQualitySection(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quality',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (isMobile) ...[
          _buildDropdownWithLabel(
            context,
            "Sampler",
            selectedSampler,
            ['Euler a', 'Euler', 'heun', 'dpm_2', 'dpm_2_a', 'lms', 'ddim', 'plms'],
            (value) {
              if (value != null) {
                onSamplerChanged(value);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDropdownWithLabel(
            context,
            "Scheduler",
            selectedScheduler,
            ['Automatic', 'euler_a', 'heun', 'dpm_2', 'dpm_2_a', 'lms', 'ddim', 'plms'],
            (value) {
              if (value != null) {
                onSchedulerChanged(value);
              }
            },
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _buildDropdownWithLabel(
                  context,
                  "Sampler",
                  selectedSampler,
                  ['Euler a', 'Euler', 'heun', 'dpm_2', 'dpm_2_a', 'lms', 'ddim', 'plms'],
                  (value) {
                    if (value != null) {
                      onSamplerChanged(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdownWithLabel(
                  context,
                  "Scheduler",
                  selectedScheduler,
                  ['Automatic', 'euler_a', 'heun', 'dpm_2', 'dpm_2_a', 'lms', 'ddim', 'plms'],
                  (value) {
                    if (value != null) {
                      onSchedulerChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        if (isMobile) ...[
          _buildNumberField(context, 'Steps', stepsController),
          const SizedBox(height: 12),
          _buildNumberField(context, 'CFG Scale', cfgController),
        ] else
          Row(
            children: [
              Expanded(child: _buildNumberField(context, 'Steps', stepsController)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumberField(context, 'CFG Scale', cfgController)),
            ],
          )
      ],
    );
  }

  Widget _buildSeedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Seed',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onRandomizeSeed,
              child: const Text(
                'Random',
                style: TextStyle(color: Color(0xFF0078D4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Seed'),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: seedController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Seed',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3A3A3A)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0078D4)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onSeedLockToggle,
              icon: Icon(
                isSeedLocked ? Icons.lock : Icons.lock_open,
                color: isSeedLocked ? Colors.amber : Colors.white54,
              ),
              tooltip: isSeedLocked ? 'Unlock seed (auto-randomize)' : 'Lock seed (keep current)',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatchSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Batch Generation',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Count'),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: batchCountController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Number of images to generate',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3A3A3A)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0078D4)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Each image will use a different random seed',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownWithLabel(
    BuildContext context,
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF404040)
                    : Colors.grey.shade400,
              ),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A)
                  : Colors.grey.shade100,
              underline: Container(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: items
                  .map((item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(BuildContext context, String label, TextEditingController controller) {
    return Row(
      children: [
        Text(label),
        SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A)
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF404040)
                      : Colors.grey.shade400,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF404040)
                      : Colors.grey.shade400,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0078D4)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

