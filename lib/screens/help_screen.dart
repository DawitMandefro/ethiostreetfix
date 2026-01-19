import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Help & Feedback'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Help & Feedback',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you found a bug or want to suggest an improvement, please send an email to:',
            ),
            const SizedBox(height: 8),
            SelectableText(
              'support@ethiostreetfix.example',
              style: TextStyle(color: Colors.blue),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.feedback_outlined),
              label: const Text('Send feedback (opens email)'),
              onPressed: () {
                // keep lightweight: launch email handled elsewhere; placeholder for now
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Open your mail client to send feedback'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Frequently asked questions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Q: How do I report an issue?\nA: Tap Report → take/attach photo → submit.',
            ),
          ],
        ),
      ),
    );
  }
}
