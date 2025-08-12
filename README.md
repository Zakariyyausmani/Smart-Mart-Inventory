# Smart Mart (Inventory Management System)

Manage your products, track stocks, and easily monitor sales with an efficient inventory management system designed specifically for Smart Mart.  
Built with a Flutter frontend and Node.js backend, utilizing JWT authentication and MongoDB for robust data management.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Setup Instructions](#setup-instructions)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#backend-setup)
  - [Frontend Setup](#frontend-setup)
- [Running Locally](#running-locally)
- [Deployment](#deployment)
- [API Usage and Authentication](#api-usage-and-authentication)
- [Contributing](#contributing)
- [License](#license)

---

## Project Overview

Smart Mart is a full-featured Inventory Management System that helps businesses manage products, stock levels, and sales efficiently.  
The Flutter app provides a user-friendly interface for admin and cashier roles, while the Node.js backend exposes RESTful APIs secured with JWTs.

---

## Features

- Product and Category management
- Stock tracking and inventory control
- Sales summary and report generation
- User authentication and role-based access (Admin, Cashier)
- Real-time updates with WebSocket integration (optional)
- Daily sales email reporting (scheduled)

---

## Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Node.js, Express.js
- **Database:** MongoDB
- **Authentication:** JSON Web Tokens (JWT)
- **Deployment:** Vercel (backend), Flutter APK/App release (frontend)

---

## Setup Instructions

### Prerequisites

- Flutter SDK installed
- Node.js and npm installed
- MongoDB instance (local or cloud)
- Git installed

### Backend Setup

1. Clone the backend repository or use the backend directory inside this project.
2. Create a `.env` file in the backend root and configure environment variables such as:

MONGODB_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret_key
SMTP_HOST=smtp.your-email.com
SMTP_PORT=587
SMTP_USER=your_email_user
SMTP_PASS=your_email_password
PORT=8080

text

3. Install backend dependencies:

npm install

text

4. Start backend server locally (development mode):

npm run dev

text

Or start for production:

npm start

text

---

### Frontend Setup

1. Ensure Flutter SDK is installed and configured.
2. Navigate to your Flutter project root folder and run:

flutter pub get

text

3. Update the backend URL in `lib/api_config.dart`. For example:

String getBackendBaseUrl() {
// Use your local backend URL for device testing
const localUrl = "http://192.168.100.181:8080";

// Use your deployed URL for production
const deployedUrl = "https://inventory-pos-backen6d.vercel.app";

// Return the URL based on your build mode or environment
return deployedUrl; // change to localUrl if testing locally
}

text

4. Run Flutter app on device or emulator:

flutter run

text

5. To build a release APK:

flutter build apk --release

text

---

## Running Locally

- Start your MongoDB server or use cloud MongoDB.
- Run backend server: `npm run dev`.
- Run Flutter app: `flutter run`.

---

## Deployment

### Backend

- Deployed on [Vercel](https://vercel.com) using serverless Node.js Express API routes.
- Configuration via `vercel.json`.

### Frontend

- Flutter app distributed as APK or via app stores.
- Backend URLs configured for production in `api_config.dart`.

---

## API Usage and Authentication

- All API endpoints are prefixed with `/api/`.
- Login API:

POST /api/login
Content-Type: application/json

{
"email": "user@example.com",
"password": "yourpassword",
"role": "admin"
}

text

- On success, backend returns:

{
"token": "JWT_TOKEN_HERE",
"userId": "USER_ID",
"name": "User Name",
"role": "admin",
"email": "user@example.com"
}

text

- Client stores the token and user info securely (e.g., SharedPreferences).
- Include the JWT token in Authorization header for protected routes:

Authorization: Bearer JWT_TOKEN_HERE

text

---

## Contributing

Contributions are very welcome! To contribute:

1. Fork the repository.
2. Create your feature branch:

git checkout -b feature/my-feature

text

3. Commit your changes:

git commit -am 'Add feature description'

text

4. Push to your branch:

git push origin feature/my-feature

text

5. Open a pull request on GitHub.

**Please ensure**:

- Code quality and readability.
- Include documentation or comments where necessary.
- Add tests for new features or fixes.

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---

If you need any assistance or find issues, please open an issue or contact the maintainer.
git add README.md
git commit -m "Resolve merge conflict and update README"
git push origin main
