# ethio_street_fix

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Product requirements (SRS)

2. Overall Description

2.1 Product Perspective

EthioStreetFix is a mobile cloud-based distributed system consisting of:

- Mobile client application (Flutter)
- Wireless communication networks (Wi‑Fi, 3G, 4G, 5G)
- Cloud backend services (application server and database)
- Web-based administrative dashboard

  2.2 Product Functions

• Secure user registration and authentication
• Street issue reporting with image and GPS location
• Secure data transmission over wireless networks
• Issue tracking and notification delivery
• Authority verification and issue resolution

2.3 User Classes and Characteristics

• Citizens: Mobile users reporting and tracking issues
• Municipal Authorities: Authorized users managing and resolving issues
• System Administrators: Users responsible for security, monitoring, and maintenance

2.4 Operating Environment

• Android OS (version 8.0 and above)
• Wireless and mobile networks
• Cloud infrastructure

2.5 Design and Implementation Constraints

• Variable network bandwidth and latency
• Security threats common to mobile and wireless networks
• Compliance with local data protection regulations

2.6 Assumptions and Dependencies

• Users possess smartphones with internet connectivity
• GPS and camera services are available
• Cloud services remain operational

3. System Features (Functional Requirements)

3.1 User Authentication and Authorization

• The system shall authenticate users securely over wireless networks.
• The system shall enforce role-based access control (RBAC) for citizens, authorities, and administrators.

3.2 Issue Reporting

• The system shall allow users to capture images using mobile device cameras.
• The system shall attach GPS-based location data to each report.
• The system shall encrypt data before transmission over wireless networks.

3.3 Issue Tracking

• The system shall allow users to track the status of submitted issues.
• The system shall notify users securely of any status updates.

3.4 Issue Management (Authority)

• Authorized personnel shall verify and update issue statuses.
• The system shall log all authority actions for audit purposes.

4. Data Requirements

• User identity and authentication data
• Issue reports (images, descriptions, location)
• Status update records
• Security logs and audit trails

5. System Architecture Overview

EthioStreetFix adopts a layered mobile cloud architecture: application layer (Flutter mobile app and web dashboard), communication layer (HTTPS/TLS), and backend layer (cloud servers). Security is implemented with a defense-in-depth approach.
