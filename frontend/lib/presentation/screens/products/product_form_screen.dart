import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../../data/models/product_model.dart';
import '../../widgets/image_delete_button.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productUuid;

  const ProductFormScreen({super.key, this.productUuid});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockQuantityController;
  late TextEditingController _unitController;
  int? _selectedCategoryId;
  bool _isActive = true;
  bool _isEditMode = false;
  final List<String> _selectedSizes = [];
  String _sizeMode = 'none'; // none | clothing | footwear | custom
  final _customSizeController = TextEditingController();

  static const _clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  static const _footwearSizes = ['4', '5', '6', '7', '8', '9', '10', '11', '12', '13'];

  final List<Uint8List> _selectedImages = [];
  final List<String> _selectedImageNames = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productUuid != null;
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _skuController = TextEditingController();
    _priceController = TextEditingController();
    _costPriceController = TextEditingController();
    _stockQuantityController = TextEditingController(text: '0');
    _unitController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false)
          .loadCategories(refresh: true);
      if (_isEditMode) {
        _loadProduct();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockQuantityController.dispose();
    _unitController.dispose();
    _customSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    await provider.loadProduct(widget.productUuid!);

    if (provider.currentProduct != null) {
      final product = provider.currentProduct!;
      setState(() {
        _nameController.text = product.name;
        _descriptionController.text = product.description ?? '';
        _skuController.text = product.sku ?? '';
        _priceController.text = product.price.toString();
        _costPriceController.text = product.costPrice?.toString() ?? '';
        _stockQuantityController.text = product.stockQuantity.toString();
        _unitController.text = product.unit ?? '';
        _selectedCategoryId = product.categoryId;
        _isActive = product.isActive;
        final loadedSizes = product.sizes ?? [];
        _selectedSizes..clear()..addAll(loadedSizes);
        if (loadedSizes.isNotEmpty) {
          final allClothing = loadedSizes.every(_clothingSizes.contains);
          final allFootwear = loadedSizes.every(_footwearSizes.contains);
          if (allClothing) _sizeMode = 'clothing';
          else if (allFootwear) _sizeMode = 'footwear';
          else _sizeMode = 'custom';
        }
      });
    }
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 images allowed')),
      );
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      for (var image in images) {
        if (_selectedImages.length < 10) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImages.add(bytes);
            _selectedImageNames.add(image.name);
          });
        }
      }
    }
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select images first')),
      );
      return;
    }

    if (!_isEditMode || widget.productUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please save the product first before uploading images')),
      );
      return;
    }

    final provider = Provider.of<ProductProvider>(context, listen: false);
    final success = await provider.uploadProductImages(
      widget.productUuid!,
      _selectedImages,
      _selectedImageNames,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Images uploaded successfully')),
        );
        setState(() {
          _selectedImages.clear();
          _selectedImageNames.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${provider.error}')),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<ProductProvider>(context, listen: false);
    bool success;

    if (_isEditMode) {
      final request = ProductUpdateRequest(
        name: _nameController.text.isNotEmpty ? _nameController.text : null,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        sku: _skuController.text.isNotEmpty ? _skuController.text : null,
        price: _priceController.text.isNotEmpty
            ? double.parse(_priceController.text)
            : null,
        costPrice: _costPriceController.text.isNotEmpty
            ? double.parse(_costPriceController.text)
            : null,
        stockQuantity: _stockQuantityController.text.isNotEmpty
            ? int.parse(_stockQuantityController.text)
            : null,
        unit: _unitController.text.isNotEmpty ? _unitController.text : null,
        categoryId: _selectedCategoryId,
        isActive: _isActive,
        sizes: _selectedSizes.isEmpty ? null : List.from(_selectedSizes),
      );
      success = await provider.updateProduct(widget.productUuid!, request);
    } else {
      final request = ProductCreateRequest(
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        sku: _skuController.text.isNotEmpty ? _skuController.text : null,
        price: double.parse(_priceController.text),
        costPrice: _costPriceController.text.isNotEmpty
            ? double.parse(_costPriceController.text)
            : null,
        stockQuantity: int.parse(_stockQuantityController.text),
        unit: _unitController.text.isNotEmpty ? _unitController.text : null,
        categoryId: _selectedCategoryId,
        isActive: _isActive,
        sizes: _selectedSizes.isEmpty ? null : List.from(_selectedSizes),
      );
      success = await provider.createProduct(request);

      // Auto-upload queued images right after product creation
      if (success && _selectedImages.isNotEmpty && provider.currentProduct != null) {
        final newUuid = provider.currentProduct!.uuid;
        final imagesCopy = List<Uint8List>.from(_selectedImages);
        final namesCopy = List<String>.from(_selectedImageNames);
        setState(() {
          _selectedImages.clear();
          _selectedImageNames.clear();
        });
        await provider.uploadProductImages(newUuid, imagesCopy, namesCopy);
      }
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Product updated successfully'
                : 'Product created successfully'),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${provider.error}')),
        );
      }
    }
  }

  String? _validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }
    final price = double.tryParse(value);
    if (price == null || price <= 0) {
      return 'Enter a valid price greater than 0';
    }
    return null;
  }

  String? _validateCostPrice(String? value) {
    if (value == null || value.isEmpty) return null;
    final costPrice = double.tryParse(value);
    if (costPrice == null || costPrice < 0) {
      return 'Enter a valid cost price';
    }
    return null;
  }

  String? _validateStockQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Stock quantity is required';
    }
    final stock = int.tryParse(value);
    if (stock == null || stock < 0) {
      return 'Enter a valid stock quantity';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: provider.isLoading ? null : _saveProduct,
          ),
        ],
      ),
      body: provider.isLoading && _isEditMode && provider.currentProduct == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Product Images — shown in both create and edit mode
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _isEditMode ? 'Product Images (Max 10)' : 'Product Images (optional, up to 10)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Existing Images (edit mode only)
                                if (_isEditMode && provider.currentProduct?.imageUrls != null)
                                  ...provider.currentProduct!.imageUrls!.map((url) => Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                                        ),
                                        PositionImageDeleteButton(onDelete: () {
                                          final newList = List<String>.from(provider.currentProduct!.imageUrls!);
                                          newList.remove(url);
                                          provider.updateProduct(widget.productUuid!, ProductUpdateRequest(imageUrls: newList));
                                        }),
                                      ],
                                    ),
                                  )),
                                // Newly Selected Images
                                ..._selectedImages.asMap().entries.map((entry) => Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                                      ),
                                      PositionImageDeleteButton(onDelete: () {
                                        setState(() {
                                          _selectedImages.removeAt(entry.key);
                                          _selectedImageNames.removeAt(entry.key);
                                        });
                                      }),
                                    ],
                                  ),
                                )),
                                // Add Button (up to 10 total)
                                if ((_isEditMode ? (provider.currentProduct?.imageUrls?.length ?? 0) : 0) + _selectedImages.length < 10)
                                  GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                                      ),
                                      child: const Icon(Icons.add_a_photo, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_isEditMode && _selectedImages.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: provider.isLoading ? null : _uploadImages,
                              icon: const Icon(Icons.upload),
                              label: Text('Upload ${_selectedImages.length} Images'),
                            ),
                          ],
                          if (!_isEditMode && _selectedImages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_selectedImages.length} image(s) selected — will upload after saving',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shopping_bag),
                      ),
                      validator: _validateRequired,
                    ),
                    const SizedBox(height: 16),
                    Consumer<CategoryProvider>(
                      builder: (context, categoryProvider, _) {
                        final categoryItems = [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No Category'),
                          ),
                          ...categoryProvider.categories
                              .where((c) => c.isActive)
                              .map((c) => DropdownMenuItem<int?>(
                                    value: c.id,
                                    child: Text(c.name),
                                  )),
                        ];
                        // Ensure _selectedCategoryId is valid in the current list
                        final validIds = categoryProvider.categories
                            .where((c) => c.isActive)
                            .map((c) => c.id)
                            .toSet();
                        final safeValue = (_selectedCategoryId != null && validIds.contains(_selectedCategoryId))
                            ? _selectedCategoryId
                            : null;
                        return DropdownButtonFormField<int?>(
                          value: safeValue,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: categoryItems,
                          onChanged: provider.isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                  });
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                        hintText: 'Stock Keeping Unit',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: _validatePrice,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Cost Price',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.price_change),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: _validateCostPrice,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockQuantityController,
                            decoration: const InputDecoration(
                              labelText: 'Stock Quantity *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _validateStockQuantity,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _UnitPicker(
                            value: _unitController.text,
                            onChanged: (v) => setState(() => _unitController.text = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ── Size / Variant Selection ───────────────────────────
                    _SizePicker(
                      mode: _sizeMode,
                      selected: _selectedSizes,
                      customController: _customSizeController,
                      onModeChanged: (m) => setState(() {
                        _sizeMode = m;
                        _selectedSizes.clear();
                      }),
                      onToggle: (s, val) => setState(() {
                        if (val) _selectedSizes.add(s);
                        else _selectedSizes.remove(s);
                      }),
                      onAddCustom: (s) => setState(() {
                        for (final part in s.split(',')) {
                          final v = part.trim();
                          if (v.isNotEmpty && !_selectedSizes.contains(v)) {
                            _selectedSizes.add(v);
                          }
                        }
                      }),
                      onRemoveCustom: (s) => setState(() => _selectedSizes.remove(s)),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active'),
                      subtitle: const Text('Product is available for sale'),
                      value: _isActive,
                      onChanged: provider.isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _isActive = value;
                              });
                            },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: provider.isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditMode
                              ? 'Update Product'
                              : 'Create Product'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Unit Picker ───────────────────────────────────────────────────────────────
