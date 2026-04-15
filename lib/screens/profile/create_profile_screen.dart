import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/profile/profile_service.dart';

class CreateProfileScreen extends StatefulWidget {
  final String? initialGender;
  
  const CreateProfileScreen({super.key, this.initialGender});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final PageController _pageController = PageController();
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  int _currentStep = 0;
  bool _isLoading = false;
  Gender? _selectedGender;

  @override
  void initState() {
    super.initState();
    // Initialize gender from registration screen if provided
    if (widget.initialGender != null) {
      _selectedGender = widget.initialGender == 'male' ? Gender.male : Gender.female;
    }
  }

  // Form controllers - Step 1: Basic Information
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // Step 2: Personal Details
  final TextEditingController _casteController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  MaritalStatus? _selectedMaritalStatus;

  // Step 3: Education & Career
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _monthlyIncomeController = TextEditingController();

  // Step 4: Contact & Address
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  // Step 5: Additional Attributes
  final TextEditingController _preferredPartnerController = TextEditingController();
  final TextEditingController _familyBackgroundController = TextEditingController();

  final List<String> _selectedHobbies = [];
  final List<String> _selectedTraits = [];
  SmokingHabit? _selectedSmoking;
  DrinkingHabit? _selectedDrinking;

  Uint8List? _profileImageBytes;
  String? _profileImageFileName;

  // Available options
  static const List<String> _availableHobbies = [
    'Reading',
    'Traveling',
    'Cooking',
    'Music',
    'Sports',
    'Photography',
    'Painting',
    'Dancing',
    'Gaming',
    'Writing',
    'Gardening',
    'Fitness',
    'Movies',
    'Shopping',
    'Volunteering',
  ];

  static const List<String> _availableTraits = [
    'Ambitious',
    'Caring',
    'Creative',
    'Dependable',
    'Empathetic',
    'Friendly',
    'Generous',
    'Honest',
    'Humorous',
    'Intelligent',
    'Kind',
    'Loyal',
    'Optimistic',
    'Patient',
    'Respectful',
    'Confident',
    'Adventurous',
    'Thoughtful',
  ];

  static final List<String> _maritalStatusLabels =
      MaritalStatus.values.map((e) => _formatEnum(e.toString())).toList();

  static final List<String> _smokingLabels =
      SmokingHabit.values.map((e) => _formatEnum(e.toString())).toList();

  static final List<String> _drinkingLabels =
      DrinkingHabit.values.map((e) => _formatEnum(e.toString())).toList();

