# Cloudinary Setup Guide

This guide will help you configure Cloudinary for image uploads in the Ethio Street Fix application.

## Prerequisites

1. Create a free account at [Cloudinary](https://cloudinary.com/)
2. Sign up and verify your email address

## Getting Your Cloudinary Credentials

1. Log in to your [Cloudinary Console](https://console.cloudinary.com/)
2. On the dashboard, you'll find your credentials:
   - **Cloud Name**: Displayed at the top of the dashboard
   - **API Key**: Found in the "Account Details" section
   - **API Secret**: Found in the "Account Details" section (click "Reveal" to see it)

## Setting Up Upload Preset (Recommended)

For client-side uploads, it's recommended to use an unsigned upload preset:

1. Go to [Upload Settings](https://console.cloudinary.com/settings/upload)
2. Scroll down to "Upload presets"
3. Click "Add upload preset"
4. Configure the preset:
   - **Preset name**: Choose a name (e.g., `ethio_street_fix_unsigned`)
   - **Signing mode**: Select "Unsigned"
   - **Folder**: Set to `ethio_street_fix/reports` (optional, for organization)
   - **Upload manipulation**: You can add transformations here if needed
5. Click "Save"

## Configuring the Application

1. Open `lib/services/cloudinary_service.dart`
2. Replace the placeholder values with your actual credentials:

```dart
static const String _cloudName = 'your_actual_cloud_name';
static const String _apiKey = 'your_actual_api_key';
static const String _apiSecret = 'your_actual_api_secret';
static const String _uploadPreset = 'your_upload_preset_name';
```

## Security Best Practices

⚠️ **Important**: For production applications, consider:

1. **Using Environment Variables**: Store credentials in environment variables or a secure configuration file
2. **Server-Side Upload**: For better security, implement server-side uploads using Cloudinary's server SDKs
3. **Upload Presets**: Use unsigned upload presets for client-side uploads (as configured above)
4. **API Secret**: Never expose your API secret in client-side code. Only use it for server-side operations like deletion.

## Testing

After configuration:

1. Run `flutter pub get` to install dependencies
2. Test image upload by creating a new report
3. Check your Cloudinary Media Library to verify the upload

## Troubleshooting

### Upload Fails
- Verify your credentials are correct
- Check that the upload preset is set to "Unsigned"
- Ensure you have internet connectivity

### Image Deletion Fails
- Image deletion requires the API secret
- For production, consider implementing server-side deletion
- Check that the image URL is a valid Cloudinary URL

## Additional Resources

- [Cloudinary Documentation](https://cloudinary.com/documentation)
- [Flutter Image Upload Guide](https://cloudinary.com/documentation/flutter_image_upload)
- [Upload Presets Guide](https://cloudinary.com/documentation/upload_presets)