class _UnitPicker extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _UnitPicker({required this.value, required this.onChanged});

  @override
  State<_UnitPicker> createState() => _UnitPickerState();
}

class _UnitPickerState extends State<_UnitPicker> {
  static const _groups = {
    'Count':  ['pcs', 'dozen', 'pair', 'set', 'box'],
    'Weight': ['g', '100g', '250g', '500g', 'kg', '5kg'],
    'Volume': ['ml', '200ml', '500ml', '1L', '2L', '5L'],
    'Length': ['cm', 'm'],
  };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: () => _showSheet(context, primary),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Unit',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.straighten),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          widget.value.isEmpty ? 'Select unit' : widget.value,
          style: TextStyle(
            color: widget.value.isEmpty ? Colors.grey : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UnitSheet(
        current: widget.value,
        groups: _groups,
        primary: primary,
        onSelect: (v) {
          widget.onChanged(v);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _UnitSheet extends StatefulWidget {
  final String current;
  final Map<String, List<String>> groups;
  final Color primary;
  final ValueChanged<String> onSelect;
  const _UnitSheet({required this.current, required this.groups, required this.primary, required this.onSelect});

  @override
  State<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<_UnitSheet> {
  late TextEditingController _custom;

  @override
  void initState() {
    super.initState();
    final presets = widget.groups.values.expand((e) => e).toSet();
    _custom = TextEditingController(
      text: presets.contains(widget.current) ? '' : widget.current,
    );
  }

  @override
  void dispose() { _custom.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Select Unit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...widget.groups.entries.map((g) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: g.value.map((u) {
                    final sel = widget.current == u;
                    return ChoiceChip(
                      label: Text(u),
                      selected: sel,
                      onSelected: (_) => widget.onSelect(u),
                      selectedColor: widget.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: sel ? widget.primary : Colors.black87,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            )),
            const Divider(),
            const SizedBox(height: 8),
            Text('Custom unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _custom,
                    decoration: const InputDecoration(
                      hintText: 'e.g. packet, roll, bottle...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.none,
                    onSubmitted: (v) { if (v.trim().isNotEmpty) widget.onSelect(v.trim()); },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final v = _custom.text.trim();
                    if (v.isNotEmpty) widget.onSelect(v);
                  },
                  child: const Text('Use'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Size / Variant Picker ─────────────────────────────────────────────────────
class _SizePicker extends StatelessWidget {
  final String mode;
  final List<String> selected;
  final TextEditingController customController;
  final ValueChanged<String> onModeChanged;
  final void Function(String, bool) onToggle;
  final ValueChanged<String> onAddCustom;
  final ValueChanged<String> onRemoveCustom;

  static const _clothing = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  static const _footwear = ['4', '5', '6', '7', '8', '9', '10', '11', '12', '13'];

  const _SizePicker({
    required this.mode,
    required this.selected,
    required this.customController,
    required this.onModeChanged,
    required this.onToggle,
    required this.onAddCustom,
    required this.onRemoveCustom,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sizes / Variants',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 4),
        const Text('Only needed for clothing, footwear, or items sold in multiple sizes',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),

        // Mode toggle
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ModeChip(label: 'None', icon: Icons.close, active: mode == 'none', primary: primary,
                  onTap: () => onModeChanged('none')),
              const SizedBox(width: 8),
              _ModeChip(label: 'Clothing', icon: Icons.checkroom, active: mode == 'clothing', primary: primary,
                  onTap: () => onModeChanged('clothing')),
              const SizedBox(width: 8),
              _ModeChip(label: 'Footwear', icon: Icons.directions_walk, active: mode == 'footwear', primary: primary,
                  onTap: () => onModeChanged('footwear')),
              const SizedBox(width: 8),
              _ModeChip(label: 'Custom', icon: Icons.edit, active: mode == 'custom', primary: primary,
                  onTap: () => onModeChanged('custom')),
            ],
          ),
        ),

        if (mode != 'none') ...[
          const SizedBox(height: 14),

          // Clothing sizes
          if (mode == 'clothing')
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _clothing.map((s) {
                final sel = selected.contains(s);
                return FilterChip(
                  label: Text(s),
                  selected: sel,
                  onSelected: (v) => onToggle(s, v),
                  selectedColor: primary.withValues(alpha: 0.15),
                  checkmarkColor: primary,
                );
              }).toList(),
            ),

          // Footwear sizes
          if (mode == 'footwear') ...[
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _footwear.map((s) {
                final sel = selected.contains(s);
                return FilterChip(
                  label: Text(s),
                  selected: sel,
                  onSelected: (v) => onToggle(s, v),
                  selectedColor: primary.withValues(alpha: 0.15),
                  checkmarkColor: primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customController,
                    decoration: const InputDecoration(
                      hintText: 'Add custom size (e.g. 13.5, 14)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.add, size: 18),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onSubmitted: (v) {
                      for (final p in v.split(',')) { final t = p.trim(); if (t.isNotEmpty) onAddCustom(t); }
                      customController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    for (final p in customController.text.split(',')) { final t = p.trim(); if (t.isNotEmpty) onAddCustom(t); }
                    customController.clear();
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],

          // Custom sizes
          if (mode == 'custom') ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 250ml, 500g, Small, Free Size...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.add, size: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (v) {
                      for (final p in v.split(',')) { final t = p.trim(); if (t.isNotEmpty) onAddCustom(t); }
                      customController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    for (final p in customController.text.split(',')) { final t = p.trim(); if (t.isNotEmpty) onAddCustom(t); }
                    customController.clear();
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: selected.map((s) => Chip(
                  label: Text(s),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => onRemoveCustom(s),
                  backgroundColor: primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
                )).toList(),
              ),
            ],
          ],

          // Show selected summary for clothing/footwear
          if (mode != 'custom' && selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Selected: ${selected.join(', ')}',
                style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600)),
          ],
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color primary;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.icon, required this.active, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? primary : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.grey.shade700,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}