  static String _formatEnum(String value) {
    final raw = value.split('.').last;
    return raw[0].toUpperCase() + raw.substring(1).replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        );
  }

  // Validation
  bool _validateStep(int step) {
    switch (step) {
      case 0: // Basic Information
        if (_fullNameController.text.trim().isEmpty) {
          _showSnackBar('Please enter your full name');
          return false;
        }
        if (_fatherNameController.text.trim().isEmpty) {
          _showSnackBar('Please enter your father\'s name');
          return false;
        }
        if (_motherNameController.text.trim().isEmpty) {
          _showSnackBar('Please enter your mother\'s name');
          return false;
        }
        if (_ageController.text.trim().isEmpty) {
          _showSnackBar('Please enter your age');
          return false;
        }
        final age = int.tryParse(_ageController.text.trim());
        if (age == null || age < 18 || age > 100) {
          _showSnackBar('Please enter a valid age (18-100)');
          return false;
        }
        return true;
      case 1: // Personal Details
        if (_casteController.text.trim().isEmpty) {
          _showSnackBar('Please enter your caste');
          return false;
        }
        if (_religionController.text.trim().isEmpty) {
          _showSnackBar('Please enter your religion');
          return false;
        }
        if (_selectedMaritalStatus == null) {
          _showSnackBar('Please select your marital status');
          return false;
        }
        return true;
      case 2: // Education & Career
        if (_qualificationController.text.trim().isEmpty) {
          _showSnackBar('Please enter your qualification');
          return false;
        }
        if (_professionController.text.trim().isEmpty) {
          _showSnackBar('Please enter your profession');
          return false;
        }
        return true;
      case 3: // Contact & Address
        if (_phoneController.text.trim().isEmpty) {
          _showSnackBar('Please enter your phone number');
          return false;
        }
        if (_cityController.text.trim().isEmpty) {
          _showSnackBar('Please enter your city');
          return false;
        }
        if (_countryController.text.trim().isEmpty) {
          _showSnackBar('Please enter your country');
          return false;
        }
        return true;
      case 4: // Additional
        if (_preferredPartnerController.text.trim().isEmpty) {
          _showSnackBar('Please describe your preferred partner criteria');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
          _profileImageFileName = image.name;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _submitProfile() async {
    if (!_validateStep(_currentStep)) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('User not authenticated. Please login again.');
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
        return;
      }

      print('===== SUBMIT PROFILE DEBUG =====');
      print('User ID: $userId');
      print('Email: ${Supabase.instance.client.auth.currentUser!.email}');
      print('Gender: $_selectedGender');
      print('Full Name: ${_fullNameController.text.trim()}');
      print('Father Name: ${_fatherNameController.text.trim()}');
      print('Age: ${_ageController.text.trim()}');
      print('City: ${_cityController.text.trim()}');
      print('Profession: ${_professionController.text.trim()}');
      print('Hobbies: $_selectedHobbies');
      print('Traits: $_selectedTraits');
      print('================================');

      String? profilePictureUrl;

      // Upload profile picture if selected
      if (_profileImageBytes != null && _profileImageFileName != null) {
        print('Uploading profile picture...');
        try {
          profilePictureUrl = await _profileService.uploadProfilePictureBytes(
            _profileImageBytes!,
            _profileImageFileName!,
            userId,
          );
          print('Profile picture URL: $profilePictureUrl');
        } catch (e) {
          print('⚠️ Profile picture upload failed: $e');
          print('⚠️ Continuing profile creation without picture...');
          // Continue without profile picture - user can upload later
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile picture upload failed: ${e.toString()}. You can upload it later from profile settings.'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      final now = DateTime.now();
      final profile = UserModel(
        id: userId,
        email: Supabase.instance.client.auth.currentUser!.email!,
        gender: _selectedGender,
        fullName: _fullNameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        profilePictureUrl: profilePictureUrl,
        caste: _casteController.text.trim(),
        religion: _religionController.text.trim(),
        maritalStatus: _selectedMaritalStatus,
        height: double.tryParse(_heightController.text.trim()),
        weight: double.tryParse(_weightController.text.trim()),
        qualification: _qualificationController.text.trim(),
        profession: _professionController.text.trim(),
        companyName: _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
        monthlyIncome: double.tryParse(_monthlyIncomeController.text.trim()),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        city: _cityController.text.trim(),
        area: _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        country: _countryController.text.trim(),
        hobbies: _selectedHobbies.isNotEmpty ? _selectedHobbies : null,
        personalityTraits: _selectedTraits.isNotEmpty ? _selectedTraits : null,
        preferredPartnerCriteria: _preferredPartnerController.text.trim(),
        smokingHabit: _selectedSmoking,
        drinkingHabit: _selectedDrinking,
        familyBackground: _familyBackgroundController.text.trim().isEmpty
            ? null
            : _familyBackgroundController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      print('Calling updateProfile...');
      await _profileService.updateProfile(profile);
      print('Profile update completed successfully!');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile created successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e, stackTrace) {
      print('❌ SUBMIT PROFILE FAILED: $e');
      print('Stack trace: $stackTrace');
      _showSnackBar('Failed to create profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < 4) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submitProfile();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _ageController.dispose();
    _casteController.dispose();
    _religionController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _qualificationController.dispose();
    _professionController.dispose();
    _companyNameController.dispose();
    _monthlyIncomeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _countryController.dispose();
    _preferredPartnerController.dispose();
    _familyBackgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitProfile,
            child: Text(
              _isLoading ? 'Saving...' : 'Skip',
              style: const TextStyle(color: AppColors.grey),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of 5',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / 5,
                          backgroundColor: AppColors.lightGrey,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // PageView for steps
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                _buildBasicInfoStep(theme),
                _buildPersonalDetailsStep(theme),
                _buildEducationCareerStep(theme),
                _buildContactAddressStep(theme),
                _buildAdditionalAttributesStep(theme),
              ],
            ),
          ),

          // Bottom navigation
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _previousStep,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: _currentStep == 0 ? 1 : 1,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _nextStep,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Icon(
                            _currentStep == 4 ? Icons.check : Icons.arrow_forward,
                          ),
                    label: Text(
                      _isLoading
                          ? 'Creating...'
                          : _currentStep == 4
                              ? 'Create Profile'
                              : 'Next',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Step indicators
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: 5,
              effect: ExpandingDotsEffect(
                activeDotColor: primaryColor,
                dotColor: AppColors.grey.withOpacity(0.3),
                dotHeight: 8,
                dotWidth: 8,
                expansionFactor: 3,
                spacing: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Basic Information
  Widget _buildBasicInfoStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about yourself',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Profile Picture Upload
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.lightGrey,
                    backgroundImage:
                        _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                    child: _profileImageBytes == null
                        ? Icon(
                            Icons.person_add,
                            size: 48,
                            color: AppColors.grey.withOpacity(0.5),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Tap to upload profile picture',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Full Name
          _buildTextField(
            controller: _fullNameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person,
          ),
          const SizedBox(height: 16),

          // Father's Name
          _buildTextField(
            controller: _fatherNameController,
            label: 'Father\'s Name',
            hint: 'Enter your father\'s name',
            icon: Icons.man,
          ),
          const SizedBox(height: 16),

          // Mother's Name
          _buildTextField(
            controller: _motherNameController,
            label: 'Mother\'s Name',
            hint: 'Enter your mother\'s name',
            icon: Icons.woman,
          ),
          const SizedBox(height: 16),

          // Age
          _buildTextField(
            controller: _ageController,
            label: 'Age',
            hint: 'Enter your age',
            icon: Icons.cake,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  // Step 2: Personal Details
  Widget _buildPersonalDetailsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Details',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help others understand your background',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Caste
          _buildTextField(
            controller: _casteController,
            label: 'Caste',
            hint: 'Enter your caste',
            icon: Icons.groups,
          ),
          const SizedBox(height: 16),

          // Religion
          _buildTextField(
            controller: _religionController,
            label: 'Religion',
            hint: 'Enter your religion',
            icon: Icons.temple_buddhist,
          ),
          const SizedBox(height: 16),

          // Marital Status
          Text(
            'Marital Status',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MaritalStatus.values.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isSelected = _selectedMaritalStatus == status;
              return ChoiceChip(
                label: Text(_maritalStatusLabels[index]),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedMaritalStatus = selected ? status : null;
                  });
                },
                selectedColor: theme.primaryColor.withOpacity(0.2),
                checkmarkColor: theme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? theme.primaryColor : AppColors.darkGrey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Height
          _buildTextField(
            controller: _heightController,
            label: 'Height (cm)',
            hint: 'e.g., 170',
            icon: Icons.height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // Weight
          _buildTextField(
            controller: _weightController,
            label: 'Weight (kg)',
            hint: 'e.g., 70',
            icon: Icons.monitor_weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }

  // Step 3: Education & Career
  Widget _buildEducationCareerStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Education & Career',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your professional background',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Qualification
          _buildTextField(
            controller: _qualificationController,
            label: 'Qualification',
            hint: 'e.g., Bachelor\'s, Master\'s, PhD',
            icon: Icons.school,
          ),
          const SizedBox(height: 16),

          // Profession
          _buildTextField(
            controller: _professionController,
            label: 'Profession',
            hint: 'e.g., Software Engineer, Doctor',
            icon: Icons.work,
          ),
          const SizedBox(height: 16),

          // Company Name
          _buildTextField(
            controller: _companyNameController,
            label: 'Company Name',
            hint: 'Enter your company name (optional)',
            icon: Icons.business,
          ),
          const SizedBox(height: 16),

          // Monthly Income
          _buildTextField(
            controller: _monthlyIncomeController,
            label: 'Monthly Income',
            hint: 'Enter your monthly income',
            icon: Icons.attach_money,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }

  // Step 4: Contact & Address
  Widget _buildContactAddressStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact & Address',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How can we reach you?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Phone Number
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'Enter your phone number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Address
          _buildTextField(
            controller: _addressController,
            label: 'Address',
            hint: 'Enter your full address (optional)',
            icon: Icons.location_on,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // City
          _buildTextField(
            controller: _cityController,
            label: 'City',
            hint: 'Enter your city',
            icon: Icons.location_city,
          ),
          const SizedBox(height: 16),

          // Area
          _buildTextField(
            controller: _areaController,
            label: 'Area',
            hint: 'Enter your area (optional)',
            icon: Icons.map,
          ),
          const SizedBox(height: 16),

          // Country
          _buildTextField(
            controller: _countryController,
            label: 'Country',
            hint: 'Enter your country',
            icon: Icons.public,
          ),
        ],
      ),
    );
  }

  // Step 5: Additional Attributes
  Widget _buildAdditionalAttributesStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Attributes',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us more about your personality and preferences',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Hobbies
          Text(
            'Hobbies',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableHobbies.map((hobby) {
              final isSelected = _selectedHobbies.contains(hobby);
              return FilterChip(
                label: Text(hobby),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedHobbies.add(hobby);
                    } else {
                      _selectedHobbies.remove(hobby);
                    }
                  });
                },
                selectedColor: theme.primaryColor.withOpacity(0.2),
                checkmarkColor: theme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? theme.primaryColor : AppColors.darkGrey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Personality Traits
          Text(
            'Personality Traits',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTraits.map((trait) {
              final isSelected = _selectedTraits.contains(trait);
              return FilterChip(
                label: Text(trait),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTraits.add(trait);
                    } else {
                      _selectedTraits.remove(trait);
                    }
                  });
                },
                selectedColor: theme.primaryColor.withOpacity(0.2),
                checkmarkColor: theme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? theme.primaryColor : AppColors.darkGrey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Preferred Partner Criteria
          _buildTextField(
            controller: _preferredPartnerController,
            label: 'Preferred Partner Criteria',
            hint: 'Describe what you\'re looking for in a partner',
            icon: Icons.favorite,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Lifestyle - Smoking
          Text(
            'Smoking Habit',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SmokingHabit.values.asMap().entries.map((entry) {
              final index = entry.key;
              final habit = entry.value;
              final isSelected = _selectedSmoking == habit;
              return ChoiceChip(
                label: Text(_smokingLabels[index]),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedSmoking = selected ? habit : null;
                  });
                },
                selectedColor: theme.primaryColor.withOpacity(0.2),
                checkmarkColor: theme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? theme.primaryColor : AppColors.darkGrey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Lifestyle - Drinking
          Text(
            'Drinking Habit',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DrinkingHabit.values.asMap().entries.map((entry) {
              final index = entry.key;
              final habit = entry.value;
              final isSelected = _selectedDrinking == habit;
              return ChoiceChip(
                label: Text(_drinkingLabels[index]),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedDrinking = selected ? habit : null;
                  });
                },
                selectedColor: theme.primaryColor.withOpacity(0.2),
                checkmarkColor: theme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? theme.primaryColor : AppColors.darkGrey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Family Background
          _buildTextField(
            controller: _familyBackgroundController,
            label: 'Family Background',
            hint: 'Tell us about your family (optional)',
            icon: Icons.family_restroom,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.grey),
            filled: true,
            fillColor: AppColors.lightGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
